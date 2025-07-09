import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mock/screens/gamelobby_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

// ルームに参加
class RoomJoinScreen extends StatefulWidget {
  final String problemTitle;
  const RoomJoinScreen({Key? key, required this.problemTitle}) : super(key: key);

  @override
  _RoomJoinScreenState createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends State<RoomJoinScreen> {
  final TextEditingController _roomIdController = TextEditingController();

  void _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームIDを入力してください')),
      );
      return;
    }

    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final docSnap = await roomDoc.get();

    if (!docSnap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームが存在しません')),
      );
      return;
    }

    final roomData = docSnap.data();
    final List<dynamic> players = roomData?['players'] ?? [];
    final int requiredPlayers = roomData?['requiredPlayers'] ?? 6;
    final String? problemId = roomData?['problemId'];

    if (problemId == null || problemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このルームには問題IDがありません。')),
      );
      return;
    }

    if (players.length >= requiredPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このルームはすでに満員です')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    // ここから名無しの参加者1～のロジック
    String displayName = '';
    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
    if (playerDoc.exists &&
        playerDoc.data()?['playerName'] != null &&
        (playerDoc.data()?['playerName'] as String).trim().isNotEmpty &&
        !players.contains(playerDoc.data()?['playerName'])) {
      displayName = playerDoc.data()?['playerName'];
    } else {
      // ユーザーコレクションにもなければ名無しの参加者1から順に
      int maxNumber = 1;
      final regex = RegExp(r'名無しの参加者(\d+)$');
      for (var uid in players) {
        final subDoc = await FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .collection('players')
            .doc(uid)
            .get();
        final p = subDoc.data()?['playerName'] ?? '';
        final match = regex.firstMatch(p);
        if (match != null) {
          final num = int.tryParse(match.group(1) ?? '');
          if (num != null && num >= maxNumber) {
            maxNumber = num + 1;
          }
        }
      }
      displayName = '名無しの参加者$maxNumber';
    }

    // UIDがすでにplayersにいる場合は再参加とみなす（重複チェック不要）
    if (!players.contains(user.uid)) {
      await roomDoc.update({
        'players': FieldValue.arrayUnion([user.uid]),
      });
    }

    await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
      'playerName': displayName,
    });

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(user.uid)
        .set({'playerName': displayName});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameLobbyScreen(
          problemTitle: widget.problemTitle,
          roomId: roomId,
          problemId: problemId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        leading: const Icon(Icons.input, color: mmAccent),
        title: Text(
          'ルームに参加',
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
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Container(
                decoration: BoxDecoration(
                  color: mmCard.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: mmAccent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(2, 7),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login, color: mmAccent, size: 46),
                    const SizedBox(height: 10),
                    Text(
                      '事件の舞台へ足を踏み入れろ',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: mmAccent,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 3, offset: Offset(2, 2)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '問題: ${widget.problemTitle}',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '参加するルームIDを入力してください',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: mmAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _roomIdController,
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white,
                        fontSize: 17,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ルームID',
                        labelStyle: const TextStyle(
                          fontFamily: mmFont,
                          color: mmAccent,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: mmBackground.withOpacity(0.85),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: mmAccent, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: mmAccent, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.vpn_key, color: mmAccent),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.input, color: Colors.white),
                        label: Text(
                          '参加する',
                          style: const TextStyle(
                            fontFamily: mmFont,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                            letterSpacing: 1.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mmAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.black, width: 1),
                          ),
                          elevation: 6,
                          shadowColor: mmAccent.withOpacity(0.3),
                        ),
                        onPressed: _joinRoom,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
}