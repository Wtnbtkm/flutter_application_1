import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/launch_screen.dart'; // LaunchPage をインポート

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 62, 219, 133)),
        useMaterial3: true,
      ),
      home: const LaunchScreen(), // 起動画面を LaunchPage に設定
    );
  }
}
