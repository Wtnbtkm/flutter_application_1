import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mock/screens/gamelobby_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ルームに参加
class RoomJoinScreen extends StatefulWidget {
  final String problemTitle;
  const RoomJoinScreen({Key? key, required this.problemTitle}) : super(key: key);

  @override
  _RoomJoinScreenState createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends State<RoomJoinScreen> {
  final TextEditingController _roomIdController = TextEditingController();

  void _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームIDを入力してください')),
      );
      return;
    }

    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final docSnap = await roomDoc.get();

    if (!docSnap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームが存在しません')),
      );
      return;
    }

    final roomData = docSnap.data();
    final List<dynamic> players = roomData?['players'] ?? [];
    final int requiredPlayers = roomData?['requiredPlayers'] ?? 6;

    if (players.length >= requiredPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このルームはすでに満員です')),
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

    String displayName;
    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
    if (playerDoc.exists && playerDoc.data()?['playerName'] != null && (playerDoc.data()?['playerName'] as String).trim().isNotEmpty) {
      displayName = playerDoc.data()?['playerName'];
    } else {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final dynamic rawName = data?['displayName'];
      if (rawName != null && rawName is String && rawName.trim().isNotEmpty) {
        displayName = rawName.trim();
      } else {
        int maxNumber = 1;
        final regex = RegExp(r'名無しの参加者(\d+)');
        for (var p in players) {
          final match = regex.firstMatch(p);
          if (match != null) {
            final num = int.tryParse(match.group(1) ?? '');
            if (num != null && num >= maxNumber) {
              maxNumber = num + 1;
            }
          }
        }
        displayName = '名無しの参加者$maxNumber';
      }
    }

    if (players.contains(displayName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同じ名前の参加者がすでにいます。もう一度お試しください。')),
      );
      return;
    }

    await roomDoc.update({
      'players': FieldValue.arrayUnion([displayName]),
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameLobbyScreen(
          problemTitle: widget.problemTitle,
          roomId: roomId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ルームに参加')),
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
                    'ルームに参加',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '問題: ${widget.problemTitle}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '参加するルームIDを入力してください',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'ルームID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _joinRoom,
                      child: const Text('参加する', style: TextStyle(fontSize: 18)),
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

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
}