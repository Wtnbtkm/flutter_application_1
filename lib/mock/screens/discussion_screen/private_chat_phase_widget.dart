import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen/playerinfo_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // JSONデータの読み込み用
//個別チャットの待機の画面
// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // pubspec.yamlで登録想定

class PrivateChatPhaseWidget extends StatefulWidget {
  final String problemId; // 問題ID
  final String roomId;
  final int discussionRound;
  final bool privateChatPhase;
  final bool canChoosePrivateChatPartner;
  final VoidCallback onShowPartnerSelectDialog;
  final Map<String, dynamic>? playersData;
  final Map<String, dynamic>? problemData;
  final List<Map<String, dynamic>> commonEvidence;
  final Future<void> Function()? onPrivateChatEnd;

  const PrivateChatPhaseWidget({
    required this.problemId, 
    required this.roomId,
    required this.discussionRound,
    required this.privateChatPhase,
    required this.canChoosePrivateChatPartner,
    required this.onShowPartnerSelectDialog,
    required this.playersData,
    required this.problemData,
    required this.commonEvidence,
    this.onPrivateChatEnd,
    super.key,
  });

  @override
  State<PrivateChatPhaseWidget> createState() => _PrivateChatPhaseWidgetState();
}

class _PrivateChatPhaseWidgetState extends State<PrivateChatPhaseWidget> {
  bool _calledEnd = false;

  Future<void> _onShowPlayerInfoDialog(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    //print('現在のUID: $uid');
    //print('playersData: ${widget.playersData}');

    if (uid != null && widget.playersData?.containsKey(uid) == true) {
      final playerRaw = widget.playersData![uid];
      final playerData = Map<String, dynamic>.from(playerRaw);

      Map<String, dynamic> loadedProblemData = widget.problemData != null
          ? Map<String, dynamic>.from(widget.problemData!)
          : {};

      if (loadedProblemData.isEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('problems')
              .doc(widget.problemId)
              .get();
          if (snap.exists) {
            loadedProblemData = snap.data() ?? {};
          } else {
            final jsonString = await DefaultAssetBundle.of(context)
                .loadString('assets/problems/${widget.problemId}.json');
            loadedProblemData = json.decode(jsonString);
          }
        } catch (e) {
          loadedProblemData = {'error': '問題データが見つかりません'};
        }
      }
      //print('chosenCommonEvidence: ${playerData['chosenCommonEvidence']}');

      showDialog(
        context: context,
        builder: (_) => PlayerInfoDialog(
          playerData: playerData,
          problemData: loadedProblemData, 
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プレイヤーデータが見つかりません')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
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
          if (allInactive && widget.privateChatPhase && !_calledEnd) {
            _calledEnd = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onPrivateChatEnd?.call();
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
              '個別チャットフェーズ 第${widget.discussionRound}ラウンド',
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
              IconButton(
                onPressed: () => _onShowPlayerInfoDialog(context),
                icon: const Icon(Icons.info, color: mmAccent),
                tooltip: 'プレイヤー情報',
              ),
              if (widget.canChoosePrivateChatPartner)
                IconButton(
                  icon: const Icon(Icons.forum, color: mmAccent),
                  tooltip: '個別チャット相手を選択',
                  onPressed: widget.onShowPartnerSelectDialog,
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
                    "個別チャットフェーズ 第${widget.discussionRound}ラウンド",
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
