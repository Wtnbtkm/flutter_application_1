import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/room_choice_screen.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';
import 'package:flutter_application_1/mock/widgets/custom_button.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定


class ProblemListScreen extends StatelessWidget {
  const ProblemListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> problems = [
      {'id': 'kage_no_naka_no_kokuhaku', 'title': '影の中の告白', 'requiredPlayers': 4},
      {'id': 'provisional2', 'title': '仮タイトル2', 'requiredPlayers': 4},
      {'id': 'provisional3', 'title': '仮タイトル3', 'requiredPlayers': 3},
      {'id': 'provisional4', 'title': '仮タイトル4', 'requiredPlayers': 2},
    ];

    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        leading: const Icon(Icons.menu_book, color: mmAccent),
        title: Text(
          '事件ファイル選択',
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: mmAccent, blurRadius: 3)],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Text(
              '— 事件ファイル一覧 —',
              style: const TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: mmAccent,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              '挑む事件を選んでください',
              style: const TextStyle(
                fontFamily: mmFont,
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: problems.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: mmCard.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: mmAccent.withOpacity(0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.book, color: mmAccent, size: 28),
                      title: Text(
                        problems[index]['title'],
                        style: const TextStyle(
                          fontFamily: mmFont,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      subtitle: Text(
                        '必要人数: ${problems[index]['requiredPlayers']}人',
                        style: const TextStyle(
                          fontFamily: mmFont,
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: mmAccent),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomChoiceScreen(
                              problemTitle: problems[index]['title'],
                              requiredPlayers: problems[index]['requiredPlayers'],
                              problemId: problems[index]['id'],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'ホームへ戻る',
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              },
              backgroundColor: mmAccent,
              textColor: Colors.white,
              borderRadius: 22.0,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}