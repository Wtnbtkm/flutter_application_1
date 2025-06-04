import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_application_1/mock/screens/charactersheet_screen.dart';

class StoryIntroScreen extends StatefulWidget {
  final String problemId;
  const StoryIntroScreen({Key? key, required this.problemId}) : super(key: key);

  @override
  State<StoryIntroScreen> createState() => _StoryIntroScreenState();
}

class _StoryIntroScreenState extends State<StoryIntroScreen> {
  Map<String, dynamic>? problemData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProblemData();
  }

  Future<void> loadProblemData() async {
    final jsonString = await rootBundle.loadString('assets/problems/${widget.problemId}.json');
    setState(() {
      problemData = json.decode(jsonString);
      loading = false;
    });
  }

  // 配役重複がないようにする
  Future<void> assignCharactersToPlayers(String roomId) async {
    if (problemData == null) return;
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (roomDoc.data()?['rolesAssigned'] == true) {
      // すでに配役済み
      return;
    }

    final playersSnapshot = await roomRef.collection('players').get();
    final players = playersSnapshot.docs.toList();

    // プレイヤー数を確認
    final characterTemplates = List<Map<String, dynamic>>.from(problemData!['characters'] as List);
    if (players.length > characterTemplates.length) {
      throw Exception('プレイヤー数が配役数を超えています。');
    }

    // 配役もプレイヤーもシャッフル
    characterTemplates.shuffle();
    players.shuffle();

    // 1:1で割り当て
    for (int i = 0; i < players.length; i++) {
      final playerDoc = players[i];
      final character = characterTemplates[i];
      await roomRef.collection('players').doc(playerDoc.id).set({
        'role': character['role'],
        'description': character['description'],
        'evidence': character['evidence'],
        'winConditions': character['winConditions'],
      }, SetOptions(merge: true));
    }

    // 配役済みフラグ
    await roomRef.update({'rolesAssigned': true});
  }

  @override
  Widget build(BuildContext context) {
    final playerId = FirebaseAuth.instance.currentUser?.uid;
    final roomId = ModalRoute.of(context)?.settings.arguments as String?;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (problemData == null) {
      return const Scaffold(
        body: Center(child: Text('問題データ読み込み失敗')),
      );
    }

    // ここからFirestoreでroom情報を取得してホスト判定・準備完了判定
     return roomId == null
      ? Scaffold(
          body: Center(child: Text('ルームIDが見つかりません。')),
        )
      : StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final hostUid = data['hostUid'] as String?;
            final players = List<String>.from(data['players'] ?? []);
            final readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
            final requiredPlayers = data['requiredPlayers'] ?? players.length;
            final isHost = hostUid == playerId;
            final allReady = players.length == readyPlayers.length && players.length == requiredPlayers;
            final rolesAssigned = data['rolesAssigned'] == true;

            // 参加者側：配役済みなら自動でキャラシートへ遷移
            if (!isHost && rolesAssigned) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CharacterSheetScreen(
                      roomId: roomId,
                      playerUid: playerId!,
                      problemId: widget.problemId,
                    ),
                  ),
                );
              });
            }

            return Scaffold(
              appBar: AppBar(title: Text(problemData!['title'] ?? '')),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      problemData!['story'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    if (isHost)
                      ElevatedButton(
                        onPressed: (allReady && !rolesAssigned)
                            ? () async {
                                try {
                                  await assignCharactersToPlayers(roomId);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CharacterSheetScreen(
                                        roomId: roomId,
                                        playerUid: playerId!,
                                        problemId: widget.problemId,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('配役失敗: $e')),
                                  );
                                }
                              }
                            : null,
                        child: const Text('配役スタート'),
                      ),
                    if (!isHost)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'ホストが全員の準備完了を確認後に配役を開始します。',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
    }
}