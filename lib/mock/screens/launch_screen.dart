import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart'; // 次のページ用のファイルをインポート
import 'package:flutter_application_1/mock/widgets/custom_button.dart'; // カスタムボタンのインポート

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
        child: CustomButton(
          text: 'ホーム画面へ',
          onPressed: () {
            // 次のページに遷移
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
          backgroundColor: Colors.orange, // ボタンの背景色をオレンジに設定
          textColor: Colors.white, // テキストの色を白に設定
          borderRadius: 16.0, // 角丸を設定
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), // 余白を調整
        ),
      ),
    );
  }
}
