import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/story_intro_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  final String roomId;
  final String problemTitle;
  final String problemId;

  const GameLobbyScreen({
    Key? key,
    required this.roomId,
    required this.problemTitle,
    required this.problemId,
  }) : super(key: key);

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  bool navigatedToStoryIntro = false;
  String? currentUid;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<String> _getPlayerName(String uid) async {
    // ルームサブコレクション優先で取得
    final sub = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(uid)
        .get();
    if (sub.exists && sub.data()?['playerName'] != null) {
      return sub.data()!['playerName'];
    }
    // fallback: playersコレクション
    final doc = await FirebaseFirestore.instance.collection('players').doc(uid).get();
    if (doc.exists && doc.data()?['playerName'] != null) {
      return doc.data()!['playerName'];
    }
    return '名無しの参加者';
  }

  Future<void> _toggleReady(List readyPlayers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final isReady = readyPlayers.contains(user.uid);
    if (isReady) {
      await roomRef.update({'readyPlayers': FieldValue.arrayRemove([user.uid])});
    } else {
      await roomRef.update({'readyPlayers': FieldValue.arrayUnion([user.uid])});
    }
  }

  Future<void> _startGame(Map<String, dynamic> data) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    await roomRef.update({'gameStarted': true});
    _navigateToStoryIntro();
  }

  void _navigateToStoryIntro() {
    if (navigatedToStoryIntro) return;
    navigatedToStoryIntro = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StoryIntroScreen(problemId: widget.problemId),
        settings: RouteSettings(arguments: widget.roomId),
      ),
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
          final myReady = currentUid != null && readyPlayers.contains(currentUid);

          // currentUidがplayers内にいない場合、警告を表示
          if (currentUid != null && !players.contains(currentUid)) {
            return Center(
              child: Text('あなたのアカウントがルームに存在しません。再参加してください。'),
            );
          }

          // gameStartedで全員遷移
          if (data['gameStarted'] == true) {
            Future.microtask(() => _navigateToStoryIntro());
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
                  child: FutureBuilder<List<Map<String, String>>>(
                    future: Future.wait(players.map((uid) async {
                      final name = await _getPlayerName(uid);
                      return {'uid': uid, 'name': name};
                    }).toList()),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final playerInfo = snap.data!;
                      return ListView.builder(
                        itemCount: playerInfo.length,
                        itemBuilder: (context, index) {
                          final p = playerInfo[index]['uid']!;
                          final name = playerInfo[index]['name']!;
                          final isMe = (p == currentUid);
                          return ListTile(
                            title: Text(
                              name,
                              style: isMe
                                  ? const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)
                                  : null,
                            ),
                            trailing: readyPlayers.contains(p)
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.hourglass_empty),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 準備完了ボタンは全員に表示
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
                    // ゲーム開始ボタンはホストのみ表示
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