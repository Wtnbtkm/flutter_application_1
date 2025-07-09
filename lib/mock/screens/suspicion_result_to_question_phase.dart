import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mock/screens/question_phase_screen.dart';

class SuspicionResultToQuestionPhase extends StatefulWidget {
  final String roomId;
  final int questionTimeLimit;
  final int overallTimeLimit;

  const SuspicionResultToQuestionPhase({
    Key? key,
    required this.roomId,
    this.questionTimeLimit = 30,
    this.overallTimeLimit = 120,
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
    // 怪しいとされたプレイヤーをtimestamp順にリストアップ（重複除去・順序維持）
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
    setState(() {
      currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (currentIndex >= suspectOrder.length) {
      return const Center(child: Text('全員の弁論・質問が終了しました'));
    }

    final targetPlayer = suspectOrder[currentIndex];

    return QuestionPhaseScreen(
      roomId: widget.roomId,
      players: suspectOrder, // or 全員のプレイヤーリスト
      questionTimeLimit: widget.questionTimeLimit,

      // ↓ 弁論対象プレイヤーを渡したい場合はQuestionPhaseScreenにパラメータ追加
      // targetPlayer: targetPlayer,
      // onFinish: _onFinishQuestionPhase,
    );
  }
}