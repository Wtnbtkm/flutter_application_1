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

  Future<void> assignCharactersToPlayers(String roomId) async {
    if (problemData == null) return;
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    // プレイヤーリスト取得（playersコレクション内に各uidドキュメントがある想定）
    final playersSnapshot = await roomRef.collection('players').get();
    final players = playersSnapshot.docs;
    final characterTemplates = problemData!['characters'] as List<dynamic>;
    if (players.length > characterTemplates.length) {
      throw Exception('プレイヤー数が配役数を超えています。');
    }
    final shuffled = List<Map<String, dynamic>>.from(characterTemplates)..shuffle();
    for (int i = 0; i < players.length; i++) {
      await roomRef.collection('players').doc(players[i].id).set({
        'role': shuffled[i]['role'],
        'description': shuffled[i]['description'],
        'evidence': shuffled[i]['evidence'],
        'winConditions': shuffled[i]['winConditions'],
      }, SetOptions(merge: true));
    }
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
            ElevatedButton(
              onPressed: () async {
                if (roomId == null || playerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('プレイヤーIDまたはルームIDが見つかりません。'),
                  ));
                  return;
                }

                try {
                  await assignCharactersToPlayers(roomId);

                  // ★ 直接画面遷移する場合はこちら
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CharacterSheetScreen(
                        roomId: roomId,
                        playerUid: playerId,
                        problemId: widget.problemId,
                      ),
                    ),
                  );

                  // ★ ルート名遷移の場合は下記コメントアウトを利用
                  // Navigator.pushNamed(
                  //   context,
                  //   '/characterSheet',
                  //   arguments: {
                  //     'roomId': roomId,
                  //     'playerId': playerId,
                  //     'problemId': widget.problemId,
                  //   },
                  // );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('配役失敗: $e')),
                  );
                }
              },
              child: const Text('配役スタート'),
            ),
          ],
        ),
      ),
    );
  }
}