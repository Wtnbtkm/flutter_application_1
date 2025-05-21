import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//	プレイヤーが自分に割り当てられた「役職」「役割」「証拠」「勝利条件」を確認する画面
class CharacterSheetScreen extends StatelessWidget {
  final String roomId;
  final String playerId;

  const CharacterSheetScreen({
    Key? key,
    required this.roomId,
    required this.playerId,
  }) : super(key: key);

  Future<Map<String, dynamic>> fetchCharacterData() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(playerId)
        .get();

    if (!doc.exists) throw Exception('配役データが見つかりません');

    return doc.data()!;
  }

  Widget buildCommonIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("🎭 事件の舞台：『影の中の告白』", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("舞台はロンドンの高級ホテル。慈善イベントの最中に主催者アリスが殺害される密室事件。"),
        SizedBox(height: 8),
        Text("共通の証拠:"),
        Text("- 死因：毒物による心停止"),
        Text("- 密室状況（内側から鍵）"),
        Text("- 少し開いた窓、時間帯証言の食い違い"),
        Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('配役情報')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchCharacterData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: Text('配役データが見つかりません'));

          final data = snapshot.data!;
          final role = data['role'];
          final description = data['description'];
          final evidence = List<String>.from(data['evidence'] ?? []);
          final winConditions = List<String>.from(data['winConditions'] ?? []);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildCommonIntro(),
                  Text("あなたの役職：$role", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("役割・背景：\n$description"),
                  const SizedBox(height: 16),
                  Text("🔍 証拠：", style: TextStyle(fontWeight: FontWeight.bold)),
                  for (var e in evidence) Text("・$e"),
                  const SizedBox(height: 16),
                  Text("🏆 勝利条件：", style: TextStyle(fontWeight: FontWeight.bold)),
                  for (var wc in winConditions) Text("・$wc"),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/discussion');
                      },
                      child: const Text('推理フェーズへ'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}