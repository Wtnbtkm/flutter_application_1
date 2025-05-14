import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/gamelobby_screen.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';
import 'package:flutter_application_1/mock/widgets/custom_button.dart';

class ProblemListScreen extends StatelessWidget {
  const ProblemListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 仮の問題リスト（今後Firestoreなどから取得しても良い）
    final List<String> problems = [
      '影の中の告白',
      '仮タイトル2',
      '仮タイトル3',
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
                      title: Text(problems[index]),
                      trailing: Icon(Icons.arrow_forward),
                      onTap: () {
                        // 問題を選択してロビーへ遷移
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GameLobbyScreen(problemTitle: problems[index]),
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
