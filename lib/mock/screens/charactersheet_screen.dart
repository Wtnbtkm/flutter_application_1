//それぞれのプレイヤーの配役を表示
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen.dart';

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
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({'gameStarted2': true});
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
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (playerData == null || problemData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: Text('データ取得エラー', style: TextStyle(color: Colors.white))),
      );
    }

    final evidenceList = List.from(playerData?['evidence'] ?? []);
    final winConditionsList = List.from(playerData?['winConditions'] ?? []);
    final commonEvidenceList = List.from(problemData?['commonEvidence'] ?? []);
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
                        backgroundColor: myReady ? Colors.green[700] : Colors.amber[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, letterSpacing: 2),
                      ),
                      label: Text(myReady ? '準備解除' : '準備完了'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      onPressed: allReady ? () => startGame() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allReady ? Colors.red[800] : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, letterSpacing: 2),
                      ),
                      label: const Text('ゲームスタート'),
                    ),
                  ]);
                } else {
                  actionButtons.add(
                    ElevatedButton.icon(
                      icon: const Icon(Icons.flag, color: Colors.white),
                      onPressed: () => toggleReady(myReady),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myReady ? Colors.green[700] : Colors.amber[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, letterSpacing: 2),
                      ),
                      label: Text(myReady ? '準備解除' : '準備完了'),
                    ),
                  );
                }

                return Scaffold(
                  backgroundColor: const Color(0xFF23232A),
                  appBar: AppBar(
                    backgroundColor: Colors.black87,
                    leading: const Icon(Icons.assignment_ind, color: Colors.amber),
                    title: const Text("あなたのキャラクター", style: TextStyle(letterSpacing: 2)),
                    centerTitle: true,
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 10,
                            color: Colors.black54,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('事件の舞台: ${problemData!['title']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        color: Colors.amber,
                                        letterSpacing: 2,
                                      )),
                                  const SizedBox(height: 8),
                                  Text(problemData!['story'] ?? '',
                                      style: const TextStyle(fontSize: 16, color: Colors.white70)),
                                  const Divider(color: Colors.amber, height: 36, thickness: 1.2),
                                  Text('あなたの役職: ${playerData!['role']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.amber)),
                                  const SizedBox(height: 8),
                                  Text('背景: ${playerData!['description'].toString()}',
                                      style: const TextStyle(fontSize: 16, color: Colors.white)),
                                  const SizedBox(height: 12),
                                  Text('証拠:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[700])),
                                  ...evidenceList.map<Widget>((e) => Text('- $e', style: const TextStyle(color: Colors.white))),
                                  const SizedBox(height: 12),
                                  Text('勝利条件:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[700])),
                                  ...winConditionsList.map<Widget>((e) => Text('- $e', style: const TextStyle(color: Colors.white))),
                                  const Divider(color: Colors.amber, height: 36, thickness: 1.2),
                                  if (myCommonEvidenceList.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('あなたが選んだ共通証拠', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[800])),
                                        ...myCommonEvidenceList.map<Widget>((e) => Text('- $e', style: const TextStyle(color: Colors.white))),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ...actionButtons,
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