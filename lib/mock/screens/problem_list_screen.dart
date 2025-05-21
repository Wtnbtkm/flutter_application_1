import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/room_choice_screen.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';
import 'package:flutter_application_1/mock/widgets/custom_button.dart';
//参加人数と問題一覧
class ProblemListScreen extends StatelessWidget {
  const ProblemListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> problems = [
      {'title': '影の中の告白', 'requiredPlayers': 5},
      {'title': '仮タイトル2', 'requiredPlayers': 4},
      {'title': '仮タイトル3', 'requiredPlayers': 3},
      {'title': '仮タイトル3', 'requiredPlayers': 2},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('問題一覧'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '問題一覧',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: problems.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(problems[index]['title']),
                      subtitle: Text('必要人数: ${problems[index]['requiredPlayers']}人'),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomChoiceScreen(
                              problemTitle: problems[index]['title'],
                              requiredPlayers: problems[index]['requiredPlayers'],
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
              backgroundColor: Colors.green,
              textColor: Colors.white,
              borderRadius: 20.0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
          ],
        ),
      ),
    );
  }
}
