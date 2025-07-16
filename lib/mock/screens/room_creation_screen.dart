import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/gamelobby_screen.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

// ルームの作成画面
class RoomCreationScreen extends StatefulWidget {
  final String problemTitle;
  final String problemId;
  final int requiredPlayers;

  const RoomCreationScreen({
    super.key,
    required this.problemTitle,
    required this.problemId, 
    required this.requiredPlayers,
  });

  @override
  State<RoomCreationScreen> createState() => _RoomCreationScreenState();
}

class _RoomCreationScreenState extends State<RoomCreationScreen> {
  final _roomNameController = TextEditingController();
  final _roomIdController = TextEditingController();

  Future<void> createRoom() async {
    final roomName = _roomNameController.text.trim();
    final roomId = _roomIdController.text.trim();
    print('DEBUG: Creating room with name: $roomName, ID: $roomId'); // デバッグ用ログ

    if (roomName.isEmpty || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルーム名とルームIDを入力してください')),
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

    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
    final hostName = playerDoc.exists
        ? (playerDoc.data()?['playerName'] ?? '名無しのホスト')
        : '名無しのホスト';

    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final docSnapshot = await roomDoc.get();

    if (docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('そのルームIDは既に使われています')),
      );
      return;
    }

    try {
      await roomDoc.set({
        'roomName': roomName,
        'hostUid': user.uid,
        'hostName': hostName,
        'problemTitle': widget.problemTitle,
        'problemId': widget.problemId,
        'players': [user.uid],
        'requiredPlayers': widget.requiredPlayers,
        'readyPlayers': [],
        'createdAt': Timestamp.now(),
        'discussionRound': 1, // 初期ラウンドは1
        'privateChatHistory': [], // 個別チャット履歴を空のリストで初期化
        'currentPrivateChatterUid': user.uid, // ホストが最初の個別チャット選択権を持つ
        'privateChatPhase': false, // 初期フェーズは個別チャットではない
        'phase': 'discussion', // 初期フェーズは話し合いフェーズ
        'evidenceChoosingPhase': true, // 初期は証拠選択フェーズ
        'evidenceTurn': 0, // 最初のプレイヤー（通常はホスト）から証拠選択を開始
        'discussionSecondsLeft': 5, // discussion_screen.dart の discussionTimePerRound と合わせる
        'discussionTimeUp': false,
        'discussionStarted': false,
      });

      // ホストのplayerNameをplayersコレクションにも保存する
      await FirebaseFirestore.instance.collection('players').doc(user.uid).set(
        {'playerName': hostName},
        SetOptions(merge: true), // 既存のフィールドを上書きせずにマージ
      );

      await FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('players')
      .doc(user.uid)
      .set({'playerName': hostName});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームを作成しました')),
      );

      _roomNameController.clear();
      _roomIdController.clear();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameLobbyScreen(
            roomId: roomId,
            problemTitle: widget.problemTitle,
            problemId: widget.problemId,
          ),
        ),
      );
    }on FirebaseException catch (e, stack) {
      // Firebase固有のエラーを詳細にログ出力
      print('❗ FirebaseException (createRoom): ${e.code} - ${e.message}');
      print(stack); // スタックトレースも出力して原因を特定しやすくする
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ルーム作成エラー (Firebase): ${e.message}')),
      );
      } catch (e, stack) {
        // その他のエラーを詳細にログ出力
        print('❗ General Error (createRoom): $e');
        print(stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
     }
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
        leading: const Icon(Icons.add_box, color: mmAccent),
        title: Text(
          'ルーム作成',
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
            constraints: const BoxConstraints(maxWidth: 440),
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
                    Icon(Icons.create, color: mmAccent, size: 46),
                    const SizedBox(height: 10),
                    Text(
                      '新たな事件の舞台を用意せよ',
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
                      '問題: ${widget.problemTitle}（定員: ${widget.requiredPlayers}人）',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _roomNameController,
                      style: const TextStyle(
                        fontFamily: mmFont,
                        color: Colors.white,
                        fontSize: 17,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ルーム名',
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
                        prefixIcon: const Icon(Icons.title, color: mmAccent),
                      ),
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
                        labelText: 'ルームID（英数字）',
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
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.local_police, color: Colors.white),
                        label: Text(
                          '作成する',
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
                        onPressed: createRoom,
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
}