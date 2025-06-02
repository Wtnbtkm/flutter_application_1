import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/room_creation_screen.dart'; // ルーム作成画面
import 'package:flutter_application_1/mock/screens/room_join_screen.dart';   // ルーム参加画面

//ルームの選択画面
class RoomChoiceScreen extends StatelessWidget {
  final String problemTitle;
  final int requiredPlayers;
  final String problemId;

  const RoomChoiceScreen({
    Key? key,
    required this.problemTitle,
    required this.requiredPlayers,
    required this.problemId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ルーム選択')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomCreationScreen(
                            problemTitle: problemTitle,
                            requiredPlayers: requiredPlayers,problemId: problemId,
                          ),
                        ),
                      );
                    },
                    child: const Text('ルームを作成'),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomJoinScreen(
                            problemTitle: problemTitle,
                          ),
                        ),
                      );
                    },
                    child: const Text('ルームに参加'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}