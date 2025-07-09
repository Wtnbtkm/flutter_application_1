import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/charactersheet_screen.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // 適切なフォントをassets/fontsに追加・pubspec.yamlで登録

class StoryIntroScreen extends StatefulWidget {
  final String problemId;
  const StoryIntroScreen({Key? key, required this.problemId}) : super(key: key);

  @override
  State<StoryIntroScreen> createState() => _StoryIntroScreenState();
}

class _StoryIntroScreenState extends State<StoryIntroScreen> {
  Map<String, dynamic>? problemData;
  bool loading = true;
  bool navigatedToCharacterSheet = false;

  @override
  void initState() {
    super.initState();
    loadProblemData();
  }

  Future<void> loadProblemData() async {
    final jsonString =
        await rootBundle.loadString('assets/problems/${widget.problemId}.json');
    setState(() {
      problemData = json.decode(jsonString);
      loading = false;
    });
  }

  Future<void> toggleReady(String roomId, String playerUid, bool isReady) async {
    final playerRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(playerUid);
    await playerRef.set({'isReady': !isReady}, SetOptions(merge: true));
  }

  Future<void> assignCharactersToPlayers(String roomId) async {
    if (problemData == null) return;
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (roomDoc.data()?['rolesAssigned'] == true) return;

    final playersSnapshot = await roomRef.collection('players').get();
    final players = playersSnapshot.docs.toList();
    final characterTemplates = List<Map<String, dynamic>>.from(problemData!['characters'] as List);
    if (players.length > characterTemplates.length) {
      throw Exception('プレイヤー数が配役数を超えています。');
    }
    characterTemplates.shuffle();
    players.shuffle();

    final futures = <Future>[];
    for (int i = 0; i < players.length; i++) {
      final playerDoc = players[i];
      final character = characterTemplates[i];
      futures.add(roomRef.collection('players').doc(playerDoc.id).set({
        'role': character['role'],
        'description': character['description'],
        'evidence': character['evidence'],
        'winConditions': character['winConditions'],
      }, SetOptions(merge: true)));
    }
    await Future.wait(futures);

    for (final player in players) {
      await roomRef.collection('players').doc(player.id).set({'isReady': false}, SetOptions(merge: true));
    }

    await roomRef.update({'rolesAssigned': true});
  }

  void _navigateToCharacterSheet({required String roomId}) {
    if (navigatedToCharacterSheet) return;
    navigatedToCharacterSheet = true;
    final playerId = FirebaseAuth.instance.currentUser?.uid;
    if (playerId == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterSheetScreen(
          roomId: roomId,
          playerUid: playerId,
          problemId: widget.problemId,
        ),
      ),
    ).then((_) => navigatedToCharacterSheet = false);
  }

  @override
  Widget build(BuildContext context) {
    final playerId = FirebaseAuth.instance.currentUser?.uid;
    final roomId = ModalRoute.of(context)?.settings.arguments as String?;

    if (loading) {
      return const Scaffold(
        backgroundColor: mmBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (problemData == null) {
      return const Scaffold(
        backgroundColor: mmBackground,
        body: Center(child: Text('問題データ読み込み失敗', style: TextStyle(color: Colors.white))),
      );
    }

    if (roomId == null) {
      return const Scaffold(
        backgroundColor: mmBackground,
        body: Center(child: Text('ルームIDが見つかりません。', style: TextStyle(color: Colors.white))),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .snapshots(),
      builder: (context, playersSnapshot) {
        if (!playersSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: mmBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final playerDocs = playersSnapshot.data!.docs;
        QueryDocumentSnapshot<Object?>? myDoc;
        try {
          myDoc = playerDocs.firstWhere((d) => d.id == playerId);
        } catch (e) {
          myDoc = null;
        }
        final bool myReady = (myDoc?.data() as Map<String, dynamic>?)?['isReady'] == true;
        final bool allReady = playerDocs.isNotEmpty && playerDocs.every((d) => (d.data() as Map<String, dynamic>?)?['isReady'] == true);

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: mmBackground,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final hostUid = data['hostUid'] as String?;
            final rolesAssigned = data['rolesAssigned'] == true;
            final isHost = hostUid == playerId;

            if (rolesAssigned && playerId != null && roomId != null) {
              Future.microtask(() => _navigateToCharacterSheet(roomId: roomId));
            }

            List<Widget> actionButtons = [];
            if (isHost) {
              actionButtons.addAll([
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag, color: Colors.white),
                  onPressed: playerId == null
                      ? null
                      : () => toggleReady(roomId, playerId, myReady),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myReady ? Colors.green[700] : mmAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontFamily: mmFont,
                      fontSize: 18, letterSpacing: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: mmAccent, width: 2),
                    ),
                    elevation: 4,
                  ),
                  label: Text(myReady ? '準備解除' : '準備完了',
                    style: const TextStyle(fontFamily: mmFont),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: (allReady && !rolesAssigned)
                      ? () async {
                          try {
                            await assignCharactersToPlayers(roomId);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('配役失敗: $e')),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allReady ? mmAccent : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontFamily: mmFont,
                      fontSize: 18, letterSpacing: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: mmAccent, width: 2),
                    ),
                    elevation: 4,
                  ),
                  label: const Text('配役スタート', style: TextStyle(fontFamily: mmFont)),
                ),
              ]);
            } else {
              actionButtons.add(
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag, color: Colors.white),
                  onPressed: playerId == null
                      ? null
                      : () => toggleReady(roomId, playerId, myReady),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myReady ? Colors.green[700] : mmAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontFamily: mmFont,
                      fontSize: 18, letterSpacing: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: mmAccent, width: 2),
                    ),
                    elevation: 4,
                  ),
                  label: Text(myReady ? '準備解除' : '準備完了',
                    style: const TextStyle(fontFamily: mmFont),
                  ),
                ),
              );
            }

            return Scaffold(
              backgroundColor: mmBackground,
              appBar: AppBar(
                backgroundColor: Colors.black87,
                leading: const Icon(Icons.local_police, color: mmAccent),
                title: Text(
                  '事件の導入',
                  style: const TextStyle(
                    fontFamily: mmFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [Shadow(color: mmAccent, blurRadius: 3)],
                  ),
                ),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.all(18.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: mmCard.withOpacity(0.98),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: mmAccent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(2, 7),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Text(
                                problemData!['title'] ?? '',
                                style: const TextStyle(
                                  fontFamily: mmFont,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: mmAccent,
                                  letterSpacing: 2,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                problemData!['story'] ?? '',
                                style: const TextStyle(
                                  fontFamily: mmFont,
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ...actionButtons,
                      const SizedBox(height: 14),
                      if (!isHost)
                        Text(
                          'ホストが全員の準備完了を確認後、配役を開始します。',
                          style: TextStyle(
                            fontFamily: mmFont,
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (isHost && !allReady)
                        Text(
                          '全員が準備完了ボタンを押すと配役スタートボタンが押せます。',
                          style: TextStyle(
                            fontFamily: mmFont,
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (rolesAssigned)
                        Text(
                          'すでに配役が完了しています。',
                          style: const TextStyle(
                            fontFamily: mmFont,
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}