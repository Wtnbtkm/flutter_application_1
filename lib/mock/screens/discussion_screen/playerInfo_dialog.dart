import 'package:flutter/material.dart';
//配役情報を表示するためのダイアログ
// マーダーミステリー用カラーパレットとフォント
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // pubspec.yamlで登録

class PlayerInfoDialog extends StatelessWidget {
  final Map<String, dynamic> playerData;
  final Map<String, dynamic>? problemData;

  const PlayerInfoDialog({
    super.key,
    required this.playerData,
    required this.problemData,
  });

  @override
  Widget build(BuildContext context) {
    final evidenceList = List.from(playerData['evidence'] ?? []);
    final winConditionsList = List.from(playerData['winConditions'] ?? []);
    final description = playerData['description'] ?? '';
    final isCriminal = playerData['isCriminal'] ?? false;
    final List<Map<String, dynamic>> commonEvidenceList =
        List<Map<String, dynamic>>.from(problemData?['commonEvidence'] ?? []);
    final List<int> chosenEvidenceIndexes =
        List<int>.from(playerData['chosenCommonEvidence'] ?? []);
    final myCommonEvidenceList = [
      for (final i in chosenEvidenceIndexes)
        if (i >= 0 && i < commonEvidenceList.length)
          commonEvidenceList[i]
    ];

    return AlertDialog(
      backgroundColor: mmCard.withOpacity(0.98),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: mmAccent, width: 2.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.person, color: mmAccent),
          const SizedBox(width: 10),
          Text(
            'あなたのキャラクター情報',
            style: const TextStyle(
              fontFamily: mmFont,
              color: mmAccent,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 1.2,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (problemData != null) ...[
              Text(
                '事件の舞台: ${problemData!['title'] ?? ''}',
                style: const TextStyle(
                  fontFamily: mmFont,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: mmAccent,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                problemData!['story'] ?? '',
                style: const TextStyle(
                  fontFamily: mmFont,
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const Divider(
                  color: mmAccent,
                  height: 28,
                  thickness: 1.2),
            ],
            Text(
              'あなたの役職: ${playerData['role'] ?? ''}',
              style: const TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: mmAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '背景: $description',
              style: const TextStyle(
                fontFamily: mmFont,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '証拠:',
              style: TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                color: mmAccent.withOpacity(0.85),
              ),
            ),
            ...evidenceList.map<Widget>((e) =>
                Text('- $e',
                    style: const TextStyle(
                      fontFamily: mmFont,
                      color: Colors.white))),
            const SizedBox(height: 10),
            Text(
              '犯人かどうか: ${playerData['isCriminal'] ? '犯人' : '無実'}',
              style: TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                color: mmAccent.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '勝利条件:',
              style: TextStyle(
                fontFamily: mmFont,
                fontWeight: FontWeight.bold,
                color: mmAccent.withOpacity(0.85),
              ),
            ),
            ...winConditionsList.map<Widget>((e) =>
                Text('- $e',
                    style: const TextStyle(
                      fontFamily: mmFont,
                      color: Colors.white))),
            const Divider(
                color: mmAccent,
                height: 28,
                thickness: 1.2),
            if (myCommonEvidenceList.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'あなたが選んだ共通証拠',
                    style: TextStyle(
                      fontFamily: mmFont,
                      fontWeight: FontWeight.bold,
                      color: mmAccent.withOpacity(0.9),
                    ),
                  ),
                  ...myCommonEvidenceList.map<Widget>(
                    (e) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('- ${e['title']}',
                            style: const TextStyle(
                              fontFamily: mmFont,
                              color: Colors.white,
                            )),
                        if ((e['detail'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12, bottom: 4),
                            child: Text(
                              '${e['detail']}',
                              style: const TextStyle(
                                fontFamily: mmFont,
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: mmAccent,
            textStyle: const TextStyle(
              fontFamily: mmFont,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          child: const Text("閉じる"),
        )
      ],
    );
  }
}