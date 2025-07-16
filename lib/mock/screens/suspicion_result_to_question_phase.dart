import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mock/screens/question_phase_screen.dart';
import 'package:flutter_application_1/mock/screens/voting_screen.dart'; // 🔸 遷移先を適宜用意

class SuspicionResultToQuestionPhase extends StatefulWidget {
  final String roomId;
  final int questionTimeLimit;
  final int overallTimeLimit;
  final String targetPlayer;
  final VoidCallback onFinish;

  const SuspicionResultToQuestionPhase({
    Key? key,
    required this.roomId,
    this.questionTimeLimit = 30,
    this.overallTimeLimit = 120,
    required this.targetPlayer,      // 弁論対象
    required this.onFinish,          // 弁論終了後に呼び出す
  }) : super(key: key);

  @override
  State<SuspicionResultToQuestionPhase> createState() => _SuspicionResultToQuestionPhaseState();
}

class _SuspicionResultToQuestionPhaseState extends State<SuspicionResultToQuestionPhase> {
  List<String> suspectOrder = [];
  int currentIndex = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSuspectOrder();
  }

  Future<void> _fetchSuspectOrder() async {
    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('suspicions')
        .orderBy('timestamp')
        .get();

    final seen = <String>{};
    final order = <String>[];
    for (var doc in snap.docs) {
      final suspect = (doc.data()['suspect'] ?? '').toString();
      if (suspect.isNotEmpty && !seen.contains(suspect)) {
        order.add(suspect);
        seen.add(suspect);
      }
    }

    setState(() {
      suspectOrder = order;
      loading = false;
    });
  }

  void _onFinishQuestionPhase() {
    print("質問フェーズ終了: currentIndex=$currentIndex");
    setState(() {
      currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (currentIndex >= suspectOrder.length) {
      // 全員の弁論が終了したら、別画面に遷移
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VotingScreen(
              roomId: widget.roomId,
              players: suspectOrder.map((uid) => {'uid': uid}).toList(), // プレイヤーリストを適宜変換
              votingTimeLimit: widget.overallTimeLimit,
            ),
          ),
        );
      });
      return const Center(child: CircularProgressIndicator());
    }

    final targetPlayer = suspectOrder[currentIndex];

    return QuestionPhaseScreen(
      roomId: widget.roomId,
      targetPlayer: targetPlayer,            // 弁論対象を渡す
      players: suspectOrder,                 // 質問者リスト（必要なら全員のプレイヤーリストに変更可）
      questionTimeLimit: widget.questionTimeLimit,
      onFinish: _onFinishQuestionPhase,      // 質問終了後の処理
    );
  }
}
