import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/story_intro_screen.dart';
// マーダーミステリーのゲームの待機ロビー画面
class GameLobbyScreen extends StatefulWidget {
  // ルームID、問題タイトル、問題IDを受け取るコンストラクタ
  final String roomId;
  final String problemTitle;
  final String problemId;

  const GameLobbyScreen({
    super.key,
    required this.roomId,
    required this.problemTitle,
    required this.problemId,
  });

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  // 一度だけ画面遷移を行うためのフラグ
  bool navigatedToStoryIntro = false;
  // 現在ログイン中のユーザーIDを保持
  String? currentUid;

  @override
  void initState() {
    super.initState();
    // FirebaseAuthから現在ログイン中ユーザーのUIDを取得
    currentUid = FirebaseAuth.instance.currentUser?.uid;
  }

  // Firestoreから指定したuidのプレイヤー名を取得する非同期関数
  Future<String> _getPlayerName(String uid) async {
    // まずルーム内のplayersコレクションから取得
    final sub = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(uid)
        .get();
    if (sub.exists && sub.data()?['playerName'] != null) {
      return sub.data()!['playerName'];
    }
    // ルーム内に名前がなければ、グローバルなplayersコレクションから取得
    final doc = await FirebaseFirestore.instance.collection('players').doc(uid).get();
    if (doc.exists && doc.data()?['playerName'] != null) {
      return doc.data()!['playerName'];
    }
    // 名前がなければ「名無しの参加者」を返す
    return '名無しの参加者';
  }

  // 自分の準備状態（readyPlayers配列の中に自分がいるか）をトグル（切り替え）する処理
  Future<void> _toggleReady(List readyPlayers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // 未ログイン時は処理しない
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final isReady = readyPlayers.contains(user.uid);
    if (isReady) {
      // すでに準備済みなら、配列から自分のUIDを削除
      await roomRef.update({'readyPlayers': FieldValue.arrayRemove([user.uid])});
    } else {
      // 未準備なら、配列に自分のUIDを追加
      await roomRef.update({'readyPlayers': FieldValue.arrayUnion([user.uid])});
    }
  }

  /*ホストがゲームを開始するときにFirestoreのgameStartedフラグをtrueにして、
  ストーリー紹介画面に遷移させる処理*/
  Future<void> _startGame(Map<String, dynamic> data) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    await roomRef.update({'gameStarted': true});
    _navigateToStoryIntro();
  }

  // ゲーム開始後、StoryIntroScreenへ画面遷移する処理
  void _navigateToStoryIntro() {
    // 二重遷移防止のためのガード
    if (navigatedToStoryIntro) return;
    navigatedToStoryIntro = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StoryIntroScreen(problemId: widget.problemId),
        // ルームIDを引数として渡す
        settings: RouteSettings(arguments: widget.roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // マーダーミステリーの世界観に合う配色とフォント設定
    const Color backgroundColor = Color(0xFF1C1B2F);
    const Color cardColor = Color(0xFF292845);
    const Color accentColor = Color(0xFFE84A5F);
    const String fontFamily = 'MurderMysteryFont'; // pubspec.yamlで登録済みのフォント
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 6,
        shadowColor: accentColor.withOpacity(0.5),
        title: Row(
          children: [
            Icon(Icons.local_police, color: accentColor),
            const SizedBox(width: 8),
            Text(
              '待機ロビー',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: accentColor, blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      // Firestoreのroomsコレクションの対象ルームのドキュメントを監視し、リアルタイム更新
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // ルーム情報をMapとして取得
          final data = snapshot.data!.data() as Map<String, dynamic>;

          // 参加者UIDリスト
          final players = List<String>.from(data['players'] ?? []);
          // 準備完了している参加者UIDリスト
          final readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
          // 必要な参加人数（デフォルト6人）
          final requiredPlayers = data['requiredPlayers'] ?? 6;
          // ホストかどうか判定
          final isHost = data['hostUid'] == FirebaseAuth.instance.currentUser?.uid;
          // 全員参加かつ全員準備完了かどうか
          final allReady = players.length == requiredPlayers && readyPlayers.length == requiredPlayers;
          // 自分が準備済みかどうか
          final myReady = currentUid != null && readyPlayers.contains(currentUid);

          // 自分のUIDが参加者リストにいなければ再参加促すメッセージ表示
          if (currentUid != null && !players.contains(currentUid)) {
            return Center(
              child: Text(
                'あなたのアカウントがルームに存在しません。再参加してください。',
                style: TextStyle(color: accentColor, fontFamily: fontFamily),
              ),
            );
          }

          // ゲーム開始フラグがtrueなら画面遷移を行う（microtaskで遅延実行）
          if (data['gameStarted'] == true) {
            Future.microtask(() => _navigateToStoryIntro());
          }

          // 画面本体（プレイヤーリスト表示、準備ボタン、ゲーム開始ボタンなど）
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '事件ファイル: ${widget.problemTitle}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '必要な人数: $requiredPlayers 人',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    '現在の参加者: ${players.length} / $requiredPlayers',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 16,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // 参加者UIDリストから名前を取得し、名前付きリストを作成して表示
                  child: FutureBuilder<List<Map<String, String>>>(
                    future: Future.wait(players.map((uid) async {
                      final name = await _getPlayerName(uid);
                      return {'uid': uid, 'name': name};
                    }).toList()),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final playerInfo = snap.data!;
                      return ListView.separated(
                        itemCount: playerInfo.length,
                        separatorBuilder: (_, __) => SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final p = playerInfo[index]['uid']!;
                          final name = playerInfo[index]['name']!;
                          final isMe = (p == currentUid);
                          return Container(
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                // 準備済みなら緑の枠、そうでなければアクセントカラー薄め
                                color: readyPlayers.contains(p)
                                    ? Colors.greenAccent
                                    : accentColor.withOpacity(0.35),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(1, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Icon(
                                // 準備状態でアイコン切替
                                readyPlayers.contains(p)
                                    ? Icons.check_circle
                                    : Icons.hourglass_empty,
                                color: readyPlayers.contains(p)
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                size: 28,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                  color: isMe ? accentColor : Colors.white,
                                  fontSize: 17,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              subtitle: isMe
                                  ? Text(
                                      'あなた',
                                      style: TextStyle(
                                        fontFamily: fontFamily,
                                        color: accentColor,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 準備完了・解除ボタン
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleReady(readyPlayers),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myReady ? Colors.grey[800] : accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(
                            fontFamily: fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          elevation: 4,
                        ),
                        icon: Icon(myReady ? Icons.close : Icons.check),
                        label: Text(myReady ? '準備を解除' : '準備完了'),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // ホストのみ表示されるゲーム開始ボタン
                    if (isHost)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: allReady ? () => _startGame(data) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allReady ? accentColor : Colors.grey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: TextStyle(
                              fontFamily: fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.black, width: 1),
                            ),
                            elevation: 4,
                          ),
                          icon: Icon(Icons.play_arrow),
                          label: const Text('ゲーム開始'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    '事件の幕は、すぐに上がる…',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontStyle: FontStyle.italic,
                      color: Colors.white38,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}