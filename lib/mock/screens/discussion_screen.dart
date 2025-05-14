import 'package:flutter/material.dart';
// 推理・チャット画面
class DiscussionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('推理・チャット')),
      body:const Column(
        children: [
          Expanded(child: Text('チャットログ表示')),
          TextField(decoration: InputDecoration(labelText: 'メッセージ')),
        ],
      ),
    );
  }
}