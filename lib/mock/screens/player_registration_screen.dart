import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

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
    _currentUser = FirebaseAuth.instance.currentUser; // 現在のユーザーを取得
    _loadExistingPlayerName(); // 既存のプレイヤー名があれば読み込む
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
        SnackBar(content: Text(_isEditing
            ? 'プレイヤー名を更新しました'
            : 'プレイヤー名を登録しました')),
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
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        leading: const Icon(Icons.person, color: mmAccent),
        title: Text(
          _isEditing ? '名前の編集' : '探偵名の登録',
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: mmAccent, blurRadius: 3)],
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
              child: Container(
                decoration: BoxDecoration(
                  color: mmCard.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: mmAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 8,
                      offset: const Offset(2, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge, color: mmAccent, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      _isEditing
                          ? 'あなたの新たな名を記せ'
                          : '名探偵、名を刻め',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: mmAccent,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 3, offset: Offset(2, 2)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.mail, color: mmAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ログイン中: ${_currentUser?.email ?? "未ログイン"}',
                            style: const TextStyle(
                              fontFamily: mmFont,
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white,
                        fontSize: 17,
                        letterSpacing: 1.2,
                      ),
                      decoration: InputDecoration(
                        labelText: _isEditing ? '新しい探偵名' : '探偵名',
                        labelStyle: const TextStyle(
                          fontFamily: mmFont,
                          color: mmAccent,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: _isEditing
                            ? '現在の名前: ${_nameController.text}'
                            : '名乗りを上げよ',
                        filled: true,
                        fillColor: mmBackground.withOpacity(0.85),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: mmAccent, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: mmAccent, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.edit, color: mmAccent),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _isEditing ? Icons.update : Icons.person_add,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isEditing ? '更新する' : '登録する',
                          style: const TextStyle(
                            fontFamily: mmFont,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mmAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.black, width: 1),
                          ),
                          elevation: 5,
                          shadowColor: mmAccent.withOpacity(0.3),
                        ),
                        onPressed: registerPlayer,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '※本名や個人情報は避けてください',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white38,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}