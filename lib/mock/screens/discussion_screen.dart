import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/private_chat_screen.dart';
import 'package:flutter_application_1/mock/screens/evidence_selection_screen.dart';

class DiscussionScreen extends StatefulWidget {
  final String roomId;
  final String problemId;
  final String playerUid;
  const DiscussionScreen({
    Key? key,
    required this.roomId,
    required this.problemId,
    required this.playerUid,
  }) : super(key: key);

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> commonEvidence = [];
  bool loading = true;
  List<String> playerOrder = [];
  int evidenceTurn = 0;
  String? hostUid;
  Map<String, List<int>> allChosen = {};
  List<int> myChosen = [];
  String? playerName;
  String? role;
  String? myUid;
  Map<String, dynamic>? playerData;
  Map<String, dynamic>? problemData;

  // --- 個別チャット用フィールド ---
  bool isPrivateChatMode = false;
  List<String> availablePlayers = [];
  String? selectedPartnerUid;
  String? selectedPartnerName;
  String? privateRoomId;
  Timer? _privateChatTimer;
  int privateChatRemainingSeconds = 0;
  bool privateChatActive = false;
  bool _isPrivateChatActive = false;
  String? _activePrivateChatId;

  // --- 話し合い全体タイマー制御 ---
  int discussionSecondsLeft = 60;
  Timer? _discussionTimer;
  bool discussionTimeUp = false;
  bool discussionStarted = false;

  // 個別チャット制御用
  bool privateChatPhase = false;
  String? currentPrivateChatterUid;
  List<Map<String, dynamic>> privateChatHistory = [];

  // --- ラウンド管理用追加 ---
  int discussionRound = 1;
  String phase = 'discussion'; // 'discussion' or 'privateChat' or 'end'
  static const int maxRounds = 3;
  static const int discussionTimePerRound = 60;

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadInitData();
    _startPrivateChatListener();
    _listenActivePrivateChat();
  }
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
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({'evidenceChoosingPhase': false});
  } else {
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

    // --- ラウンド・フェーズ読み込み ---
    discussionRound = roomData['discussionRound'] ?? 1;
    phase = roomData['phase'] ?? 'discussion';

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

  Future<void> _goToPrivateChatPhase() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({
      'phase': 'privateChat',
      'privateChatPhase': true,
      'currentPrivateChatterUid': hostUid,
      'privateChatHistory': [],
    });
  }

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
              .then((_) {
            _isPrivateChatActive = false;
          });
          break;
        }
      }
    });
  }

  // --- 個別チャット全員終了チェック＆次ラウンド進行 ---
  Future<void> _onPrivateChatEnd() async {
    final privateChatsSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .get();
    final allInactive = privateChatsSnap.docs
        .every((doc) => (doc.data()['active'] ?? false) == false);
    if (allInactive) {
      if (discussionRound < maxRounds) {
        //まだ次のラウンドがある
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({
          'phase': 'discussion',
          'discussionRound': discussionRound + 1,
          'privateChatPhase': false,
          'privateChatHistory': [],
          'discussionSecondsLeft': discussionTimePerRound,
          'discussionTimeUp': false,
          'discussionStarted': false,
        });
      } else if (discussionRound == maxRounds){
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({
          'phase': 'end',
          'privateChatPhase': false,
          'privateChatHistory': [],
        });
      }
    }
  }

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

  List<String> getAvailableChatPartners() {
    return playerOrder.where((uid) {
      if (uid == widget.playerUid) return false;
      return !privateChatHistory.any((pair) =>
          (pair['a'] == widget.playerUid && pair['b'] == uid) ||
          (pair['a'] == uid && pair['b'] == widget.playerUid));
    }).toList();
  }

  bool get canChoosePrivateChatPartner =>
      privateChatPhase &&
      currentPrivateChatterUid == widget.playerUid &&
      getAvailableChatPartners().isNotEmpty;

  void _showPartnerSelectDialog() async {
    final partners = getAvailableChatPartners();
    if (partners.isEmpty) return;
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
        builder: (ctx) => AlertDialog(
              backgroundColor: Colors.black87,
              title: const Text("個別チャット相手を選択",
                  style: TextStyle(color: Colors.amber)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: partners
                    .map((uid) => ListTile(
                          title: Text(partnerNames[uid] ?? uid,
                              style: const TextStyle(color: Colors.white)),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _startPrivateChatWith(uid);
                          },
                        ))
                    .toList(),
              ),
            ));
  }

  Future<void> _startPrivateChatWith(String partnerUid) async {
    final chosenPair = {
      'a': widget.playerUid,
      'b': partnerUid,
    };
    final allPlayers = List<String>.from(playerOrder);

    final newHistory = List<Map<String, dynamic>>.from(privateChatHistory);
    newHistory.add(chosenPair);

    final Set<String> alreadyPaired = {widget.playerUid, partnerUid};
    final restPlayers =
        allPlayers.where((uid) => !alreadyPaired.contains(uid)).toList();
    
    List<Map<String, dynamic>> restPairs = [];
    for (int i = 0; i + 1 < restPlayers.length; i += 2) {
      restPairs.add({'a': restPlayers[i], 'b': restPlayers[i + 1]});
      newHistory.add({'a': restPlayers[i], 'b': restPlayers[i + 1]});
    }

    final chosenId =
        'private_${chosenPair['a']}_${chosenPair['b']}_${widget.roomId}_$discussionRound';
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .doc(chosenId)
        .set({
      'participants': [chosenPair['a'], chosenPair['b']],
      'startTimestamp': FieldValue.serverTimestamp(),
      'durationSeconds': PrivateChatScreen.defaultTimeLimitSeconds,
      'active': true,
      'round': discussionRound,
    });

    for (final pair in restPairs) {
      final pairSorted = [pair['a'], pair['b']]..sort();
      final restId =
          'private_${pairSorted[0]}_${pairSorted[1]}_${widget.roomId}_$discussionRound';
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('privateChats')
          .doc(restId)
          .set({
        'participants': pairSorted,
        'startTimestamp': FieldValue.serverTimestamp(),
        'durationSeconds': PrivateChatScreen.defaultTimeLimitSeconds,
        'active': true,
        'round': discussionRound,
      });
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({
      'privateChatHistory': newHistory,
      'currentPrivateChatterUid': partnerUid,
    });

    final totalPairs = (allPlayers.length * (allPlayers.length - 1)) ~/ 2;
    if (newHistory.length >= totalPairs) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({
        'privateChatPhase': false,
      });
    }
    // 遷移はリスナーで行うためここでは不要
  }

  @override
  void dispose() {
    _discussionTimer?.cancel();
    _privateChatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData) {
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

        // --- ラウンド・フェーズ監視 ---
        discussionRound = data['discussionRound'] ?? 1;
        phase = data['phase'] ?? 'discussion';

        // --- 話し合いタイマーの開始判定 ---
        if (phase == 'discussion' && !evidenceChoosingPhase && !discussionStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startDiscussionTimer();
            setState(() {
              discussionStarted = true;
            });
          });
        }

        // --- ラウンド・フェーズによる分岐 ---
        if (phase == 'discussion') {
          return _buildDiscussionPhase(context, evidenceChoosingPhase, data);
        } else if (phase == 'privateChat') {
          return _buildPrivateChatPhase(context);
        } else if (phase == 'end') {
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

  Widget _buildDiscussionPhase(BuildContext context, bool evidenceChoosingPhase, Map<String, dynamic> data) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .snapshots(),
      builder: (context, psnap) {
        if (!psnap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF23232A),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        allChosen = {};
        for (final doc in psnap.data!.docs) {
          allChosen[doc.id] = List<int>.from(
              (doc.data() as Map<String, dynamic>)['chosenCommonEvidence'] ??
                  []);
          if (doc.id == widget.playerUid) {
            myChosen = allChosen[doc.id]!;
          }
        }

        if (evidenceChoosingPhase) {
          final isMyTurnDraft = playerOrder.isNotEmpty &&
              playerOrder[evidenceTurn] == widget.playerUid;
          final alreadyChosen = allChosen.values.expand((e) => e).toSet();

          return EvidenceSelectionScreen(
            commonEvidence: commonEvidence,
            myChosen: myChosen,
            playerOrder: playerOrder,
            evidenceTurn: evidenceTurn,
            alreadyChosen: alreadyChosen.cast<int>(),
            isMyTurnDraft: isMyTurnDraft,
            playerUid: widget.playerUid,
            onChooseEvidence: chooseEvidence,
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black87,
            title: Text('推理・チャット 第$discussionRoundラウンド',
                style: const TextStyle(letterSpacing: 2)),
            actions: [
              if (canChoosePrivateChatPartner)
                IconButton(
                  icon: const Icon(Icons.forum, color: Colors.amber),
                  tooltip: '個別チャット相手を選択',
                  onPressed: _showPartnerSelectDialog,
                ),
              IconButton(
                icon: const Icon(Icons.assignment_ind, color: Colors.amber),
                onPressed: () async {
                  final mySnap = await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.roomId)
                      .collection('players')
                      .doc(widget.playerUid)
                      .get();
                  final latestPlayerData = mySnap.data() ?? {};

                  final evidenceList = List.from(latestPlayerData['evidence'] ?? []);
                  final winConditionsList =
                      List.from(latestPlayerData['winConditions'] ?? []);
                  final description = latestPlayerData['description'] ?? '';
                  final List<Map<String, dynamic>> commonEvidenceList =
                      List<Map<String, dynamic>>.from(problemData?['commonEvidence'] ?? []);
                  final List<int> chosenEvidenceIndexes =
                      List<int>.from(latestPlayerData['chosenCommonEvidence'] ?? []);
                  final myCommonEvidenceList = [
                    for (final i in chosenEvidenceIndexes)
                      if (i >= 0 && i < commonEvidenceList.length)
                        commonEvidenceList[i]
                  ];

                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: Colors.black87,
                        title: const Text('あなたのキャラクター情報',
                            style: TextStyle(color: Colors.amber)),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (problemData != null) ...[
                                Text(
                                    '事件の舞台: ${problemData!['title'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.amber,
                                      letterSpacing: 2,
                                    )),
                                const SizedBox(height: 8),
                                Text(problemData!['story'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white70)),
                                const Divider(
                                    color: Colors.amber,
                                    height: 28,
                                    thickness: 1.2),
                              ],
                              Text(
                                  'あなたの役職: ${latestPlayerData['role'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.amber)),
                              const SizedBox(height: 8),
                              Text('背景: $description',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white)),
                              const SizedBox(height: 10),
                              Text('証拠:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[700])),
                              ...evidenceList.map<Widget>((e) =>
                                  Text('- $e',
                                      style: const TextStyle(
                                          color: Colors.white))),
                              const SizedBox(height: 10),
                              Text('勝利条件:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[700])),
                              ...winConditionsList.map<Widget>((e) =>
                                  Text('- $e',
                                      style: const TextStyle(
                                          color: Colors.white))),
                              const Divider(
                                  color: Colors.amber,
                                  height: 28,
                                  thickness: 1.2),
                              if (myCommonEvidenceList.isNotEmpty)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('あなたが選んだ共通証拠',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[800])),
                                    ...myCommonEvidenceList.map<Widget>(
                                      (e) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('- ${e['title']}',
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                          if ((e['detail'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                      left: 12,
                                                      bottom: 4),
                                              child: Text('${e['detail']}',
                                                  style: const TextStyle(
                                                      color:
                                                          Colors.white70,
                                                      fontSize: 13)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.amber),
                            child: const Text("閉じる"),
                          )
                        ],
                      );
                    },
                  );
                },
              )
            ],
          ),
          backgroundColor: const Color(0xFF23232A),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18.0, bottom: 10.0),
                  child: Center(
                    child: Text(
                      '${discussionSecondsLeft ~/ 60}:${(discussionSecondsLeft % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 40,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                if (privateChatPhase && !canChoosePrivateChatPartner)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      currentPrivateChatterUid == widget.playerUid
                          ? "個別チャットで話せる相手がいません"
                          : currentPrivateChatterUid == null
                              ? "個別チャット順番待ち"
                              : "現在${currentPrivateChatterUid == widget.playerUid ? "あなた" : "他のプレイヤー"}が個別チャット相手を選択中です",
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                if (discussionTimeUp)
                  Container(
                    color: Colors.red[900],
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      "話し合いの制限時間が終了しました。",
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rooms')
                        .doc(widget.roomId)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, idx) {
                          final data =
                              docs[idx].data() as Map<String, dynamic>;
                          final senderUid = data['uid'] ?? '';
                          final text = data['text'] ?? '';
                          return _ChatMessageBubble(
                            roomId: widget.roomId,
                            senderUid: senderUid,
                            text: text,
                            isMe: senderUid == widget.playerUid,
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  color: Colors.black26,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          enabled: discussionStarted && !discussionTimeUp,
                          decoration: InputDecoration(
                            hintText: 'メッセージを入力',
                            hintStyle: TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black38,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.amber),
                        onPressed: (discussionStarted && !discussionTimeUp)
                            ? _sendMessage
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivateChatPhase(BuildContext context) {
    // 個別チャット自体はPrivateChatScreenでやるので
    // ここは案内（または何も表示しなくてもOK）
    _onPrivateChatEnd(); // 全員終了チェック
    return Scaffold(
      backgroundColor: const Color(0xFF23232A),
      body: Center(
        child: Text(
          "個別チャットフェーズ 第$discussionRoundラウンドです。\n全員の個別チャットが終了すると次の話し合いフェーズに進みます。",
          style: const TextStyle(
              fontSize: 18, color: Colors.amber, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// --- 既存のチャットバブル ---
class _ChatMessageBubble extends StatelessWidget {
  final String roomId;
  final String senderUid;
  final String text;
  final bool isMe;

  const _ChatMessageBubble({
    required this.roomId,
    required this.senderUid,
    required this.text,
    required this.isMe,
  });

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
            if (!isMe) ...[
              CircleAvatar(
                backgroundColor: Colors.amber[800],
                child: Text(role.isNotEmpty ? role[0] : '?',
                    style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  color: isMe ? Colors.amber[800] : Colors.white10,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 2),
                    bottomRight: Radius.circular(isMe ? 2 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.isNotEmpty && senderName.isNotEmpty
                          ? '$role（$senderName）'
                          : (senderName.isNotEmpty ? senderName : '名無し'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.amber[800],
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      text,
                      style: TextStyle(
                          color: isMe ? Colors.white : Colors.white70,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 6),
              CircleAvatar(
                backgroundColor: Colors.amber[800],
                child: Text(role.isNotEmpty ? role[0] : '?',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ],
        );
      },
    );
  }
}