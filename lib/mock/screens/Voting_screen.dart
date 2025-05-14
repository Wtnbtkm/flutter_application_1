import 'package:flutter/material.dart';
//投票画面
class VotingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投票フェーズ')),
      body: Column(
        children: [
          const Text('誰に投票しますか？'),
          // プレイヤー一覧を表示
          ElevatedButton(
            onPressed: () {
              // 投票をFirestoreに送信
              Navigator.pushNamed(context, '/result');
            },
            child:const Text('投票する'),
          ),
        ],
      ),
    );
  }
}
