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
import 'package:flutter_application_1/mock/screens/suspicion_result_to_question_phase.dart';

// カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont';

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
  bool showResults = false;
  final user = FirebaseAuth.instance.currentUser;
  Map<String, String> playerNameMap = {};
  StreamSubscription<DocumentSnapshot>? roomSubscription;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.timeLimitSeconds;
    _startTimer();
    _fetchPlayerNames();
    _listenToRoomChanges();
  }

  Future<void> _fetchPlayerNames() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .get();

    final map = <String, String>{};
    for (final doc in snapshot.docs) {
      map[doc.id] = doc.data()['playerName'] ?? doc.id;
    }
    setState(() {
      playerNameMap = map;
    });
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
        setState(() {
          showResults = true;
        });
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
        .doc(user!.uid)
        .set(suspicionData);

    setState(() {
      submitted = true;
    });

    _checkAllSubmittedAndSetReadyFlag();
  }

  Future<void> _checkAllSubmittedAndSetReadyFlag() async {
    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('suspicions')
        .get();

    if (snap.docs.length >= widget.players.length) {
      // 集計処理
      final countMap = <String, int>{};
      for (final doc in snap.docs) {
        final suspect = doc['suspect'] as String;
        if (suspect.isNotEmpty) {
          countMap[suspect] = (countMap[suspect] ?? 0) + 1;
        }
      }
      final sorted = countMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final orderedList = sorted.map((e) => e.key).toList();

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('suspicion_result')
          .doc('order')
          .set({'orderedSuspicionList': orderedList});

      // nextPhaseReady を true にして全員に通知
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'nextPhaseReady': true});
    }
  }

  void _listenToRoomChanges() {
    roomSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data()?['nextPhaseReady'] == true) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuspicionResultToQuestionPhase(
                roomId: widget.roomId,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    roomSubscription?.cancel();
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
            String display = '${playerNameMap[data['playerUid']] ?? data['playerName'] ?? '(名無し)'}「${playerNameMap[data['suspect']] ?? data['suspect']}が怪しい。理由：${data['reason']}」';
            if (data['autoSubmitted'] == true) {
              display += '（時間切れ自動送信）';
            }
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                decoration: BoxDecoration(
                  color: isMe ? mmAccent.withOpacity(0.13) : mmCard.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMe ? mmAccent : mmCard,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 3,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  child: Text(
                    display,
                    style: TextStyle(
                      fontFamily: mmFont,
                      color: isMe ? mmAccent : Colors.white,
                      fontSize: 16,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
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
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        title: Text(
          '誰が怪しい？',
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: mmAccent, blurRadius: 3)],
          ),
        ),
        leading: const Icon(Icons.search, color: mmAccent),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, color: mmAccent),
                const SizedBox(width: 8),
                Text(
                  '残り: $secondsLeft 秒',
                  style: const TextStyle(
                    fontFamily: mmFont,
                    fontSize: 18,
                    color: mmAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: mmCard.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: mmAccent, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: showResults
                      ? _buildChatList()
                      : const Center(
                          child: Text(
                            '制限時間終了後に全員の回答が表示されます。',
                            style: TextStyle(
                              fontFamily: mmFont,
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (!submitted) ...[
              _buildInputForm(),
            ] else ...[
              const Text(
                'あなたの回答は送信済みです。',
                style: TextStyle(
                  fontFamily: mmFont,
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      decoration: BoxDecoration(
        color: mmCard.withOpacity(0.93),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: mmAccent, width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedSuspect,
            hint: Text(
              '怪しい人を選択',
              style: const TextStyle(fontFamily: mmFont, color: mmAccent),
            ),
            dropdownColor: mmCard,
            decoration: InputDecoration(
              labelText: '怪しい人',
              labelStyle: const TextStyle(
                fontFamily: mmFont,
                color: mmAccent,
                fontWeight: FontWeight.bold,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: mmAccent, width: 2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: mmAccent, width: 2),
              ),
            ),
            icon: const Icon(Icons.arrow_drop_down, color: mmAccent),
            items: widget.players
                .where((p) => p != user?.uid)
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        playerNameMap[p] ?? p,
                        style: const TextStyle(
                          fontFamily: mmFont,
                          color: Colors.white,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (val) => setState(() => selectedSuspect = val),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: '理由を入力',
              labelStyle: const TextStyle(
                fontFamily: mmFont,
                color: mmAccent,
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: mmAccent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: mmAccent, width: 2),
              ),
              fillColor: mmBackground.withOpacity(0.9),
              filled: true,
            ),
            style: const TextStyle(
              fontFamily: mmFont,
              color: Colors.white,
              fontSize: 16,
            ),
            onChanged: (v) => setState(() => reason = v),
            maxLines: 2,
            enabled: !submitted,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                '送信',
                style: TextStyle(
                  fontFamily: mmFont,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mmAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.black, width: 1),
                ),
                elevation: 5,
              ),
              onPressed: (selectedSuspect != null && reason.trim().isNotEmpty && !submitted)
                  ? () => _submitSuspicion()
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
