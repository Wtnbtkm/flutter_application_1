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
    final sub = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(uid)
        .get();
    if (sub.exists && sub.data()?['playerName'] != null) {
      return sub.data()!['playerName'];
    }
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
    // マーダーミステリーの雰囲気カラー・フォント
    const Color backgroundColor = Color(0xFF1C1B2F);
    const Color cardColor = Color(0xFF292845);
    const Color accentColor = Color(0xFFE84A5F);
    const String fontFamily = 'MurderMysteryFont'; // pubspec.yamlで追加しておくと良い

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 6,
        shadowColor: accentColor.withOpacity(0.5),
        title: Row(
          children: [
            Icon(Icons.local_police, color: accentColor),
            const SizedBox(width: 8),
            Text(
              '待機ロビー',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: accentColor, blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
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

          if (currentUid != null && !players.contains(currentUid)) {
            return Center(
              child: Text(
                'あなたのアカウントがルームに存在しません。再参加してください。',
                style: TextStyle(color: accentColor, fontFamily: fontFamily),
              ),
            );
          }

          if (data['gameStarted'] == true) {
            Future.microtask(() => _navigateToStoryIntro());
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '事件ファイル: ${widget.problemTitle}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '必要な人数: $requiredPlayers 人',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    '現在の参加者: ${players.length} / $requiredPlayers',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 16,
                      color: accentColor,
                    ),
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
                      return ListView.separated(
                        itemCount: playerInfo.length,
                        separatorBuilder: (_, __) => SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final p = playerInfo[index]['uid']!;
                          final name = playerInfo[index]['name']!;
                          final isMe = (p == currentUid);
                          return Container(
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: readyPlayers.contains(p)
                                    ? Colors.greenAccent
                                    : accentColor.withOpacity(0.35),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(1, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Icon(
                                readyPlayers.contains(p)
                                    ? Icons.check_circle
                                    : Icons.hourglass_empty,
                                color: readyPlayers.contains(p)
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                size: 28,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                  color: isMe ? accentColor : Colors.white,
                                  fontSize: 17,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              subtitle: isMe
                                  ? Text(
                                      'あなた',
                                      style: TextStyle(
                                        fontFamily: fontFamily,
                                        color: accentColor,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleReady(readyPlayers),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myReady ? Colors.grey[800] : accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(
                            fontFamily: fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          elevation: 4,
                        ),
                        icon: Icon(myReady ? Icons.close : Icons.check),
                        label: Text(myReady ? '準備を解除' : '準備完了'),
                      ),
                    ),
                    const SizedBox(width: 18),
                    if (isHost)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: allReady ? () => _startGame(data) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allReady ? accentColor : Colors.grey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: TextStyle(
                              fontFamily: fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.black, width: 1),
                            ),
                            elevation: 4,
                          ),
                          icon: Icon(Icons.play_arrow),
                          label: const Text('ゲーム開始'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    '事件の幕は、すぐに上がる…',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontStyle: FontStyle.italic,
                      color: Colors.white38,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}