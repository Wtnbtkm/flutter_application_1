import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomCreationScreen extends StatefulWidget {
  const RoomCreationScreen({super.key});

  @override
  State<RoomCreationScreen> createState() => _RoomCreationScreenState();
}

class _RoomCreationScreenState extends State<RoomCreationScreen> {
  final _roomNameController = TextEditingController();
  final _hostUidController = TextEditingController(); // 後に FirebaseAuth.currentUser!.uid に変更可能

  Future<void> createRoom() async {
    final roomName = _roomNameController.text;
    final hostUid = _hostUidController.text;

    if (roomName.isEmpty || hostUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全ての項目を入力してください')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('rooms').add({
        'roomName': roomName,
        'hostUid': hostUid,
        'createdAt': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームを作成しました')),
      );
      _roomNameController.clear();
      _hostUidController.clear();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(labelText: 'ルーム名'),
            ),
            TextField(
              controller: _hostUidController,
              decoration: const InputDecoration(labelText: 'ホストUID'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: createRoom,
              child: const Text('作成する'),
            ),
          ],
        ),
      ),
    );
  }
}
