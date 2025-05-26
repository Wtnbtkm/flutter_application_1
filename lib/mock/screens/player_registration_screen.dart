import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// プレイヤー名の登録・編集画面のウィジェット
class PlayerRegistrationScreen extends StatefulWidget {
  const PlayerRegistrationScreen({super.key});

  @override
  State<PlayerRegistrationScreen> createState() => _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends State<PlayerRegistrationScreen> {
  final _nameController = TextEditingController();
  User? _currentUser;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;// 現在のユーザーを取得
    _loadExistingPlayerName();// 既存のプレイヤー名があれば読み込む
  }
  // Firestoreから既存のプレイヤー名を取得し、あればテキストフィールドにセット
  Future<void> _loadExistingPlayerName() async {
    if (_currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('players')
        .doc(_currentUser!.uid) 
        .get();
    // 既にプレイヤー名が登録されていれば、テキストフィールドにセットし編集モードへ
    if (doc.exists && doc.data()?['playerName'] != null) {
      setState(() {
        _nameController.text = doc.data()!['playerName'];
        _isEditing = true;
      });
    }
  }
// プレイヤー名の登録・更新処理
Future<void> registerPlayer() async {
    final playerName = _nameController.text.trim();

    if (playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プレイヤー名を入力してください')),
      );
      return;
    }

    // nullチェック
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーがログインしていません')),
      );
      return;
    }

    try {
      final playerRef = FirebaseFirestore.instance
          .collection('players')
          .doc(_currentUser!.uid); 

      if (_isEditing) {
        await playerRef.update({
          'playerName': playerName,
          'updatedAt': Timestamp.now(),
        });
      } else {
        await playerRef.set({
          'uid': _currentUser!.uid,
          'email': _currentUser!.email,
          'playerName': playerName,
          'score': 0,
          'createdAt': Timestamp.now(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 
          'プレイヤー名を更新しました' : 'プレイヤー名を登録しました')),
      );
      
      _nameController.clear(); // 入力欄をクリア
      Navigator.pop(context); // 前の画面に戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 
          'プレイヤー名の編集' : 'プレイヤー名の登録'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('ログイン中: ${_currentUser?.email ?? "未ログイン"}'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _isEditing ? 
                  '新しいプレイヤー名' : 'プレイヤー名',
                hintText: _isEditing ? 
                  '現在の名前: ${_nameController.text}' : '',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: registerPlayer,
              child: Text(_isEditing ? '更新する' : '登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
