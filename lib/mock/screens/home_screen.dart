import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/detail_screen.dart';
import 'package:flutter_application_1/mock/screens/settings_screen.dart';
import 'package:flutter_application_1/mock/screens/Next_screen.dart';
import 'package:flutter_application_1/mock/screens/launch_screen.dart';
import 'package:flutter_application_1/mock/screens/login_screen.dart';

// ホーム画面
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム画面'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ホーム画面です。'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LaunchScreen()),
                );
              },
              child: const Text('起動画面へ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NextScreen()),
                );
              },
              child: const Text('次の画面へ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DetailScreen()),
                );
              },
              child: const Text('詳細画面へ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
              child: const Text('設定画面へ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('ログイン画面へ'),
            ),
          ],
        ),
      ),
    );
  }
}
