// game_lobby_page.dart
import 'package:flutter/material.dart';

class GameLobbyScreen extends StatelessWidget {
  final String problemTitle;

  const GameLobbyScreen({Key? key, required this.problemTitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ロビー - $problemTitle')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('選択された問題: $problemTitle'),
            Text('他のプレイヤーの参加を待っています...'),
            ElevatedButton(
              onPressed: () {
                // ここでプレイヤーを登録し、役職を割り振る処理へ
              },
              child: Text('ゲーム開始'),
            ),
          ],
        ),
      ),
    );
  }
}