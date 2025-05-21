import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//プレイヤー名の登録
class PlayerRegistrationScreen extends StatefulWidget {
  const PlayerRegistrationScreen({super.key});

  @override
  State<PlayerRegistrationScreen> createState() => _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends State<PlayerRegistrationScreen> {
  final _nameController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> registerPlayer() async {
    final playerName = _nameController.text.trim();

    if (playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プレイヤー名を入力してください')),
      );
      return;
    }

      // nullチェック追加
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーがログインしていません')),
      );
      return;
    }


    try {
      await FirebaseFirestore.instance
          .collection('players')
          .doc(_currentUser!.uid) // ユーザーUIDをドキュメントIDに
          .set({
        'uid': _currentUser.uid,
        'email': _currentUser.email,
        'playerName': playerName,
        'score': 0,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プレイヤー名を登録しました')),
      );
      _nameController.clear();
      // ホーム画面に戻る
      Navigator.pop(context); // これで1つ前の画面（ホーム）に戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレイヤー名の登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('ログイン中: ${_currentUser?.email ?? "未ログイン"}'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'プレイヤー名'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: registerPlayer,
              child: const Text('登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
