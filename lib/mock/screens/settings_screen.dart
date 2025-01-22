import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定画面'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '設定画面',
              style: Theme.of(context).textTheme.headlineMedium,
            ), 
        const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigatorを使ってHomeScreenに遷移
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false, // これにより全ての既存ルートを破棄
                );
              },
              child: const Text('ホームへ戻る'),
            ),
          ],
        ),
      ),
    );
  }
}