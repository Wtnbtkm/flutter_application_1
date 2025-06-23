//質問フェーズ
/*質問・反論フェーズ画面
目的：上記の怪しい人の理由に対し、質問したい人が質問する

必要機能：

挙手 or ボタンで質問したい人を受け付け

順番に質問できるUI

時間制限（1人何秒 or 全体制限）*/
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore構造（例）
/// rooms/{roomId}/questionPhase
///   - phaseState: 'waiting' | 'asking' | 'finished'
///   - askedPlayerUid: string
///   - startTime: Timestamp
/// rooms/{roomId}/questionRequests/
///   - {uid}: { playerName: string, timestamp: Timestamp }

class QuestionPhaseScreen extends StatefulWidget {
  final String roomId;
  final List<String> players; // プレイヤー名リスト
  final int questionTimeLimit; // 1人の質問制限（秒）
  final int overallTimeLimit; // 全体の質問制限（秒）

  const QuestionPhaseScreen({
    Key? key,
    required this.roomId,
    required this.players,
    this.questionTimeLimit = 30,
    this.overallTimeLimit = 120,
  }) : super(key: key);

  @override
  State<QuestionPhaseScreen> createState() => _QuestionPhaseScreenState();
}

class _QuestionPhaseScreenState extends State<QuestionPhaseScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String? playerName;
  int overallSecondsLeft = 0;
  Timer? _overallTimer;
  int questionSecondsLeft = 0;
  Timer? _questionTimer;

  @override
  void initState() {
    super.initState();
    _fetchPlayerName();
    _startOverallTimer();
  }

  Future<void> _fetchPlayerName() async {
    if (user == null) return;
    // Firestoreのplayersコレクション優先。なければユーザー名
    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(user!.uid).get();
    setState(() {
      playerName = playerDoc.data()?['playerName'] ?? user!.displayName ?? '名無し';
    });
  }

  void _startOverallTimer() {
    setState(() {
      overallSecondsLeft = widget.overallTimeLimit;
    });
    _overallTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (overallSecondsLeft > 0) {
        setState(() {
          overallSecondsLeft--;
        });
      } else {
        _overallTimer?.cancel();
        // フェーズ終了処理
        _finishPhase();
      }
    });
  }

  void _startQuestionTimer() {
    setState(() {
      questionSecondsLeft = widget.questionTimeLimit;
    });
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (questionSecondsLeft > 0) {
        setState(() {
          questionSecondsLeft--;
        });
      } else {
        _questionTimer?.cancel();
        // 次の人へ
        _nextAsker();
      }
    });
  }

  Future<void> _raiseHand() async {
    if (user == null || playerName == null) return;
    final reqRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('questionRequests')
        .doc(user!.uid);
    await reqRef.set({
      'playerName': playerName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _nextAsker() async {
    // 質問リクエストのキューから次の人を取得
    final reqs = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('questionRequests')
        .orderBy('timestamp')
        .get();
    if (reqs.docs.isNotEmpty) {
      // 先頭の人を phaseState.askedPlayerUid にセットし、質問タイマー開始
      final nextUid = reqs.docs.first.id;
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('questionRequests')
          .doc(nextUid)
          .delete();
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('questionPhase')
          .doc('state')
          .set({
            'phaseState': 'asking',
            'askedPlayerUid': nextUid,
            'startTime': FieldValue.serverTimestamp(),
          });
      _startQuestionTimer();
    } else {
      // キューが空ならwaiting or 終了
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('questionPhase')
          .doc('state')
          .set({
            'phaseState': 'waiting',
            'askedPlayerUid': '',
          });
      _questionTimer?.cancel();
      setState(() => questionSecondsLeft = 0);
    }
  }

  Future<void> _finishPhase() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('questionPhase')
        .doc('state')
        .set({'phaseState': 'finished'});
  }

  @override
  void dispose() {
    _overallTimer?.cancel();
    _questionTimer?.cancel();
    super.dispose();
  }

  Widget _buildQuestionQueue() {
    // 挙手順リスト表示
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('questionRequests')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text('挙手者なし');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('質問キュー:'),
            ...docs.asMap().entries.map((entry) {
              final i = entry.key;
              final data = entry.value.data() as Map<String, dynamic>;
              return Text('${i + 1}. ${data['playerName'] ?? ''}');
            }),
          ],
        );
      },
    );
  }

  Widget _buildPhaseState() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('questionPhase')
          .doc('state')
          .snapshots(),
      builder: (context, snapshot) {
        String state = 'waiting';
        String askedUid = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          state = data['phaseState'] ?? 'waiting';
          askedUid = data['askedPlayerUid'] ?? '';
        }
        if (state == 'finished') {
          return const Text('質問フェーズ終了', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green));
        }
        if (state == 'asking' && askedUid.isNotEmpty) {
          // 現在の質問者を取得し強調
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('players').doc(askedUid).get(),
            builder: (context, snap) {
              String pname = '';
              if (snap.hasData && snap.data!.exists) {
                pname = snap.data!.data() != null ? (snap.data!.data() as Map)['playerName'] ?? '' : '';
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('現在の質問者: $pname', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  Text('残り: $questionSecondsLeft 秒', style: const TextStyle(color: Colors.red)),
                ],
              );
            },
          );
        }
        return const Text('質問待ち...');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alreadyRaised =
        user == null ? false : null; // ここは自分が既に挙手済みかどうかをFirestore監視で出すとベター
    return Scaffold(
      appBar: AppBar(title: const Text('質問・反論フェーズ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 全体制限タイマー
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text('全体残り: $overallSecondsLeft 秒', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPhaseState(),
            const SizedBox(height: 16),
            _buildQuestionQueue(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.pan_tool),
              label: const Text('挙手する（質問したい）'),
              onPressed: alreadyRaised == true ? null : _raiseHand,
            ),
            // 質問内容や回答欄などをここに追加可能
            const Spacer(),
            ElevatedButton(
              child: const Text('次の人へ（ホスト用）'),
              onPressed: _nextAsker,
            ),
          ],
        ),
      ),
    );
  }
}