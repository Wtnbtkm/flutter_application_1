import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';
import 'package:flutter_application_1/mock/widgets/custom_button.dart';
// 設定画面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            CustomButton(
              text: 'ホームへ戻る',
              onPressed: () {
                // Navigatorを使ってHomeScreenに遷移
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false, // これにより全ての既存ルートを破棄
                );
              },
              backgroundColor: Colors.green, // 背景色をオレンジに設定
              textColor: Colors.white, // 文字色を白に設定
              borderRadius: 20.0, // 角丸を設定
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), // 余白を調整
            ),
          ],
        ),
      ),
    );
  }
}