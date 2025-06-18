import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/PrivateChatScreen.dart';

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
  static const int privateChatDurationSeconds = 60; // 1分
  bool privateChatActive = false;
  bool _isPrivateChatActive = false;  
  bool _canEnterPrivateChat = false;
  String? _activePrivateChatId;

  // --- 話し合い全体タイマー制御 ---
  int discussionSecondsLeft = 60; // 1分
  Timer? _discussionTimer;
  bool discussionTimeUp = false;
  bool discussionStarted = false; // 証拠選択終了後にタイマーを開始するためのフラグ

  // 順番制御用
  List<List<String>> privateChatPairs = [];
  int privateChatTurn = 0;
  bool privateChatPhase = false;

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadInitData();
    _startPrivateChatListener();
    _listenActivePrivateChat();
    // _startDiscussionTimer(); // ←証拠選択後に呼ぶのでここはコメントアウト
  }

  void _startDiscussionTimer() {
    _discussionTimer?.cancel();
    setState(() {
      discussionSecondsLeft = 60;
      discussionTimeUp = false;
    });
    _discussionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (discussionSecondsLeft > 0) {
        setState(() {
          discussionSecondsLeft--;
        });
      } else {
        _discussionTimer?.cancel();
        setState(() {
          discussionTimeUp = true;
        });
      }
    });
  }

  void _listenActivePrivateChat() {
    FirebaseFirestore.instance
      .collection('rooms')
      .doc(widget.roomId)
      .collection('privateChats')
      .snapshots()
      .listen((snapshot) {
        bool found = false;
        String? activeId;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final List participants = data['participants'] ?? [];
          final bool isActive = data['active'] ?? true;
          if (isActive && participants.contains(widget.playerUid)) {
            found = true;
            activeId = doc.id;
            break;
          }
        }
        // 個別チャットは話し合い後のみ許可
        setState(() {
          _canEnterPrivateChat = found && discussionTimeUp;
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
          if (isActive && participants.contains(widget.playerUid) && !_isPrivateChatActive) {
            _isPrivateChatActive = true;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => PrivateChatScreen(
                roomId: widget.roomId,
                sessionId: doc.id,
                timeLimitSeconds: PrivateChatScreen.defaultTimeLimitSeconds,
                round: 1,
              ),
            )).then((_) {
              _isPrivateChatActive = false;
            });
            break;
          }
        }
      });
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
    privateChatTurn = roomData['privateChatTurn'] ?? 0;
    privateChatPairs = List<List<String>>.from(
      (roomData['privateChatPairs'] ?? []).map<List<String>>(
        (e) => List<String>.from(e),
      ),
    );

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

  Future<void> chooseEvidence(int idx) async {
    final ref = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid);
    final snap = await ref.get();
    List<int> chosen =
        List<int>.from(snap.data()?['chosenCommonEvidence'] ?? []);
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

  void _tryEnterPrivateChat() async {
    if (!_canEnterPrivateChat || _activePrivateChatId == null) return;
    final chatDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .doc(_activePrivateChatId)
        .get();
    final data = chatDoc.data();
    if (data == null) return;
    final List participants = data['participants'] ?? [];
    final bool isActive = data['active'] ?? true;
    if (!isActive || !participants.contains(widget.playerUid)) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PrivateChatScreen(
        roomId: widget.roomId,
        sessionId: _activePrivateChatId!,
        timeLimitSeconds: PrivateChatScreen.defaultTimeLimitSeconds,
        round: 1,
      ),
    ));
  }

  Widget _buildPrivateChatSelector({List<String>? candidates}) {
    final list = candidates ?? availablePlayers;
    return AlertDialog(
      backgroundColor: Colors.black87,
      title: const Text('個別チャット相手を選択', style: TextStyle(color: Colors.amber)),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final uid in list)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(widget.roomId)
                    .collection('players')
                    .doc(uid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final name = data?['playerName'] ?? '名無し';
                  return ListTile(
                    title: Text(name, style: const TextStyle(color: Colors.amber)),
                    onTap: () {
                      Navigator.pop(context);
                      _startPrivateChat(uid, name);
                    },
                  );
                },
              )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.amber),
          child: const Text('閉じる'),
        )
      ],
    );
  }

  void _startPrivateChat(String partnerUid, String partnerName) async {
    final uids = [widget.playerUid, partnerUid]..sort();
    final privateId = 'private_${uids[0]}_${uids[1]}_${widget.roomId}';
    final privateChatRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .doc(privateId);

    final doc = await privateChatRef.get();
    if (!doc.exists) {
      await privateChatRef.set({
        'participants': uids,
        'startTimestamp': FieldValue.serverTimestamp(),
        'durationSeconds': PrivateChatScreen.defaultTimeLimitSeconds,
        'active': true,
      });
    }
    // 遷移はリスナー任せ
  }

  Widget _buildPrivateChatOrderButton(bool showPrivateChatButton) {
    if (!privateChatPhase ||
        privateChatPairs.isEmpty ||
        privateChatTurn >= privateChatPairs.length) {
      return Container();
    }
    final nowPair = privateChatPairs[privateChatTurn];
    final isMyTurn = nowPair.contains(widget.playerUid);

    if (!isMyTurn) {
      final myNextIdx = privateChatPairs.indexWhere((pair) => pair.contains(widget.playerUid));
      final waitMsg = (myNextIdx > privateChatTurn)
          ? "あと${myNextIdx - privateChatTurn}ターンであなたの個別チャット順です"
          : "あなたの個別チャットは終了しました";
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(waitMsg, style: const TextStyle(color: Colors.amber)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.forum, color: Colors.white),
        style: ElevatedButton.styleFrom(
          backgroundColor: showPrivateChatButton ? Colors.amber[800] : Colors.grey,
        ),
        label: Text(
          showPrivateChatButton ? "個別チャットを開始" : "まだ開始できません",
          style: const TextStyle(color: Colors.white),
        ),
        onPressed: showPrivateChatButton ? _tryEnterPrivateChat : null,
      ),
    );
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
        privateChatTurn = data['privateChatTurn'] ?? 0;
        privateChatPairs = List<List<String>>.from(
          (data['privateChatPairs'] ?? []).map<List<String>>(
            (e) => List<String>.from(e),
          ),
        );

        // --- 話し合いタイマーの開始判定 ---
        if (!evidenceChoosingPhase && !discussionStarted) {
          _startDiscussionTimer();
          discussionStarted = true;
        }
        // 個別チャットボタン表示判定
        final showPrivateChatButton =
            !evidenceChoosingPhase && discussionTimeUp;

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
              final isMyTurn = playerOrder.isNotEmpty &&
                  playerOrder[evidenceTurn] == widget.playerUid;
              final selectedCount = myChosen.length;
              final alreadyChosen = allChosen.values.expand((e) => e).toSet();

              return Scaffold(
                backgroundColor: const Color(0xFF23232A),
                appBar: AppBar(
                  backgroundColor: Colors.black87,
                  title: const Text('推理・チャット',
                      style: TextStyle(letterSpacing: 2)),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.amber),
                          Text(
                            ' 1:00',
                            style: const TextStyle(
                                color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      if (isMyTurn && selectedCount < 2) ...[
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
                                    : () => chooseEvidence(i),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: alreadyChosen.contains(i)
                                      ? Colors.grey
                                      : Colors.amber[800],
                                ),
                                child: Text(commonEvidence[i]['title'],
                                    style:
                                        const TextStyle(color: Colors.white)),
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
                              ? "${playerOrder[evidenceTurn] == widget.playerUid ? "あなた" : "他のプレイヤー"}が証拠選択中です。しばらくお待ちください。"
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

            // 証拠選択フェーズ終了→通常チャット＋個別チャット順番制御
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black87,
                title: const Text('推理・チャット', style: TextStyle(letterSpacing: 2)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.amber),
                        Text(
                          ' ${discussionSecondsLeft ~/ 60}:${(discussionSecondsLeft % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forum, color: Colors.amber),
                    tooltip: '個別チャットを開始',
                    onPressed: showPrivateChatButton ? _tryEnterPrivateChat : null,
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
                    if (privateChatPhase)
                      _buildPrivateChatOrderButton(showPrivateChatButton),
                    if (discussionTimeUp)
                      Container(
                        color: Colors.red[900],
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          "話し合いの制限時間が終了しました。",
                          style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
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
                            onPressed: (discussionStarted && !discussionTimeUp) ? _sendMessage : null,
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
      },
    );
  }
}

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
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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