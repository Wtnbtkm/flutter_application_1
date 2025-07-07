import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // pubspec.yamlで登録想定

class ChatMessageBubble extends StatelessWidget {
  final String roomId;
  final String senderUid;
  final String text;
  final bool isMe;

  const ChatMessageBubble({
    required this.roomId,
    required this.senderUid,
    required this.text,
    required this.isMe,
    Key? key,
  }) : super(key: key);

  Future<Map<String, String>> _getSenderInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(senderUid)
        .get();
    final playerName = doc.data()?['playerName'] ?? '';
    final role = doc.data()?['role'] ?? '';
    return {'playerName': playerName, 'role': role};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getSenderInfo(),
      builder: (context, snap) {
        final senderName = snap.data?['playerName'] ?? '';
        final role = snap.data?['role'] ?? '';
        return Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                backgroundColor: mmAccent,
                child: Text(
                  role.isNotEmpty ? role[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: mmFont,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!isMe) const SizedBox(width: 6),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                decoration: BoxDecoration(
                  color: isMe
                      ? mmAccent.withOpacity(0.85)
                      : mmCard.withOpacity(0.92),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 7),
                    bottomRight: Radius.circular(isMe ? 7 : 20),
                  ),
                  border: Border.all(
                    color: isMe ? mmAccent : mmCard,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.13),
                      blurRadius: 4,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.isNotEmpty && senderName.isNotEmpty
                          ? '$role（$senderName）'
                          : (senderName.isNotEmpty ? senderName : '名無し'),
                      style: TextStyle(
                        fontFamily: mmFont,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : mmAccent,
                        fontSize: 13,
                        letterSpacing: 1,
                        shadows: isMe
                            ? [const Shadow(color: Colors.black38, blurRadius: 2)]
                            : [],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: TextStyle(
                        fontFamily: mmFont,
                        color: isMe ? Colors.white : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 6),
            if (isMe)
              CircleAvatar(
                backgroundColor: mmAccent,
                child: Text(
                  role.isNotEmpty ? role[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: mmFont,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}