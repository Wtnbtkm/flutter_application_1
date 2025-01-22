import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart'; // 次のページ用のファイルをインポート
//起動画面
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('起動画面'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 次のページに遷移
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
          child: const Text('ホーム画面へ'),
        ),
      ),
    );
  }
}
