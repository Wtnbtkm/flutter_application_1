import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

class CharacterSheetScreen extends StatefulWidget {
  final String roomId;
  final String playerUid;
  final String problemId;

  const CharacterSheetScreen({
    Key? key,
    required this.roomId,
    required this.playerUid,
    required this.problemId,
  }) : super(key: key);

  @override
  State<CharacterSheetScreen> createState() => _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends State<CharacterSheetScreen> {
  Map<String, dynamic>? playerData;
  Map<String, dynamic>? problemData;
  bool loading = true;
  String? hostUid;
  bool navigated = false;

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    final playerDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .get();
    final jsonString = await rootBundle.loadString('assets/problems/${widget.problemId}.json');
    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();
    setState(() {
      playerData = playerDoc.data();
      problemData = json.decode(jsonString);
      hostUid = roomDoc.data()?['hostUid'];
      loading = false;
    });
  }

  Future<void> toggleReady(bool isReady) async {
    final playerRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid);
    await playerRef.set({'isReady': !isReady}, SetOptions(merge: true));
  }

  Future<bool> checkAllReady() async {
    final playersSnapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .get();
    return playersSnapshot.docs.isNotEmpty &&
        playersSnapshot.docs.every(
            (d) => (d.data()['isReady'] ?? false) == true
        );
  }

  Future<void> startGame() async {
    final allReady = await checkAllReady();
    if (!allReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全員が準備完了していません')),
      );
      return;
    }
      // criminalUid を設定する処理を追加
    await assignCriminal(widget.roomId);
    
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({'gameStarted2': true});
  }

  // ファイル末尾に追加（Stateクラス外）
  Future<void> assignCriminal(String roomId) async {
    final playersRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('players');

    final snapshot = await playersRef.get();
    final players = snapshot.docs;

    for (final doc in players) {
      final data = doc.data();
      if (data['isCriminal'] == true) {
        final criminalUid = doc.id;

        // rooms ドキュメントに犯人 UID を保存
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .update({'criminalUid': criminalUid});
        break;
      }
    }
  }

  void navigateToDiscussionScreen() {
    if (!navigated) {
      navigated = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DiscussionScreen(
            roomId: widget.roomId,
            problemId: widget.problemId,
            playerUid: widget.playerUid,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: mmBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (playerData == null || problemData == null) {
      return const Scaffold(
        backgroundColor: mmBackground,
        body: Center(child: Text('データ取得エラー', style: TextStyle(color: Colors.white))),
      );
    }

    final evidenceList = List.from(playerData?['evidence'] ?? []);
    final winConditionsList = List.from(playerData?['winConditions'] ?? []);
    final commonEvidenceList = List.from(problemData?['commonEvidence'] ?? []);
    final isCriminal = playerData ?['isCriminal'] ?? false;
    final chosenEvidenceIndexes = List<int>.from(playerData?['chosenCommonEvidence'] ?? []);
    final myCommonEvidenceList = [for (final i in chosenEvidenceIndexes) commonEvidenceList[i]];
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isHost = (hostUid == myUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, snapshot) {
        final docData = snapshot.data?.data() as Map<String, dynamic>?;
        if (docData != null && docData['gameStarted2'] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigateToDiscussionScreen();
          });
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('players')
              .doc(widget.playerUid)
              .snapshots(),
          builder: (context, snap) {
            final bool myReady = (snap.data?.data() as Map<String, dynamic>?)?['isReady'] == true;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('players')
                  .snapshots(),
              builder: (context, allPlayersSnap) {
                final bool allReady = allPlayersSnap.hasData &&
                    allPlayersSnap.data!.docs.isNotEmpty &&
                    allPlayersSnap.data!.docs.every(
                        (d) => (d.data() as Map<String, dynamic>?)?['isReady'] == true
                    );

                List<Widget> actionButtons = [];
                if (isHost) {
                  actionButtons.addAll([
                    ElevatedButton.icon(
                      icon: const Icon(Icons.flag, color: Colors.white),
                      onPressed: () => toggleReady(myReady),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myReady ? Colors.green[700] : mmAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontFamily: mmFont,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
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
                      onPressed: allReady ? () => startGame() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allReady ? mmAccent : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontFamily: mmFont,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(color: mmAccent, width: 2),
                        ),
                        elevation: 4,
                      ),
                      label: const Text('ゲームスタート', style: TextStyle(fontFamily: mmFont)),
                    ),
                  ]);
                } else {
                  actionButtons.add(
                    ElevatedButton.icon(
                      icon: const Icon(Icons.flag, color: Colors.white),
                      onPressed: () => toggleReady(myReady),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myReady ? Colors.green[700] : mmAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontFamily: mmFont,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
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
                    leading: const Icon(Icons.assignment_ind, color: mmAccent),
                    title: Text(
                      "あなたのキャラクター",
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '事件の舞台: ${problemData!['title']}',
                                    style: const TextStyle(
                                      fontFamily: mmFont,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: mmAccent,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    problemData!['story'] ?? '',
                                    style: const TextStyle(
                                      fontFamily: mmFont,
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const Divider(color: mmAccent, height: 36, thickness: 1.2),
                                  Text(
                                    'あなたの役職: ${playerData!['role']}',
                                    style: const TextStyle(
                                      fontFamily: mmFont,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                      color: mmAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '背景: ${playerData!['description'].toString()}',
                                    style: const TextStyle(
                                      fontFamily: mmFont,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '証拠:',
                                    style: TextStyle(
                                      fontFamily: mmFont,
                                      fontWeight: FontWeight.bold,
                                      color: mmAccent.withOpacity(0.8),
                                    ),
                                  ),
                                  ...evidenceList.map<Widget>((e) => Text(
                                      '- $e',
                                      style: const TextStyle(
                                        fontFamily: mmFont,
                                        color: Colors.white,
                                      ),
                                    )),
                                  const SizedBox(height: 12),
                                  Text(
                                    '勝利条件:',
                                    style: TextStyle(
                                      fontFamily: mmFont,
                                      fontWeight: FontWeight.bold,
                                      color: mmAccent.withOpacity(0.8),
                                    ),
                                  ),
                                  ...winConditionsList.map<Widget>((e) => Text(
                                      '- $e',
                                      style: const TextStyle(
                                        fontFamily: mmFont,
                                        color: Colors.white,
                                      ),
                                    )),
                                  const Divider(color: mmAccent, height: 36, thickness: 1.2),
                                  Text(
                                    '犯人かどうか: ${playerData?['isCriminal'] ? '犯人' : '無実'}',
                                    style: TextStyle(
                                      fontFamily: mmFont,
                                      fontWeight: FontWeight.bold,
                                      color: mmAccent.withOpacity(0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (myCommonEvidenceList.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'あなたが選んだ共通証拠',
                                          style: TextStyle(
                                            fontFamily: mmFont,
                                            fontWeight: FontWeight.bold,
                                            color: mmAccent.withOpacity(0.85),
                                          ),
                                        ),
                                        ...myCommonEvidenceList.map<Widget>((e) => Text(
                                            '- $e',
                                            style: const TextStyle(
                                              fontFamily: mmFont,
                                              color: Colors.white,
                                            ),
                                          )),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          ...actionButtons,
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}