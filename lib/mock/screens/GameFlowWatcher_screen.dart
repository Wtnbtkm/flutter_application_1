import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//自動的に状態（フェーズ）を確認し、適切な画面へ遷移させて進行を自動化する
class GameFlowWatcher extends StatelessWidget {
  final String gameId;

  const GameFlowWatcher({Key? key, required this.gameId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gameRef = FirebaseFirestore.instance.collection('gameState').doc(gameId);

    return StreamBuilder<DocumentSnapshot>(
      stream: gameRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'];

        switch (status) {
          case 'character':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/character'));
            break;
          case 'evidence':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/evidence'));
            break;
          case 'discussion':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/discussion'));
            break;
          case 'private':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/private'));
            break;
          case 'suspicion':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/suspicion'));
            break;
          case 'qna':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/qna'));
            break;
          case 'voting':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/voting'));
            break;
          case 'result':
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/result'));
            break;
          default:
            return Scaffold(body: Center(child: Text("ゲームがまだ開始されていません")));
        }

        return Scaffold(
          body: Center(child: Text("遷移中...")),
        );
      },
    );
  }
}
