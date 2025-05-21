import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameLobbyScreen extends StatelessWidget {
  final String problemTitle;
  final String roomId;

  const GameLobbyScreen({Key? key, required this.problemTitle, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(roomId);

    return Scaffold(
      appBar: AppBar(title: Text('ロビー - $problemTitle')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: roomDoc.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('エラーが発生しました'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final roomData = snapshot.data!.data() as Map<String, dynamic>?;

          if (roomData == null) return const Center(child: Text('ルーム情報がありません'));

          final hostName = roomData['hostName'] ?? '不明なホスト';
          final players = List<String>.from(roomData['players'] ?? []);
          final requiredPlayers = roomData['requiredPlayers'] ?? 6; // ← Firestoreから取得

          final remaining = requiredPlayers - players.length;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('選択された問題: $problemTitle', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('ルーム名: ${roomData['roomName'] ?? 'なし'}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                Text('ホスト: $hostName', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Text('参加プレイヤー (${players.length}/$requiredPlayers):', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(players[index]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  remaining > 0
                      ? 'あと $remaining 人参加が必要です'
                      : '必要人数が揃いました。ゲームを開始できます。',
                  style: TextStyle(
                    fontSize: 16,
                    color: remaining > 0 ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: remaining == 0
                      ? () {
                          // ゲーム開始処理（未実装）
                        }
                      : null,
                  child: const Text('ゲーム開始'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
