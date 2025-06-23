import 'package:flutter/material.dart';

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
    Key? key,
    required this.commonEvidence,
    required this.myChosen,
    required this.playerOrder,
    required this.evidenceTurn,
    required this.alreadyChosen,
    required this.isMyTurnDraft,
    required this.playerUid,
    required this.onChooseEvidence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selectedCount = myChosen.length;
    return Scaffold(
      backgroundColor: const Color(0xFF23232A),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('推理・チャット', style: TextStyle(letterSpacing: 2)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.black87,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '【証拠ドラフトフェーズ】\n順番に共通証拠を2つずつ選びます。\n選んだ証拠は自分だけが閲覧できます。',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isMyTurnDraft && selectedCount < 2) ...[
              Text(
                "あなたの番です。共通証拠を選んでください（あと${2 - selectedCount}つ）",
                style: const TextStyle(
                    color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < commonEvidence.length; i++)
                    ElevatedButton(
                      onPressed: alreadyChosen.contains(i)
                          ? null
                          : () async {
                              await onChooseEvidence(i);
                              // Firestore更新後、親のStreamBuilderで自動再描画される
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alreadyChosen.contains(i)
                            ? Colors.grey
                            : Colors.amber[800],
                      ),
                      child: Text(commonEvidence[i]['title'],
                          style: const TextStyle(color: Colors.white)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedCount > 0)
                Text(
                  "選択済み: ${myChosen.map((i) => commonEvidence[i]['title']).join('、')}",
                  style: const TextStyle(color: Colors.amberAccent),
                )
            ] else ...[
              Text(
                playerOrder.isNotEmpty
                    ? "${playerOrder[evidenceTurn] == playerUid ? "あなた" : "他のプレイヤー"}が証拠選択中です。しばらくお待ちください。"
                    : "証拠選択フェーズです。",
                style: const TextStyle(
                    color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 12),
              Text(
                "あなたの選択済み証拠: ${myChosen.map((i) => commonEvidence[i]['title']).join('、')}",
                style: const TextStyle(color: Colors.amberAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}