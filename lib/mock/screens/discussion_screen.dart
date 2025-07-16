import 'dart:convert'; // JSONデータのエンコード・デコードに使用
import 'dart:async'; // 非同期処理（タイマーなど）に使用
import 'package:flutter/material.dart'; // FlutterのUIコンポーネントを扱うためのパッケージ
import 'package:flutter/services.dart' show rootBundle; // アセットファイル（JSONなど）の読み込みに使用
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestoreデータベースとの連携に使用
import 'package:firebase_auth/firebase_auth.dart'; // Firebase認証（ユーザーUID取得など）に使用
import'package:flutter_application_1/mock/screens/private_chat_screen.dart'; // 個別チャット画面へのパス
import 'package:flutter_application_1/mock/screens/accusation_screen.dart'; // 疑惑入力画面へのパス（SuspicionInputScreenとして使用）
import 'package:flutter_application_1/mock/screens/discussion_screen/partner_select_dialog.dart'; // 個別チャット相手選択ダイアログへのパス
import 'package:flutter_application_1/mock/screens/discussion_screen/discussion_phase.dart'; // 話し合いフェーズのUIウィジェットへのパス
import 'package:flutter_application_1/mock/screens/discussion_screen/playerInfo_dialog.dart'; // プレイヤー情報表示ダイアログへのパス
import 'package:flutter_application_1/mock/screens/discussion_screen/private_chat_phase_widget.dart'; // 個別チャットフェーズのUIウィジェットへのパス

// 話し合い画面のメインWidget
class DiscussionScreen extends StatefulWidget {
  final String roomId; // ルームID：現在のゲームセッションを識別
  final String problemId; // 問題ID：ゲームのシナリオや共通証拠を識別
  final String playerUid; // プレイヤーのUID：このウィジェットを表示しているユーザーの識別子
  // コンストラクタ
  const DiscussionScreen({
    required this.roomId,
    required this.problemId,
    required this.playerUid,
    super.key, // 親クラス（StatefulWidget）のkeyをスーパーパラメータとして渡す
  });

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

// 状態管理クラス
class _DiscussionScreenState extends State<DiscussionScreen> {
  final TextEditingController _controller = TextEditingController(); // メッセージ入力フィールドのテキストを制御
  List<Map<String, dynamic>> commonEvidence = []; // 共通証拠リスト：問題ごとに設定される証拠
  bool loading = true; // データ読み込み中かどうかを示すフラグ
  List<String> playerOrder = []; // プレイヤーのUIDが格納された順番リスト（ターン管理などに使用）
  int evidenceTurn = 0; // 証拠選択のターン：現在証拠を選べるプレイヤーのplayerOrder内のインデックス
  String? hostUid; // ホストプレイヤーのUID
  Map<String, List<int>> allChosen = {}; // 全プレイヤーの証拠選択状況（UIDをキーに、選択した証拠のインデックスリストを値とする）
  List<int> myChosen = []; // 自分が選んだ証拠のインデックスリスト
  String? playerName; // プレイヤー名
  String? role; // プレイヤーの役割（例: 犯人、探偵など）
  String? myUid; // 自分のUID（Firebase認証から取得）
  Map<String, dynamic> playersData = {}; // 全プレイヤーのデータ（UIDをキーに、プレイヤー情報を値とする）
  Map<String, dynamic>? playerData; // 自分のプレイヤーデータ
  Map<String, dynamic>? problemData; // 問題データ（JSONファイルまたはFirestoreから読み込み）
  int? _prevDiscussionRound; // 前回のディスカッションラウンド数（タイマー再起動判定などに使用）

  // --- 個別チャット用フィールド ---
  bool isPrivateChatMode = false; // 個別チャットモードが有効かどうか（現在未使用の可能性あり）
  List<String> availablePlayers = []; // 個別チャット可能な相手のUIDリスト
  String? selectedPartnerUid; // 選択中の個別チャット相手のUID
  String? selectedPartnerName; // 選択中の個別チャット相手の名前
  String? privateRoomId; // 個別チャットルームのID
  Timer? _privateChatTimer; // 個別チャットの残り時間を管理するタイマー
  int privateChatRemainingSeconds = 0; // 個別チャットの残り秒数
  bool privateChatActive = false; // 個別チャットが現在アクティブかどうか
  bool _isPrivateChatActive = false; // 個別チャット画面へ遷移中かどうかを示すフラグ
  String? _activePrivateChatId; // 現在アクティブな個別チャットのセッションID

  // --- 話し合い全体タイマー制御 ---
  int discussionSecondsLeft = 10; // 話し合いフェーズの残り秒数
  Timer? _discussionTimer; // 話し合いフェーズのタイマー
  bool discussionTimeUp = false; // 話し合い時間が終了したかどうか
  bool discussionStarted = false; // 話し合いが開始されたかどうか

  // 個別チャット制御用
  bool privateChatPhase = false; // 現在が個別チャットフェーズかどうか
  String? currentPrivateChatterUid; // 現在個別チャットの選択権を持つプレイヤーのUID
  List<Map<String, dynamic>> privateChatHistory = []; // 個別チャットの履歴（どのペアがどのラウンドでチャットしたか）

  // --- ラウンド管理用追加 ---
  int discussionRound = 1; // 現在の話し合いラウンド数
  String phase = 'discussion'; // 現在のゲームフェーズ（'discussion', 'privateChat', 'suspicion', 'end'など）
  static const int maxRounds = 2; // 最大ラウンド数
  static const int discussionTimePerRound = 10; // 各話し合いラウンドの秒数
  String? _lastOpenedSessionId; // 最後に開いた個別チャットセッションのID（重複起動防止用）
  bool _onPrivateChatEndCalled = false; // _onPrivateChatEndが呼び出されたかどうかを示すフラグ（二重実行防止用）
  
 @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _listenMyChosen();
    _loadInitData();
    _startPrivateChatListener();
    _listenActivePrivateChat();
  }

  @override
  void dispose() {
    debugPrint('🔴 dispose called'); // デバッグログ：disposeが呼ばれたことを示す
    debugPrint('disposing discussionRound: $discussionRound'); // dispose時点のラウンド数をログ出力
    _discussionTimer?.cancel(); // 話し合いタイマーをキャンセル
    _privateChatTimer?.cancel(); // 個別チャットタイマーをキャンセル
    _controller.dispose(); // テキストコントローラーを破棄
    super.dispose();
  }

  // 自分が選んだ共通証拠の変更をFirestoreからリアルタイムで監視する
  void _listenMyChosen() {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data != null) {
        setState(() {
          myChosen = List<int>.from(data['chosenCommonEvidence'] ?? []); // 選択された証拠リストを更新
        });
      }
    });
  }

  /// 証拠を選ぶ処理：プレイヤーが共通証拠を選択し、Firestoreに保存する
  Future<void> chooseEvidence(int idx) async {
    final ref = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid);
    final snap = await ref.get();
    List<int> chosen = List<int>.from(snap.data()?['chosenCommonEvidence'] ?? []); // 現在選択している証拠を取得
    if (chosen.length >= 2) return; // 既に2つ選んでいたら何もしない
    if (chosen.contains(idx)) return; // 既にその証拠を選んでいたら何もしない
    chosen.add(idx); // 新しい証拠を追加
    await ref.set({'chosenCommonEvidence': chosen}, SetOptions(merge: true)); // Firestoreに更新

    // 全員の証拠選択状況を取得
    final playersSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .get();
    Map<String, List<int>> allChosenTemp = {};
    for (final doc in playersSnap.docs) {
      allChosenTemp[doc.id] =
          List<int>.from(doc.data()['chosenCommonEvidence'] ?? []);
    }
    bool allDone = allChosenTemp.values.every((list) => list.length >= 2); // 全員が2つ証拠を選び終えたかチェック

    if (allDone) {
      // 全員選び終わったら証拠選択フェーズを終了
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'evidenceChoosingPhase': false});
    } else {
      // 全員選び終わっていない場合、次のターンの人を決める
      int nextTurn = evidenceTurn;
      for (int i = 1; i <= playerOrder.length; i++) {
        int idx2 = (evidenceTurn + i) % playerOrder.length; // 順番に次のプレイヤーをチェック
        if ((allChosenTemp[playerOrder[idx2]] ?? []).length < 2) {
          nextTurn = idx2; // まだ2つ選んでいないプレイヤーがいれば、その人を次のターンとする
          break;
        }
      }
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'evidenceTurn': nextTurn}); // Firestoreのターン情報を更新
    }
  }

  /// Firestoreまたはアセットから初期データを読み込む
  Future<void> _loadInitData() async {
    DocumentSnapshot<Map<String, dynamic>>? problemSnap;
    try {
      // まずFirestoreから問題データを取得を試みる
      problemSnap = await FirebaseFirestore.instance
          .collection('problems')
          .doc(widget.problemId)
          .get();
    } catch (e) {
      problemSnap = null; // エラーが発生した場合はnullとする
    }
    Map<String, dynamic> _problemData;
    if (problemSnap != null && problemSnap.exists) {
      // Firestoreにデータがあればそれを使用
      _problemData = problemSnap.data() ?? {};
    } else {
      // Firestoreになければアセット（JSONファイル）から読み込む
      final jsonString = await rootBundle
          .loadString('assets/problems/${widget.problemId}.json');
      _problemData = json.decode(jsonString);
    }
    problemData = _problemData; // 読み込んだ問題データを格納

    // 共通証拠データの整形：問題データから共通証拠リストを抽出し、適切な形式に変換
    commonEvidence = [];
    if (problemData!['commonEvidence'] != null) {
      if (problemData!['commonEvidence'] is List) {
        for (final e in problemData!['commonEvidence']) {
          if (e is String) {
            commonEvidence.add({'title': e, 'detail': ''}); // 文字列の場合はタイトルとして追加
          } else if (e is Map<String, dynamic>) {
            commonEvidence.add(e); // Map形式の場合はそのまま追加
          }
        }
      }
    }
    // ルーム情報取得
    final roomSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();
    final roomData = roomSnap.data() ?? {};
    hostUid = roomData['hostUid']; // ホストUIDを設定
    playerOrder = List<String>.from(roomData['players'] ?? []); // プレイヤー順序を設定
    evidenceTurn = roomData['evidenceTurn'] ?? 0; // 証拠選択ターンを設定
    privateChatPhase = roomData['privateChatPhase'] ?? false; // 個別チャットフェーズかどうかを設定
    currentPrivateChatterUid = roomData['currentPrivateChatterUid']; // 現在の個別チャット選択権者を設定
    privateChatHistory = (roomData['privateChatHistory'] ?? [])
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList(); // 個別チャット履歴を設定
    // ラウンド・フェーズ情報取得
    setState(() {
      discussionRound = roomData['discussionRound'] ?? 1; // ディスカッションラウンドを設
    });
    phase = roomData['phase'] ?? 'discussion'; // 現在のフェーズを設定
    // プレイヤー自身の情報取得
    final mySnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .get();
    playerData = mySnap.data() ?? {}; // 自分のプレイヤーデータを格納
    playerName = playerData!['playerName'] ?? ''; // プレイヤー名を設定
    role = playerData!['role'] ?? ''; // 役割を設定
    availablePlayers = playerOrder.where((uid) => uid != widget.playerUid).toList(); // 個別チャット可能な相手リストを作成（自分以外）
    await _loadPlayersData(); // 全プレイヤーのデータを読み込む
    setState(() {
      loading = false; // ローディング完了
    });
  }

  /// 現在個別チャット中のプレイヤーのUIDリストをFirestoreから取得する
  Future<List<String>> fetchCurrentlyChattingPlayers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .where('active', isEqualTo: true) // activeがtrueのチャットセッションを検索
        .get();

    Set<String> activeUids = {}; // アクティブなチャットに参加しているUIDを格納するセット
    for (final doc in snapshot.docs) {
      final List participants = doc.data()['participants'] ?? []; // 参加者リストを取得
      activeUids.addAll(participants.cast<String>()); // セットに追加
    }

    return activeUids.toList(); // リストとして返す
  }

  // 全プレイヤーのデータをFirestoreから読み込み、`playersData`に格納する
  Future<void> _loadPlayersData() async {
    final playersSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .get();

    Map<String, dynamic> allPlayersData = {};
    for (final doc in playersSnap.docs) {
      allPlayersData[doc.id] = doc.data(); // 各プレイヤーのUIDをキーとしてデータを格納
    }

    setState(() {
      playersData = allPlayersData; // 状態を更新
    });
  }

  /// 話し合いタイマーを開始する
  void _startDiscussionTimer() {
    _discussionTimer?.cancel(); // 既存のタイマーがあればキャンセル
    setState(() {
      discussionSecondsLeft = discussionTimePerRound; // 残り秒数を初期設定
      discussionTimeUp = false; // 時間切れフラグをリセット
    });
    _discussionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (discussionSecondsLeft > 0) {
        setState(() {
          discussionSecondsLeft--; // 1秒ごとに残り秒数を減らす
        });
      } else {
        _discussionTimer?.cancel(); // タイマーをキャンセル
        setState(() {
          discussionTimeUp = true; // 時間切れフラグを立てる
        });
        // 話し合い終了時に個別チャットフェーズを開始
        await _goToPrivateChatPhase();
      }
    });
  }

  /// 個別チャットフェーズへ遷移するためのFirestore更新処理
  Future<void> _goToPrivateChatPhase() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({
      'phase': 'privateChat', // フェーズを'privateChat'に設定
      'privateChatPhase': true, // 個別チャットフェーズフラグをtrueに
      // ホストから選択権を開始
      'currentPrivateChatterUid': hostUid, // ホストに個別チャット選択権を渡す
      'privateChatHistory': [], // 個別チャット履歴をリセット（新しいラウンドのため）
    });
  }

  /// アクティブな個別チャットセッションを監視し、必要に応じて画面遷移に利用する
  void _listenActivePrivateChat() {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .snapshots()
        .listen((snapshot) {
      String? activeId;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List participants = data['participants'] ?? [];
        final bool isActive = data['active'] ?? true;
        // 現在のプレイヤーが参加しており、かつアクティブなチャットセッションがあればそのIDを保持
        if (isActive && participants.contains(widget.playerUid)) {
          activeId = doc.id;
          break;
        }
      }
      setState(() {
        _activePrivateChatId = activeId; // アクティブなチャットIDを更新
      });
    });
  }

  /// 個別チャットの状態を監視し、アクティブになった際にチャット画面へ遷移させる
  void _startPrivateChatListener() {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List participants = data['participants'] ?? [];
        final bool isActive = data['active'] ?? true;

        // ✅ すでに開いているセッションは除外（同じsessionIdなら再起動しない）
        final String sessionId = doc.id;

        // チャットがアクティブで、自分が参加しており、個別チャット画面に遷移中でなく、かつ、
        // 最後に開いたセッションIDと異なる場合に画面遷移を実行
        if (isActive &&
            participants.contains(widget.playerUid) &&
            !_isPrivateChatActive &&
            sessionId != _lastOpenedSessionId) {
          _isPrivateChatActive = true; // 遷移中フラグを立てる
          _lastOpenedSessionId = sessionId; // 🔑 現在のセッションIDを記録

          // PrivateChatScreenへ遷移
          Navigator.of(context)
              .push(MaterialPageRoute(
            builder: (context) => PrivateChatScreen(
              roomId: widget.roomId,
              sessionId: sessionId,
              timeLimitSeconds: PrivateChatScreen.defaultTimeLimitSeconds,
              round: discussionRound,
            ),
          ))
              .then((_) async {
            // PrivateChatScreenから戻ってきた際の処理
            _isPrivateChatActive = false; // 遷移中フラグをリセット
            await _onPrivateChatEnd(); // 個別チャット終了後の処理を実行
          });

          break; // 複数のアクティブなチャットがあっても1つだけ処理
        }
      }
    });
  }


  Future<void> _startNewPrivateChatRound(int nextRound) async {
    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
 
    // 1. privateChatsコレクションを全削除（またはラウンド番号でフィルタして削除）
    final privateChats = await roomDoc.collection('privateChats').get();
    for (var doc in privateChats.docs) {
      await doc.reference.delete();
    }
    // 2. 履歴・選択権・フェーズ・ラウンド番号を初期化
    await roomDoc.update({
      'privateChatHistory': [],
      'currentPrivateChatterUid': hostUid, // 必ずhostUidまたは先頭
      'privateChatPhase': true,
      'phase': 'privateChat',
      'discussionRound': nextRound,
    });
  }

  /// (B) 個別チャットペア作成時のID・判定厳密化
  Future<void> _startPrivateChatWith(String partnerUid) async {
      final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomDoc);
      final allPlayers = List<String>.from(roomSnap.data()?['players'] ?? []);
      final roomData = roomSnap.data() ?? {};
      final discussionRound = roomData['discussionRound'] ?? this.discussionRound;
      final privateChatHistory = (roomData['privateChatHistory'] ?? []).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
 
      // (1) 同一ラウンド・同一ペアのチャットが既に存在するか厳密判定
      final alreadyExists = privateChatHistory.any((pair) =>
        ((pair['a'] == widget.playerUid && pair['b'] == partnerUid) ||
         (pair['a'] == partnerUid && pair['b'] == widget.playerUid)) &&
        pair['round'] == discussionRound
      );
      if (alreadyExists) return;
 
      final participantsSorted = [widget.playerUid, partnerUid]..sort();
      final chosenPair = {
        'a': participantsSorted[0],
        'b': participantsSorted[1],
        'round': discussionRound,
      };
      privateChatHistory.add(chosenPair);
 
      // (2) ラウンド番号込みのチャットセッションID
      final chosenId = 'private_${participantsSorted[0]}_${participantsSorted[1]}_${widget.roomId}_$discussionRound';
      final privateChatRef = roomDoc.collection('privateChats').doc(chosenId);
      transaction.set(privateChatRef, {
        'participants': [chosenPair['a'], chosenPair['b']],
        'startTimestamp': FieldValue.serverTimestamp(),
        'durationSeconds': 90,
        'active': true,
        'round': discussionRound,
      });
 
      // (3) 全ペア数
      final n = allPlayers.length;
      final totalPairs = (n * (n - 1)) ~/ 2;
      final roundHistory = privateChatHistory.where((pair) => pair['round'] == discussionRound).toList();
 
      // (4) 全ペア終了時はcurrentPrivateChatterUid: null
      String? nextChatterUid;
      if (roundHistory.length >= totalPairs) {
        nextChatterUid = null;
      } else {
        // 未消化ペアがある人をリストアップし、順送り
        for (int offset = 1; offset <= allPlayers.length; offset++) {
          final idx = (allPlayers.indexOf(widget.playerUid) + offset) % allPlayers.length;
          final candidate = allPlayers[idx];
          final available = getAvailableChatPartnersFor(candidate, privateChatHistory, allPlayers, discussionRound);
          if (available.isNotEmpty) {
            nextChatterUid = candidate;
            break;
          }
        }
      }
      transaction.update(roomDoc, {
        'privateChatHistory': privateChatHistory,
      });
    });
  }
  // (E) 次の選択権者を厳密に決定
  Future<String?> getNextChatterUid(
    List<String> playerOrder,
    List<Map<String, dynamic>> privateChatHistory,
    int discussionRound,
    String? currentUid,
) async {
    if (playerOrder.isEmpty) return null;
    int startIdx = currentUid != null ? playerOrder.indexOf(currentUid) : 0;
    if (startIdx == -1) startIdx = 0;

    // 最大人数分ループして、未消化ペアがいる人を見つける
    for (int offset = 1; offset <= playerOrder.length; offset++) {
        final idx = (startIdx + offset) % playerOrder.length;
        final candidate = playerOrder[idx];
        final available = getAvailableChatPartnersFor(
          candidate,
          privateChatHistory,
          playerOrder,
          discussionRound,
        );
        if (available.isNotEmpty) {
            return candidate;
        }
    }
    return null;
}
 
  //(C) 個別チャット履歴から未消化ペアを正確に判定
  List<String> getAvailableChatPartnersFor(
    String uid,
    List<Map<String, dynamic>> history,
    List<String> allPlayers,
    int round,
    {List<String> currentlyChattingPlayers = const []}
  ) {
    Set<String> spokenWith = {};
    for (final pair in history) {
      if (pair['round'] != round) continue;
      final a = pair['a'], b = pair['b'];
      if (a == uid) spokenWith.add(b);
      if (b == uid) spokenWith.add(a);
    }
    return allPlayers
        .where((other) => other != uid && !spokenWith.contains(other) && !currentlyChattingPlayers.contains(other))
        .toList();
  }
  /// 個別チャットが終了した際の処理（全員のチャット終了チェック＆次ラウンド進行）
  /// (D) ラウンド終了判定・次ラウンド開始
  Future<void> _onPrivateChatEnd() async {
    if (_onPrivateChatEndCalled) return;
    _onPrivateChatEndCalled = true;
    try {
      if (myUid != hostUid) return;
      final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final roomSnap = await transaction.get(roomDoc);
        final roomData = roomSnap.data() ?? {};
        final allPlayers = List<String>.from(roomData['players'] ?? []);
        final currentRound = roomData['discussionRound'] ?? discussionRound;
        final privateChatHistory = (roomData['privateChatHistory'] ?? []).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        final n = allPlayers.length;
        final totalPairs = (n * (n - 1)) ~/ 2;
        final roundHistory = privateChatHistory.where((pair) => pair['round'] == currentRound).toList();
        final privateChatsSnap = await roomDoc.collection('privateChats').get();
        final anyActiveChats = privateChatsSnap.docs.any((doc) => (doc.data()['active'] ?? false));
        if (anyActiveChats) return;
        // 全ペア消化済みならフェーズ終了
        if (roundHistory.length >= totalPairs) {
          transaction.update(roomDoc, {          
            'currentPrivateChatterUid': null,
            'privateChatPhase': false,
          });
        } else {
          // 今のcurrentPrivateChatterUidに選べる相手がいなければ即座に次の人へ
          String? nextChatter = await getNextChatterUid(
            allPlayers, privateChatHistory, currentRound, roomData['currentPrivateChatterUid']);
          if (nextChatter != null) {
            transaction.update(roomDoc, {
              'currentPrivateChatterUid': nextChatter,
              'privateChatPhase': true,
            });
          } else {
            transaction.update(roomDoc, {
              'currentPrivateChatterUid': null,
              'privateChatPhase': false,
            });
          }
        }
      });
    } finally {
      _onPrivateChatEndCalled = false;
    }
  }
 
  /// チャットメッセージを送信する
  Future<void> _sendMessage() async {
    final message = _controller.text.trim(); // 入力されたメッセージを取得し、空白をトリム
    if (message.isEmpty || !discussionStarted || discussionTimeUp) return; // メッセージが空、話し合いが開始されていない、または時間切れの場合は送信しない
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'uid': widget.playerUid, // 送信者のUID
      'text': message, // メッセージ本文
      'timestamp': FieldValue.serverTimestamp(), // Firestoreのサーバータイムスタンプ
    });
    _controller.clear(); // 入力フィールドをクリア
  }

  /// 現在のプレイヤーが個別チャット可能な相手のリストを取得する
  List<String> getAvailableChatPartners() {
    final available = getAvailableChatPartnersFor(
        widget.playerUid,
        privateChatHistory,
        playerOrder,
        discussionRound
    ); // ヘルパー関数を呼び出して利用可能な相手を取得
    return available;
  }

  /// 個別チャットの相手を選択できる状態かどうかを判定するゲッター
  bool get canChoosePrivateChatPartner => privateChatPhase && // 個別チャットフェーズである
      currentPrivateChatterUid == widget.playerUid && // 自分が現在の選択権者である
      (currentPrivateChatterUid?.isNotEmpty ?? false) && // 選択権者UIDが空でない
      getAvailableChatPartners().isNotEmpty && // 個別チャット可能な相手がいる
      !_isPrivateChatActive; // 個別チャット画面に遷移中でない

  /// 相手選択ダイアログを表示する
  void _showPartnerSelectDialog() async {
    final partners = getAvailableChatPartners(); // 個別チャット可能な相手リストを取得
    if (partners.isEmpty) {
      // 選択可能なパートナーがいない場合はダイアログを表示しない
      return;
    }
    final partnerNames = <String, String>{}; // パートナーのUIDと名前のマップ
    for (final uid in partners) {
      // 各パートナーのプレイヤー名を取得
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(uid)
          .get();
      partnerNames[uid] = snap.data()?['playerName'] ?? uid; // 名前がなければUIDを使用
    }
    showDialog(
      context: context,
      builder: (ctx) => PartnerSelectDialog(
        partners: partners, // 選択可能なパートナーUIDリスト
        partnerNames: partnerNames, // パートナー名マップ
        onSelected: (uid) async {
          await _startPrivateChatWith(uid); // 選択された相手と個別チャットを開始
        },
      ),
    );
  }
  /// 画面描画（UIの構築）
  @override
  Widget build(BuildContext context) {
    if (loading) {
      // ローディング中はプログレスインジケータを表示
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Firestoreの部屋情報をリアルタイムで監視し、UIを更新
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData) {
          // データ未取得の場合はローディング表示
          return const Scaffold(
            backgroundColor: Color(0xFF23232A),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = roomSnap.data!.data() as Map<String, dynamic>; // 部屋の最新データを取得
        evidenceTurn = data['evidenceTurn'] ?? 0; // 証拠選択ターンを更新
        bool evidenceChoosingPhase = data['evidenceChoosingPhase'] ?? true; // 証拠選択フェーズかどうかを更新
        playerOrder = List<String>.from(data['players'] ?? playerOrder); // プレイヤー順序を更新

        privateChatPhase = data['privateChatPhase'] ?? false; // 個別チャットフェーズかどうかを更新
        currentPrivateChatterUid = data['currentPrivateChatterUid']; // 現在の個別チャット選択権者を更新
        privateChatHistory = (data['privateChatHistory'] ?? [])
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList(); // 個別チャット履歴を更新

        // ラウンド・フェーズ監視
        // Firestoreから取得したラウンド情報
        final int fetchedDiscussionRound = data['discussionRound'] ?? 1;
        // Stateの変数を更新（discussionRoundに変更がある場合のみ）
        if (fetchedDiscussionRound != discussionRound) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                discussionRound = fetchedDiscussionRound; // ラウンド数を更新
                debugPrint('🔄 discussionRound updated from StreamBuilder: $discussionRound'); // デバッグログ
              });
            }
          });
        }
        phase = data['phase'] ?? 'discussion'; // 現在のフェーズを更新

        // 話し合いタイマーの開始判定
        // フェーズが'discussion'で、証拠選択フェーズが終了しており、
        // かつ、ラウンドが更新されたか、話し合いがまだ開始されていない場合にタイマーを開始
        if (phase == 'discussion' && !evidenceChoosingPhase &&
            (_prevDiscussionRound != discussionRound || !discussionStarted)) { // discussionStarted も条件に追加
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startDiscussionTimer(); // 話し合いタイマーを開始
            setState(() {
              discussionStarted = true; // 話し合い開始フラグを立てる
              discussionTimeUp = false; // 時間切れフラグをリセット
              _prevDiscussionRound = discussionRound; // 前回のラウンド数を更新
            });
          });
        }

        // ラウンド・フェーズによる画面分岐
        if (phase == 'discussion') {
          // 話し合いフェーズのUIを表示
          return DiscussionPhaseWidget(
            roomId: widget.roomId,
            playerUid: widget.playerUid,
            evidenceChoosingPhase: evidenceChoosingPhase,
            evidenceTurn: evidenceTurn,
            playerOrder: playerOrder,
            commonEvidence: commonEvidence,
            myChosen: myChosen,
            canChoosePrivateChatPartner: canChoosePrivateChatPartner,
            onShowPartnerSelectDialog: _showPartnerSelectDialog,
            onSendMessage: _sendMessage,
            controller: _controller,
            discussionStarted: discussionStarted,
            discussionTimeUp: discussionTimeUp,
            discussionSecondsLeft: discussionSecondsLeft,
            discussionRound: discussionRound,
            privateChatPhase: privateChatPhase,
            currentPrivateChatterUid: currentPrivateChatterUid,
            problemData: problemData,
            onChooseEvidence: chooseEvidence,
            onShowPlayerInfo: _showPlayerInfoDialog,
          );
          
        } else if (phase == 'privateChat') {
          // 個別チャットフェーズのUIを表示
          // ホストの場合のみ、全チャット終了判定ロジックを実行するトリガーを設置
          // (PrivateChatPhaseWidget内でonPrivateChatEndが呼ばれることを期待)
          return PrivateChatPhaseWidget(
            problemId: widget.problemId,
            roomId: widget.roomId,
            discussionRound: discussionRound,
            privateChatPhase: privateChatPhase,
            canChoosePrivateChatPartner: canChoosePrivateChatPartner,
            onShowPartnerSelectDialog: _showPartnerSelectDialog,
            playersData: playersData,
            problemData: problemData,
            commonEvidence: commonEvidence,
            onPrivateChatEnd: (myUid == hostUid) ? _onPrivateChatEnd : null, // ホストのみ終了判定をトリガー
          );
        } else if (phase == 'suspicion') {
          // 疑惑入力フェーズのUIを表示
          return SuspicionInputScreen(
            roomId: widget.roomId,
            players: playerOrder, // プレイヤーリスト
            timeLimitSeconds: 60, // 制限時間
            targetPlayer: widget.playerUid, // 弁論対象（現在のプレイヤー）
          );
        } else if (phase == 'end') {
          // 終了画面を表示
          return Scaffold(
            backgroundColor: const Color(0xFF23232A),
            body: const Center(
              child: Text(
                "全ラウンド終了しました。お疲れさまでした！",
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        } else {
          // その他（未定義）フェーズの場合
          return Scaffold(
            backgroundColor: const Color(0xFF23232A),
            body: const Center(
              child: Text("次のフェーズ待ち...", style: TextStyle(color: Colors.amber)),
            ),
          );
        }
      },
    );
  }

  /// プレイヤー情報ダイアログを表示する
  void _showPlayerInfoDialog() async {
    // 最新の自分のプレイヤー情報をFirestoreから取得
    final mySnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .get();
    final latestPlayerData = mySnap.data() ?? {}; // 取得したデータを格納

    showDialog(
      context: context,
      builder: (context) => PlayerInfoDialog(
        playerData: latestPlayerData, // プレイヤーデータ
        problemData: problemData, // 問題データ
      ),
    );
  }
}