import 'package:flutter/material.dart';
//結果の表示
class ResulScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('結果発表')),
      body: Column(
        children: [
          Text('投票結果と勝敗'),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/home'),
            child: Text('ホームへ戻る'),
          ),
        ],
      ),
    );
  }
}
