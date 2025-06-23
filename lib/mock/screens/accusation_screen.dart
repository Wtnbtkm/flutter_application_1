//誰があやしいか順番に聞いていくなぜ怪しいと思うのかを理由を入力する画面
//怪しい人と理由提示画面
/*目的：プレイヤーが順番に「誰が怪しいか」と「その理由」を述べる
必要機能：
入力欄（怪しい人を選択・理由をテキストで入力）(チャット画面に表示)
時間制限あり
他のプレイヤーが見ることができる表示*/

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuspicionInputScreen extends StatefulWidget {
  final String roomId;
  final List<String> players;
  final int timeLimitSeconds;

  const SuspicionInputScreen({
    Key? key,
    required this.roomId,
    required this.players,
    this.timeLimitSeconds = 60,
  }) : super(key: key);

  @override
  State<SuspicionInputScreen> createState() => _SuspicionInputScreenState();
}

class _SuspicionInputScreenState extends State<SuspicionInputScreen> {
  String? selectedSuspect;
  String reason = '';
  int secondsLeft = 0;
  Timer? _timer;
  bool submitted = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.timeLimitSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft > 0) {
        setState(() {
          secondsLeft--;
        });
      } else {
        _timer?.cancel();
        if (!submitted) {
          _submitSuspicion(auto: true);
        }
      }
    });
  }

  Future<void> _submitSuspicion({bool auto = false}) async {
    if (user == null || submitted) return;

    final suspicionData = {
      'suspect': selectedSuspect ?? '',
      'reason': reason,
      'playerUid': user!.uid,
      'playerName': user!.displayName ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'autoSubmitted': auto,
    };

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('suspicions')
        .doc(user!.uid) // 1人1回答
        .set(suspicionData);

    setState(() {
      submitted = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('suspicions')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView(
          reverse: true,
          children: docs.reversed.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isMe = user?.uid == data['playerUid'];
            String display = '${data['playerName'] ?? '(名無し)'}「${data['suspect']}が怪しい。理由：${data['reason']}」';
            if (data['autoSubmitted'] == true) {
              display += '（時間切れ自動送信）';
            }
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Card(
                color: isMe ? Colors.blue[50] : Colors.grey[200],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(display),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = !submitted; // turn制にしたいならロジック追加
    return Scaffold(
      appBar: AppBar(title: const Text('誰が怪しいか発表')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // タイマー
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.red),
                const SizedBox(width: 8),
                Text('残り: $secondsLeft 秒', style: const TextStyle(fontSize: 18, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildChatList(),
            ),
            const SizedBox(height: 16),
            if (!submitted) ...[
              DropdownButtonFormField<String>(
                value: selectedSuspect,
                hint: const Text('怪しい人を選択'),
                items: widget.players
                    .where((p) => p != (user?.displayName ?? '')) // 自分以外
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) => setState(() => selectedSuspect = val),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: '理由を入力', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => reason = v),
                maxLines: 2,
                enabled: !submitted,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text('送信'),
                  onPressed: (selectedSuspect != null && reason.trim().isNotEmpty && !submitted)
                      ? () => _submitSuspicion()
                      : null,
                ),
              ),
            ] else ...[
              const Text('あなたの回答は送信済みです。'),
            ],
          ],
        ),
      ),
    );
  }
}