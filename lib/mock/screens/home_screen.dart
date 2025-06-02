import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/GameState_Screen.dart';
import 'package:flutter_application_1/mock/screens/problem_list_screen.dart';
import 'package:flutter_application_1/mock/screens/player_registration_screen.dart';
import 'package:flutter_application_1/mock/screens/settings_screen.dart';
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
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // タイトル
                  Text(
                    'ホーム画面です',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  // ボタン郡
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LaunchScreen()),
                      );
                    },
                    child: const Text('起動画面へ'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProblemListScreen()),
                      );
                    },
                    child: const Text('問題一覧へ'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                    child: const Text('設定画面へ'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text('ログイン画面へ'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlayerRegistrationScreen()),
                      );
                    },
                    child: const Text('プレイヤー名の登録'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GameStateScreen()),
                      );
                    },
                    child: const Text('ゲーム管理画面へ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}