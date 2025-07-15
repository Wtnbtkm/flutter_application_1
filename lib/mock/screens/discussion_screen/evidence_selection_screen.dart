import 'package:flutter/material.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // pubspec.yamlに登録想定

class EvidenceSelectionScreen extends StatelessWidget {
  final List<Map<String, dynamic>> commonEvidence;
  final List<int> myChosen;
  final List<String> playerOrder;
  final int evidenceTurn;
  final Set<int> alreadyChosen;
  final bool isMyTurnDraft;
  final String playerUid;
  final Future<void> Function(int evidenceIndex) onChooseEvidence;

  const EvidenceSelectionScreen({
    super.key,
    required this.commonEvidence,
    required this.myChosen,
    required this.playerOrder,
    required this.evidenceTurn,
    required this.alreadyChosen,
    required this.isMyTurnDraft,
    required this.playerUid,
    required this.onChooseEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = myChosen.length;
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.3),
        centerTitle: true,
        title: Text(
          '証拠ドラフトフェーズ',
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: mmAccent, blurRadius: 3)],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: mmCard.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: mmAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 8,
                    offset: const Offset(2, 7),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  '— 共通証拠をドラフト —\n順番に共通証拠を2つずつ選びます。\n選んだ証拠は自分だけが閲覧できます。',
                  style: const TextStyle(
                    fontFamily: mmFont,
                    color: mmAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 1.1,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isMyTurnDraft && selectedCount < 2) ...[
              Text(
                "あなたの番です。共通証拠を選んでください（あと${2 - selectedCount}つ）",
                style: const TextStyle(
                  fontFamily: mmFont,
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  for (int i = 0; i < commonEvidence.length; i++)
                    ElevatedButton(
                      onPressed: alreadyChosen.contains(i)
                          ? null
                          : () async {
                              await onChooseEvidence(i);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alreadyChosen.contains(i)
                            ? Colors.grey[700]
                            : mmAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(
                            color: alreadyChosen.contains(i)
                                ? Colors.grey[800]!
                                : mmAccent,
                            width: 2,
                          ),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        commonEvidence[i]['title'],
                        style: const TextStyle(
                          fontFamily: mmFont,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (selectedCount > 0)
                Text(
                  "選択済み: ${myChosen.map((i) => commonEvidence[i]['title']).join('、')}",
                  style: const TextStyle(
                    fontFamily: mmFont,
                    color: Colors.amberAccent,
                    fontSize: 15,
                  ),
                ),
            ] else ...[
              Text(
                playerOrder.isNotEmpty
                    ? "${playerOrder[evidenceTurn] == playerUid ? "あなた" : "他のプレイヤー"}が証拠選択中です。しばらくお待ちください。"
                    : "証拠選択フェーズです。",
                style: const TextStyle(
                  fontFamily: mmFont,
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "あなたの選択済み証拠: ${myChosen.map((i) => commonEvidence[i]['title']).join('、')}",
                style: const TextStyle(
                  fontFamily: mmFont,
                  color: Colors.amberAccent,
                  fontSize: 15,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}