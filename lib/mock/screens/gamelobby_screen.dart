import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameLobbyScreen extends StatefulWidget {
  final String roomId;
  final String problemTitle;

  const GameLobbyScreen({Key? key, required this.roomId, required this.problemTitle}) : super(key: key);

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  String? displayName;
  bool isReady = false;
  bool navigatedToCharacterSheet = false;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // 1. プレイヤー名（playersコレクション）優先、なければusersコレクションのdisplayName
    String? name;
    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
    if (playerDoc.exists && playerDoc.data()?['playerName'] != null && (playerDoc.data()?['playerName'] as String).trim().isNotEmpty) {
      name = playerDoc.data()?['playerName'];
    } else {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      name = userDoc.data()?['displayName'] ?? '名無しの参加者';
    }
    setState(() {
      displayName = name;
    });
  }

  Future<void> _toggleReady(List readyPlayers) async {
    if (displayName == null) return;

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);

    setState(() {
      isReady = !isReady; // 先にUI反映
    });

    if (!isReady) {
      // 準備解除
      await roomRef.update({'readyPlayers': FieldValue.arrayRemove([displayName])});
    } else {
      // 準備完了
      await roomRef.update({'readyPlayers': FieldValue.arrayUnion([displayName])});
    }
  }

  Future<void> _startGame(Map<String, dynamic> data) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    await roomRef.update({'gameStarted': true});
    _navigateToCharacterSheet();
  }

  void _navigateToCharacterSheet() {
    if (navigatedToCharacterSheet) return;
    navigatedToCharacterSheet = true;
    Navigator.pushReplacementNamed(
      context,
      '/characterSheet',
      arguments: {
        'roomId': widget.roomId,
        'playerUid': FirebaseAuth.instance.currentUser?.uid,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待機ロビー')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final players = List<String>.from(data['players'] ?? []);
          final readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
          final requiredPlayers = data['requiredPlayers'] ?? 6;

          final isHost = data['hostUid'] == FirebaseAuth.instance.currentUser?.uid;
          final allReady = players.length == requiredPlayers && readyPlayers.length == requiredPlayers;

          // 自分のisReady状態をFirestoreから判断
          final myReady = displayName != null && readyPlayers.contains(displayName);

          // gameStartedで全員遷移
          if (data['gameStarted'] == true) {
            Future.microtask(() => _navigateToCharacterSheet());
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '選択中の問題: ${widget.problemTitle}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '必要な人数: $requiredPlayers 人',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '参加者: ${players.length} / $requiredPlayers',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final p = players[index];
                        final isMe = (p == displayName);
                        return ListTile(
                          title: Text(
                            p,
                            style: isMe
                                ? const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)
                                : null,
                          ),
                          trailing: readyPlayers.contains(p)
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.hourglass_empty),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _toggleReady(readyPlayers),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(myReady ? '準備を解除' : '準備完了'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (isHost)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: allReady ? () => _startGame(data) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allReady ? Theme.of(context).primaryColor : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('ゲーム開始'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}