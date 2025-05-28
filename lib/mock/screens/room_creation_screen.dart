import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/gamelobby_screen.dart';

// ルームの作成画面
class RoomCreationScreen extends StatefulWidget {
  final String problemTitle;
  final int requiredPlayers;

  const RoomCreationScreen({
    Key? key,
    required this.problemTitle,
    required this.requiredPlayers,
  }) : super(key: key);

  @override
  State<RoomCreationScreen> createState() => _RoomCreationScreenState();
}

class _RoomCreationScreenState extends State<RoomCreationScreen> {
  final _roomNameController = TextEditingController();
  final _roomIdController = TextEditingController();

  Future<void> createRoom() async {
    final roomName = _roomNameController.text.trim();
    final roomId = _roomIdController.text.trim();

    if (roomName.isEmpty || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルーム名とルームIDを入力してください')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
    final hostName = playerDoc.exists
        ? (playerDoc.data()?['playerName'] ?? '名無しのホスト')
        : '名無しのホスト';

    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final docSnapshot = await roomDoc.get();

    if (docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('そのルームIDは既に使われています')),
      );
      return;
    }

    try {
      await roomDoc.set({
        'roomName': roomName,
        'hostUid': user.uid,
        'hostName': hostName,
        'problemTitle': widget.problemTitle,
        'players': [hostName],
        'requiredPlayers': widget.requiredPlayers,
        'readyPlayers': [],
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームを作成しました')),
      );

      _roomNameController.clear();
      _roomIdController.clear();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameLobbyScreen(
            roomId: roomId,
            problemTitle: widget.problemTitle,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ルーム作成')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '新しいルームを作成',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '問題: ${widget.problemTitle}（定員: ${widget.requiredPlayers}人）',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _roomNameController,
                    decoration: const InputDecoration(
                      labelText: 'ルーム名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'ルームID（英数字）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: createRoom,
                      child: const Text('作成する', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}