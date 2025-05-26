import 'package:flutter/material.dart';
//結果の表示
/*
（犯人・結果公開画面）
目的：最後に誰が犯人だったのか、どんな結末になったのかを表示

必要機能：

投票結果と一致/不一致

犯人の正体表示

各キャラのその後の運命（文章などで）

エンディング的演出（BGM、効果音、画像）
 */
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
