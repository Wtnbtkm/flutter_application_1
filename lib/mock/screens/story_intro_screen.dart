import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoryIntroScreen extends StatelessWidget {
  StoryIntroScreen({super.key});

  // 🔸 配役マスターデータ（好きなように追加・編集可）
  final List<Map<String, dynamic>> characterTemplates = [
    {
      'role': 'エミリー・ホワイト',
      'description': ['表の顔 華やかな社交界の顔、ジャーナリスト','裏の顔アリスに過去の不正取材を知られ、脅されていた'],
      'evidence': ['ポケットから敗れた取材メモ（「彼女は私の秘密を・・」とある）', '殺害時刻、彼女は人前にいたとされるが証言は曖昧','所特品に劇薬の小瓶','エミリーのPCに「アリス 暴露 記事準備中」というファイルがある'],
      'winConditions': ['冤罪を晴らし、真犯人を特定する', '真犯人として逃げ切る'],
    },
    {
      'role': '主催者の妹',
      'description': '被害者アリスの妹。事件に関して何か知っている様子。',
      'evidence': ['姉の遺言を持っていた', '不審な時間に部屋の外にいた'],
      'winConditions': ['自分の無実を証明する'],
    },
    {
      'role': 'ホテル従業員',
      'description': '事件当日のサービスを担当していたスタッフ。状況をよく見ていたが、何かを隠している？',
      'evidence': ['カメラの死角を指摘', '清掃記録と矛盾あり'],
      'winConditions': ['真相を明かさずに生き延びる'],
    },
    {
      'role': 'ジャーナリスト',
      'description': '真実を追い求める記者。スクープを狙って事件に首を突っ込む。',
      'evidence': ['密談を盗み聞きしていた', '事件前に取材していた'],
      'winConditions': ['犯人の動機を暴く'],
    },
  ];

  // 🔸 配役を各プレイヤーに割り当てる処理
  Future<void> assignCharactersToPlayers(String roomId) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final playersSnapshot = await roomRef.collection('players').get();

    final players = playersSnapshot.docs;
    final availableTemplates = List<Map<String, dynamic>>.from(characterTemplates);
    availableTemplates.shuffle(Random());

    if (players.length > availableTemplates.length) {
      throw Exception('プレイヤー数が配役数を超えています。');
    }

    for (int i = 0; i < players.length; i++) {
      final playerDoc = players[i];
      final assignedRole = availableTemplates[i];

      await roomRef.collection('players').doc(playerDoc.id).set({
        'role': assignedRole['role'],
        'description': assignedRole['description'],
        'evidence': assignedRole['evidence'],
        'winConditions': assignedRole['winConditions'],
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Firebase Auth から現在のユーザーIDを取得
    final playerId = FirebaseAuth.instance.currentUser?.uid;
    // 👇 実際の roomId はルーム作成時に保存されているものを受け取る必要があります
    final roomId = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      appBar: AppBar(title: const Text("ゲーム開始")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              '影の中の告白\n\n'
              ' ロンドンの高級ホテルで行われる慈善イベントの夜。富豪の古参メンバーが集まり、地元の慈善事業を支援しています。\n'
              'しかし、夜が進むにつれて、一人のメンバーが突然殺されます。\n'
              ' イベントの最中、部屋の中でアリスが遺体として発見されます。部屋は内部から施錠されており、外からの侵入は考えにくい状況です。怪しい動きを見せるのは、ウィリアムとエミリーで、それぞれの証言には穴があります。ジョンは事件解決に執念を燃やし、レベッカは自分のホテルでの事件に動揺します。\n'
              '事件の真相を暴くのは誰か、犯人として逃げ切るのは誰か？',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (roomId == null || playerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('プレイヤーIDまたはルームIDが見つかりません。'),
                  ));
                  return;
                }

                try {
                  await assignCharactersToPlayers(roomId);
                  Navigator.pushNamed(
                    context,
                    '/characterSheet',
                    arguments: {'roomId': roomId, 'playerId': playerId},
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('配役失敗: $e')),
                  );
                }
              },
              child: const Text('配役スタート'),
            ),
          ],
        ),
      ),
    );
  }
}
