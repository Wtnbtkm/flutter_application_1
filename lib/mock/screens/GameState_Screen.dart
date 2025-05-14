import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameStateScreen extends StatefulWidget {
  const GameStateScreen({super.key});

  @override
  State<GameStateScreen> createState() => _GameStateScreenState();
}

class _GameStateScreenState extends State<GameStateScreen> {
  final _roomIdController = TextEditingController();
  final _statusController = TextEditingController();
  final _currentTurnController = TextEditingController();

  Future<void> updateGameState() async {
    final roomId = _roomIdController.text;
    final status = _statusController.text;
    final currentTurn = _currentTurnController.text;

    if (roomId.isEmpty || status.isEmpty || currentTurn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全ての項目を入力してください')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('gameState').doc(roomId).set({
        'status': status,
        'currentTurn': currentTurn,
        'updatedAt': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ゲーム状態を更新しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ゲーム状態管理')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(labelText: 'ルームID'),
            ),
            TextField(
              controller: _statusController,
              decoration: const InputDecoration(labelText: 'ゲームの状態（例: waiting, playing）'),
            ),
            TextField(
              controller: _currentTurnController,
              decoration: const InputDecoration(labelText: '現在のターン（例: player1）'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: updateGameState,
              child: const Text('状態を更新'),
            ),
          ],
        ),
      ),
    );
  }
}
