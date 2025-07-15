import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evidence_selection_screen.dart';
import 'chat_message_bubble.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // フォントをpubspec.yamlに登録

class DiscussionPhaseWidget extends StatelessWidget {
  final String roomId;
  final String playerUid;
  final bool evidenceChoosingPhase;
  final int evidenceTurn;
  final List<String> playerOrder;
  final List<Map<String, dynamic>> commonEvidence;
  final List<int> myChosen;
  final bool canChoosePrivateChatPartner;
  final VoidCallback onShowPartnerSelectDialog;
  final VoidCallback onSendMessage;
  final TextEditingController controller;
  final bool discussionStarted;
  final bool discussionTimeUp;
  final int discussionSecondsLeft;
  final int discussionRound;
  final bool privateChatPhase;
  final String? currentPrivateChatterUid;
  final Map<String, dynamic>? problemData;
  final VoidCallback? onShowPlayerInfo;
  final Future<void> Function(int) onChooseEvidence;

  const DiscussionPhaseWidget({
    super.key,
    required this.roomId,
    required this.playerUid,
    required this.evidenceChoosingPhase,
    required this.evidenceTurn,
    required this.playerOrder,
    required this.commonEvidence,
    required this.myChosen,
    required this.canChoosePrivateChatPartner,
    required this.onShowPartnerSelectDialog,
    required this.onSendMessage,
    required this.controller,
    required this.discussionStarted,
    required this.discussionTimeUp,
    required this.discussionSecondsLeft,
    required this.discussionRound,
    required this.privateChatPhase,
    required this.currentPrivateChatterUid,
    required this.problemData,
    required this.onChooseEvidence,
    this.onShowPlayerInfo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .snapshots(),
      builder: (context, psnap) {
        if (!psnap.hasData) {
          return const Scaffold(
            backgroundColor: mmBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 証拠選択フェーズ
        Map<String, List<int>> allChosen = {};
        List<int> myChosenLocal = myChosen;
        for (final doc in psnap.data!.docs) {
          allChosen[doc.id] = List<int>.from(
              (doc.data() as Map<String, dynamic>)['chosenCommonEvidence'] ?? []);
          if (doc.id == playerUid) {
            myChosenLocal = allChosen[doc.id]!;
          }
        }

        if (evidenceChoosingPhase) {
          final isMyTurnDraft = playerOrder.isNotEmpty &&
              playerOrder[evidenceTurn] == playerUid;
          final alreadyChosen = allChosen.values.expand((e) => e).toSet();

          return EvidenceSelectionScreen(
            commonEvidence: commonEvidence,
            myChosen: myChosenLocal,
            playerOrder: playerOrder,
            evidenceTurn: evidenceTurn,
            alreadyChosen: alreadyChosen.cast<int>(),
            isMyTurnDraft: isMyTurnDraft,
            playerUid: playerUid,
            onChooseEvidence: onChooseEvidence,
          );
        }

        // チャットフェーズ
        return Scaffold(
          backgroundColor: mmBackground,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            elevation: 7,
            shadowColor: mmAccent.withOpacity(0.3),
            title: Text(
              '推理・チャット 第$discussionRoundラウンド',
              style: const TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                fontSize: 21,
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
              IconButton(
                icon: const Icon(Icons.assignment_ind, color: mmAccent),
                onPressed: onShowPlayerInfo,
              )
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: mmCard.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: mmAccent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(1, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
                      child: Text(
                        '${discussionSecondsLeft ~/ 60}:${(discussionSecondsLeft % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontFamily: mmFont,
                          color: mmAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 40,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                ),
                if (privateChatPhase && !canChoosePrivateChatPartner)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      currentPrivateChatterUid == playerUid
                          ? "個別チャットで話せる相手がいません"
                          : currentPrivateChatterUid == null
                              ? "個別チャット順番待ち"
                              : "現在${currentPrivateChatterUid == playerUid ? "あなた" : "他のプレイヤー"}が個別チャット相手を選択中です",
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: mmAccent,
                        fontSize: 15,
                      ),
                    ),
                  ),
                if (discussionTimeUp)
                  Container(
                    decoration: BoxDecoration(
                      color: mmAccent.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      "話し合いの制限時間が終了しました。",
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                    decoration: BoxDecoration(
                      color: mmCard.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: mmAccent, width: 2),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(roomId)
                          .collection('messages')
                          .orderBy('timestamp', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          itemCount: docs.length,
                          itemBuilder: (context, idx) {
                            final data =
                                docs[idx].data() as Map<String, dynamic>;
                            final senderUid = data['uid'] ?? '';
                            final text = data['text'] ?? '';
                            return ChatMessageBubble(
                              roomId: roomId,
                              senderUid: senderUid,
                              text: text,
                              isMe: senderUid == playerUid,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  color: Colors.black26,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: mmFont,
                            fontSize: 16,
                          ),
                          enabled: discussionStarted && !discussionTimeUp,
                          decoration: InputDecoration(
                            hintText: 'メッセージを入力',
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontFamily: mmFont,
                            ),
                            filled: true,
                            fillColor: mmBackground.withOpacity(0.80),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => onSendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: mmAccent),
                        onPressed: (discussionStarted && !discussionTimeUp)
                            ? onSendMessage
                            : null,
                        tooltip: "送信",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}