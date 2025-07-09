// 必要なパッケージのインポート
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 画面やウィジェットのインポート
import 'package:flutter_application_1/mock/screens/private_chat_screen.dart';
import 'package:flutter_application_1/mock/screens/accusation_screen.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen/partner_select_dialog.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen/discussion_phase.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen/playerInfo_dialog.dart';
import 'package:flutter_application_1/mock/screens/discussion_screen/private_chat_phase_widget.dart';

// 話し合い画面のメインWidget
class DiscussionScreen extends StatefulWidget {
  final String roomId; // ルームID
  final String problemId; // 問題ID
  final String playerUid; // プレイヤーのUID
  const DiscussionScreen({
    Key? key,
    required this.roomId,
    required this.problemId,
    required this.playerUid,
  }) : super(key: key);

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

// 状態管理クラス
class _DiscussionScreenState extends State<DiscussionScreen> {
  final TextEditingController _controller = TextEditingController(); // メッセージ入力用コントローラー
  List<Map<String, dynamic>> commonEvidence = []; // 共通証拠リスト
  bool loading = true; // ローディング中か
  List<String> playerOrder = []; // プレイヤーの順番
  int evidenceTurn = 0; // 証拠選択のターン
  String? hostUid; // ホストのuid
  Map<String, List<int>> allChosen = {}; // 全員の証拠選択状況
  List<int> myChosen = []; // 自分が選んだ証拠
  String? playerName; // プレイヤー名
  String? role; // 役割
  String? myUid; // 自分のuid
  Map<String, dynamic>? playerData; // 自分のデータ
  Map<String, dynamic>? problemData; // 問題データ
  int? _prevDiscussionRound; // 前回のディスカッションラウンド

  // --- 個別チャット用フィールド ---
  bool isPrivateChatMode = false; // 個別チャットモードか
  List<String> availablePlayers = []; // 個別チャット可能な相手
  String? selectedPartnerUid; // 選択中の相手uid
  String? selectedPartnerName; // 選択中の相手名
  String? privateRoomId; // 個別チャットルームID
  Timer? _privateChatTimer; // 個別チャットタイマー
  int privateChatRemainingSeconds = 0; // 個別チャット残り秒数
  bool privateChatActive = false; // 個別チャットがアクティブか
  bool _isPrivateChatActive = false; // 個別チャット画面遷移中か
  String? _activePrivateChatId; // アクティブな個別チャットID

  // --- 話し合い全体タイマー制御 ---
  int discussionSecondsLeft = 10; // 話し合い残り秒数
  Timer? _discussionTimer; // 話し合いタイマー
  bool discussionTimeUp = false; // 話し合い時間切れか
  bool discussionStarted = false; // 話し合いが始まったか

  // 個別チャット制御用
  bool privateChatPhase = false; // 個別チャットフェーズか
  String? currentPrivateChatterUid; // 現在選択権のあるuid
  List<Map<String, dynamic>> privateChatHistory = []; // 個別チャット履歴

  // --- ラウンド管理用追加 ---
  int discussionRound = 1; // 話し合いラウンド
  String phase = 'discussion'; // 現在のフェーズ
  static const int maxRounds = 2; // 最大ラウンド数
  static const int discussionTimePerRound = 10; // 各ラウンドのディスカッション秒数

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid; // ログインユーザーのuid取得
    _loadInitData(); // 初期データ読み込み
    _startPrivateChatListener(); // 個別チャット監視開始
    _listenActivePrivateChat(); // アクティブ個別チャット監視
  }

  /// 指定uidがまだ話していない相手を返す（ラウンド指定）
  List<String> getAvailableChatPartnersFor(
    String uid,
    List<Map<String, dynamic>> history,
    List<String> allPlayers,
    int round,
  ) {
    Set<String> spokenWith = {};
    for (final pair in history) {
      if (pair['round'] != round) continue;
      // 対称性を考慮: (a, b) も (b, a) も同じペアとして扱う
      if ((pair['a'] == uid || pair['b'] == uid) && (pair['a'] == uid ? pair['b'] : pair['a']) != null) {
        spokenWith.add(pair['a'] == uid ? pair['b'] : pair['a']);
      }
    }
    return allPlayers.where((other) => other != uid && !spokenWith.contains(other)).toList();
  }

  /// 証拠を選ぶ処理
  Future<void> chooseEvidence(int idx) async {
    final ref = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid);
    final snap = await ref.get();
    List<int> chosen = List<int>.from(snap.data()?['chosenCommonEvidence'] ?? []);
    if (chosen.length >= 2) return;
    if (chosen.contains(idx)) return;
    chosen.add(idx);
    await ref.set({'chosenCommonEvidence': chosen}, SetOptions(merge: true));

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
    bool allDone = allChosenTemp.values.every((list) => list.length >= 2);

    if (allDone) {
      // 全員選び終わったらフェーズ終了
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'evidenceChoosingPhase': false});
    } else {
      // 次のターンの人を決める
      int nextTurn = evidenceTurn;
      for (int i = 1; i <= playerOrder.length; i++) {
        int idx2 = (evidenceTurn + i) % playerOrder.length;
        if ((allChosenTemp[playerOrder[idx2]] ?? []).length < 2) {
          nextTurn = idx2;
          break;
        }
      }
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'evidenceTurn': nextTurn});
    }
  }

  /// Firestoreから初期データを読み込む
  Future<void> _loadInitData() async {
    DocumentSnapshot<Map<String, dynamic>>? problemSnap;
    try {
      problemSnap = await FirebaseFirestore.instance
          .collection('problems')
          .doc(widget.problemId)
          .get();
    } catch (e) {
      problemSnap = null;
    }
    Map<String, dynamic> _problemData;
    if (problemSnap != null && problemSnap.exists) {
      _problemData = problemSnap.data() ?? {};
    } else {
      final jsonString = await rootBundle
          .loadString('assets/problems/${widget.problemId}.json');
      _problemData = json.decode(jsonString);
    }
    problemData = _problemData;

    // 共通証拠データの整形
    commonEvidence = [];
    if (problemData!['commonEvidence'] != null) {
      if (problemData!['commonEvidence'] is List) {
        for (final e in problemData!['commonEvidence']) {
          if (e is String) {
            commonEvidence.add({'title': e, 'detail': ''});
          } else if (e is Map<String, dynamic>) {
            commonEvidence.add(e);
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
    hostUid = roomData['hostUid'];
    playerOrder = List<String>.from(roomData['players'] ?? []);
    evidenceTurn = roomData['evidenceTurn'] ?? 0;
    privateChatPhase = roomData['privateChatPhase'] ?? false;
    currentPrivateChatterUid = roomData['currentPrivateChatterUid'];
    privateChatHistory = (roomData['privateChatHistory'] ?? [])
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    // ラウンド・フェーズ情報取得
    discussionRound = roomData['discussionRound'] ?? 1;
    phase = roomData['phase'] ?? 'discussion';

    // プレイヤー自身の情報取得
    final mySnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .get();
    playerData = mySnap.data() ?? {};
    playerName = playerData!['playerName'] ?? '';
    role = playerData!['role'] ?? '';
    availablePlayers = playerOrder.where((uid) => uid != widget.playerUid).toList();

    setState(() {
      loading = false;
    });
  }

  /// 話し合いタイマー開始
  void _startDiscussionTimer() {
    _discussionTimer?.cancel();
    setState(() {
      discussionSecondsLeft = discussionTimePerRound;
      discussionTimeUp = false;
    });
    _discussionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (discussionSecondsLeft > 0) {
        setState(() {
          discussionSecondsLeft--;
        });
      } else {
        _discussionTimer?.cancel();
        setState(() {
          discussionTimeUp = true;
        });
        // 話し合い終了時に個別チャットフェーズを開始
        await _goToPrivateChatPhase();
      }
    });
  }

  /// 個別チャットフェーズへ遷移
  Future<void> _goToPrivateChatPhase() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({
      'phase': 'privateChat',
      'privateChatPhase': true,
      // ホストから選択権を開始
      'currentPrivateChatterUid': hostUid,
      'privateChatHistory': [],
    });
  }

  /// アクティブな個別チャットを監視し、画面遷移に利用
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
        if (isActive && participants.contains(widget.playerUid)) {
          activeId = doc.id;
          break;
        }
      }
      setState(() {
        _activePrivateChatId = activeId;
      });
    });
  }

  /// 個別チャットの状態を監視し、アクティブ時にチャット画面へ遷移
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
        if (isActive &&
            participants.contains(widget.playerUid) &&
            !_isPrivateChatActive) {
          _isPrivateChatActive = true;
          Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (context) => PrivateChatScreen(
                  roomId: widget.roomId,
                  sessionId: doc.id,
                  timeLimitSeconds: PrivateChatScreen.defaultTimeLimitSeconds,
                  round: discussionRound,
                ),
              ))
              .then((_) async {
                // 個別チャット画面から戻ってきたら、個別チャット終了処理を呼び出す
                _isPrivateChatActive = false;
                await _onPrivateChatEnd(); // ここで確実に終了処理を呼び出す
              });
          break;
        }
      }
    });
  }

  /// 個別チャット全員終了チェック＆次ラウンド進行
  Future<void> _onPrivateChatEnd() async {
    // 自身がホストである場合のみ処理を実行 (二重実行防止)
    if (myUid != hostUid) return;

    final roomDocRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomDocRef);
      final roomData = roomSnap.data() ?? {};

      final currentPrivateChatHistory = (roomData['privateChatHistory'] ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
      final currentDiscussionRound = roomData['discussionRound'] ?? 1;
      final allPlayers = List<String>.from(roomData['players'] ?? []);

      final n = allPlayers.length;
      final totalPairs = (n * (n - 1)) ~/ 2; // 全ペア数
      final roundHistory = currentPrivateChatHistory.where((pair) => pair['round'] == currentDiscussionRound).toList();

      // 現在アクティブな個別チャットがあるか確認
      final privateChatsSnap = await roomDocRef.collection('privateChats').get();
      final anyActiveChats = privateChatsSnap.docs.any((doc) => (doc.data()['active'] ?? false));

      if (!anyActiveChats && roundHistory.length >= totalPairs) {
        // すべての個別チャットが非アクティブであり、かつ、そのラウンドの全ペアがチャット済み
        if (currentDiscussionRound < maxRounds) {
          // まだ次のラウンドがある
          transaction.update(roomDocRef, {
            'phase': 'discussion',
            'discussionRound': currentDiscussionRound + 1,
            'privateChatPhase': false,
            'privateChatHistory': [], // 次のラウンドのために履歴をリセット
            'discussionSecondsLeft': discussionTimePerRound,
            'discussionTimeUp': false,
            'discussionStarted': false,
            'currentPrivateChatterUid': null, // 次のフェーズに移るのでリセット
          });
        } else {
          // 全てのラウンドが終了
          transaction.update(roomDocRef, {
            'phase': 'suspicion',
            'privateChatPhase': false,
            'privateChatHistory': [], // フェーズ移行で履歴をリセット
            'currentPrivateChatterUid': null, // フェーズ移行でリセット
          });
        }
      } else if (!anyActiveChats && roundHistory.length < totalPairs) {
        // アクティブなチャットは無いが、まだチャットすべきペアが残っている場合
        // 次のチャット選択権を持つプレイヤーを決定
        String? nextChatter = _getNextChatterUid(
          allPlayers,
          currentPrivateChatHistory,
          currentDiscussionRound,
          currentPrivateChatterUid ?? hostUid!,
        );
      }
    });
  }

  /// 次の個別チャット選択権を持つプレイヤーを計算する
  String? _getNextChatterUid(
      List<String> allPlayers,
      List<Map<String, dynamic>> privateChatHistory,
      int discussionRound,
      String currentUid,
    ) {
      final currentIdx = allPlayers.indexOf(currentUid);
      for (int offset = 1; offset <= allPlayers.length; offset++) {
        final idx = (currentIdx + offset) % allPlayers.length;
        final candidate = allPlayers[idx];
        final available = getAvailableChatPartnersFor(
          candidate, privateChatHistory, allPlayers, discussionRound);
        if (available.isNotEmpty) {
          return candidate;
        }
      }
      return null;
    }


  /// チャットメッセージ送信
  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty || !discussionStarted || discussionTimeUp) return;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'uid': widget.playerUid,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _controller.clear();
  }

  /// 話していないプレイヤーリストを取得
  List<String> getAvailableChatPartners() {
    return getAvailableChatPartnersFor(
        widget.playerUid, privateChatHistory, playerOrder, discussionRound);
  }

  /// 個別チャット選択権があるか判定
  bool get canChoosePrivateChatPartner =>
      privateChatPhase &&
      currentPrivateChatterUid == widget.playerUid &&
      (currentPrivateChatterUid?.isNotEmpty ?? false) &&
      getAvailableChatPartners().isNotEmpty;

  /// 相手選択ダイアログを表示
  void _showPartnerSelectDialog() async {
    final partners = getAvailableChatPartners();
    if (partners.isEmpty) {
      // 選択可能なパートナーがいない場合はダイアログを表示しない
      return;
    }
    final partnerNames = <String, String>{};
    for (final uid in partners) {
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(uid)
          .get();
      partnerNames[uid] = snap.data()?['playerName'] ?? uid;
    }
    showDialog(
      context: context,
      builder: (ctx) => PartnerSelectDialog(
        partners: partners,
        partnerNames: partnerNames,
        onSelected: (uid) async {
          await _startPrivateChatWith(uid);
        },
      ),
    );
  }

  /// 指定した相手と個別チャット開始
 Future<void> _startPrivateChatWith(String partnerUid) async {
  final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
 
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final roomSnap = await transaction.get(roomDoc);
 
    final allPlayers = List<String>.from(roomSnap.data()?['players'] ?? []);
    final discussionRound = roomSnap.data()?['discussionRound'] ?? this.discussionRound;
    final privateChatHistory = (roomSnap.data()?['privateChatHistory'] ?? [])
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
 
    final chosenPair = {
      'a': widget.playerUid,
      'b': partnerUid,
      'round': discussionRound,
    };
 
    // すでに同じペア・同じラウンドでチャットしていたら何もしない
    final alreadyExists = privateChatHistory.any((pair) =>
      ((pair['a'] == widget.playerUid && pair['b'] == partnerUid) ||
      (pair['a'] == partnerUid && pair['b'] == widget.playerUid)) &&
      pair['round'] == discussionRound
    );
    if (alreadyExists) return;
 
    // 履歴追加
    privateChatHistory.add(chosenPair);
 
    // チャットルーム作成
    final chosenId =
        'private_${chosenPair['a']}_${chosenPair['b']}_${widget.roomId}_$discussionRound';
    final privateChatRef = roomDoc.collection('privateChats').doc(chosenId);
    transaction.set(privateChatRef, {
      'participants': [chosenPair['a'], chosenPair['b']],
      'startTimestamp': FieldValue.serverTimestamp(),
      'durationSeconds': PrivateChatScreen.defaultTimeLimitSeconds,
      'active': true,
      'round': discussionRound,
    });
 
    // 全ペア数
    final n = allPlayers.length;
    final totalPairs = (n * (n - 1)) ~/ 2;
    final roundHistory = privateChatHistory.where((pair) => pair['round'] == discussionRound).toList();
 
    if (roundHistory.length >= totalPairs) {
      // 全消化済み
      transaction.update(roomDoc, {
        'privateChatHistory': privateChatHistory,
        'currentPrivateChatterUid': null,
        'privateChatPhase': false,
      });
      return;
    }
 
    // 未消化ペアがある人をリストアップ
    List<String> remaining = allPlayers.where(
      (uid) => getAvailableChatPartnersFor(uid, privateChatHistory, allPlayers, discussionRound).isNotEmpty
    ).toList();
 
    // 順送りで直前チャットした人の次の人に渡す
    String lastChatterUid = widget.playerUid;
    String? nextChatterUid;
    final playerList = List<String>.from(allPlayers);
    int lastIdx = allPlayers.indexOf(lastChatterUid);
    // 順送りで playerOrder に従って次の人へ渡す（ホスト→B→C→D→...）
    for (int offset = 1; offset <= playerList.length; offset++) {
      final idx = (lastIdx + offset) % playerList.length;
      final candidate = playerList[idx];
      final available = getAvailableChatPartnersFor(candidate, privateChatHistory, playerList, discussionRound);
      if (available.isNotEmpty) {
        nextChatterUid = candidate;
        break;
      }
    }
    transaction.update(roomDoc, {
      'privateChatHistory': privateChatHistory,
      'currentPrivateChatterUid': nextChatterUid,
      'privateChatPhase': true,
    });
  });
}

  @override
  void dispose() {
    _discussionTimer?.cancel();
    _privateChatTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 画面描画
  @override
  Widget build(BuildContext context) {
    if (loading) {
      // ローディング中
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Firestoreの部屋情報を監視
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData) {
          // データ未取得
          return const Scaffold(
            backgroundColor: Color(0xFF23232A),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = roomSnap.data!.data() as Map<String, dynamic>;
        evidenceTurn = data['evidenceTurn'] ?? 0;
        bool evidenceChoosingPhase = data['evidenceChoosingPhase'] ?? true;
        playerOrder = List<String>.from(data['players'] ?? playerOrder);

        privateChatPhase = data['privateChatPhase'] ?? false;
        currentPrivateChatterUid = data['currentPrivateChatterUid'];
        privateChatHistory = (data['privateChatHistory'] ?? [])
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        // ラウンド・フェーズ監視
        discussionRound = data['discussionRound'] ?? 1;
        phase = data['phase'] ?? 'discussion';

        // 話し合いタイマーの開始判定
        if (phase == 'discussion' && !evidenceChoosingPhase &&
            (_prevDiscussionRound != discussionRound || !discussionStarted)) { // discussionStarted も条件に追加
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startDiscussionTimer();
            setState(() {
              discussionStarted = true;
              discussionTimeUp = false;
              _prevDiscussionRound = discussionRound;
            });
          });
        }

        // ラウンド・フェーズによる画面分岐
        if (phase == 'discussion') {
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
          // ホストの場合のみ、全チャット終了判定ロジックを実行するトリガーを設置
          // (PrivateChatPhaseWidget内でonPrivateChatEndが呼ばれることを期待)
          return PrivateChatPhaseWidget(
            roomId: widget.roomId,
            discussionRound: discussionRound,
            privateChatPhase: privateChatPhase,
            canChoosePrivateChatPartner: canChoosePrivateChatPartner,
            onShowPartnerSelectDialog: _showPartnerSelectDialog,
            onPrivateChatEnd: (myUid == hostUid) ? _onPrivateChatEnd : null, // ホストのみ終了判定をトリガー
          );
        } else if (phase == 'suspicion') {
          // 疑惑入力フェーズ
          return SuspicionInputScreen(
            roomId: widget.roomId,
            players: playerOrder, // プレイヤーリスト
            timeLimitSeconds: 60,
          );
        } else if (phase == 'end') {
          // 終了画面
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
          // その他フェーズ
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

  /// プレイヤー情報ダイアログ表示
  void _showPlayerInfoDialog() async {
    final mySnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .get();
    final latestPlayerData = mySnap.data() ?? {};

    showDialog(
      context: context,
      builder: (context) => PlayerInfoDialog(
        playerData: latestPlayerData,
        problemData: problemData,
      ),
    );
  }
}