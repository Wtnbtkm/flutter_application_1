import 'package:flutter/material.dart';

class CharacterSheetScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Firestore からユーザーの配役情報を取得
    return Scaffold(
      appBar: AppBar(title:const Text('配役')),
      body: Column(
        children: [
          Text('あなたの役職: エミリー・ホワイト'),
          Text('役割説明と証拠、勝利条件...'),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/discussion'),
            child: Text('推理フェーズへ'),
          ),
        ],
      ),
    );
  }
}