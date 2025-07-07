import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // pubspec.yamlで登録想定

class PrivateChatPhaseWidget extends StatelessWidget {
  final String roomId;
  final int discussionRound;
  final bool privateChatPhase;
  final bool canChoosePrivateChatPartner;
  final VoidCallback onShowPartnerSelectDialog;
  final Future<void> Function()? onPrivateChatEnd;

  const PrivateChatPhaseWidget({
    Key? key,
    required this.roomId,
    required this.discussionRound,
    required this.privateChatPhase,
    required this.canChoosePrivateChatPartner,
    required this.onShowPartnerSelectDialog,
    this.onPrivateChatEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 全員終了チェックを呼び出し（副作用なので注意。必要なら他の場所で呼び出す設計もOK）
    onPrivateChatEnd?.call();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('privateChats')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: mmBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isNotEmpty) {
          final allInactive = docs.every((doc) => (doc.data() as Map<String, dynamic>)['active'] == false);
          if (allInactive && privateChatPhase) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onPrivateChatEnd?.call();
            });
          }
        }

        return Scaffold(
          backgroundColor: mmBackground,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            elevation: 7,
            shadowColor: mmAccent.withOpacity(0.3),
            centerTitle: true,
            title: Text(
              '個別チャットフェーズ 第$discussionRoundラウンド',
              style: const TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [Shadow(color: mmAccent, blurRadius: 3)],
              ),
            ),
            actions: [
              if (canChoosePrivateChatPartner)
                IconButton(
                  icon: const Icon(Icons.forum, color: mmAccent),
                  tooltip: '個別チャット相手を選択',
                  onPressed: onShowPartnerSelectDialog,
                ),
            ],
          ),
          body: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: mmCard.withOpacity(0.98),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: mmAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(2, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum, color: mmAccent, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    "個別チャットフェーズ 第$discussionRoundラウンド",
                    style: const TextStyle(
                      fontFamily: mmFont,
                      color: mmAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 1.1,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "全員の個別チャットが終了すると\n次の話し合いフェーズに進みます。",
                    style: TextStyle(
                      fontFamily: mmFont,
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}