import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mock/screens/gamelobby_screen.dart';

class RoomChoiceScreen extends StatelessWidget {
  final String problemTitle;
  final int requiredPlayers;

  const RoomChoiceScreen({
    Key? key,
    required this.problemTitle,
    required this.requiredPlayers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController roomNameController = TextEditingController();
    final TextEditingController hostIdController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('ルーム作成')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: roomNameController,
              decoration: const InputDecoration(labelText: 'ルーム名'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hostIdController,
              decoration: const InputDecoration(labelText: 'ホストID'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final roomName = roomNameController.text.trim();
                final hostId = hostIdController.text.trim();
                if (roomName.isEmpty || hostId.isEmpty) return;

                final newRoomRef = FirebaseFirestore.instance.collection('rooms').doc();
                await newRoomRef.set({
                  'roomName': roomName,
                  'hostId': hostId,
                  'players': [hostId],
                  'requiredPlayers': requiredPlayers,
                  'problemTitle': problemTitle,
                });

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameLobbyScreen(
                      problemTitle: problemTitle,
                      roomId: newRoomRef.id,
                    ),
                  ),
                );
              },
              child: const Text('ルームを作成'),
            ),
          ],
        ),
      ),
    );
  }
}
