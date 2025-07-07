import 'package:flutter/material.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // pubspec.yamlに登録想定

class PartnerSelectDialog extends StatelessWidget {
  final List<String> partners;
  final Map<String, String> partnerNames;
  final Function(String) onSelected;

  const PartnerSelectDialog({
    super.key,
    required this.partners,
    required this.partnerNames,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: mmCard.withOpacity(0.97),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: mmAccent, width: 2.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.forum, color: mmAccent),
          const SizedBox(width: 10),
          Text(
            "個別チャット相手を選択",
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: partners
            .map((uid) => Card(
                  color: mmCard,
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: mmAccent, width: 1.2),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: mmAccent),
                    title: Text(
                      partnerNames[uid] ?? uid,
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 1,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(uid);
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }
}