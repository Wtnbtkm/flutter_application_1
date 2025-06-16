import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/PrivateChatScreen.dart';

// --- 画面本体 ---
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
  static const int privateChatDurationSeconds = 1 * 60;
  bool privateChatActive = false;
  bool _isPrivateChatActive = false;  

  // 順番制御用
  List<List<String>> privateChatPairs = []; // [[uidA,uidB], ...]
  int privateChatTurn = 0; // 今のペアのインデックス
  bool privateChatPhase = false; // 個別チャットフェーズかどうか

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadInitData();
    _startPrivateChatListener();
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
      // まだチャット画面でない、activeなチャット、かつ自分が含まれてる
      if (isActive && participants.contains(widget.playerUid) && !_isPrivateChatActive) {
        // すでに表示中なら何もしない（例：フラグで管理するか、Navigator stackを確認）
        // まだなら遷移
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PrivateChatScreen(
            roomId: widget.roomId,
            sessionId: doc.id,
            timeLimitSeconds: PrivateChatScreen.defaultTimeLimitSeconds,
            round: 1,
          ),
        )).then((_){
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

    // 個別チャットフェーズ情報・順番取得
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
    if (message.isEmpty) return;
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

  /// 順番で自分の番の場合のみ、相手選択ダイアログ→開始
  void _tryEnterPrivateChat() async {
    if (!privateChatPhase) return;
    if (privateChatPairs.isEmpty || privateChatTurn >= privateChatPairs.length) return;
    final nowPair = privateChatPairs[privateChatTurn];
    if (!nowPair.contains(widget.playerUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("あなたの個別チャットの順番ではありません。")),
      );
      return;
    }
    // 2人ならそのまま、3人以上なら選択
    if (nowPair.length == 2) {
      final partnerUid = nowPair.firstWhere((uid) => uid != widget.playerUid);
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(partnerUid)
          .get();
      final data = snap.data() ?? {};
      final partnerName = data['playerName'] ?? '名無し';
      _startPrivateChat(partnerUid, partnerName);
    } else {
      showDialog(
        context: context,
        builder: (_) => _buildPrivateChatSelector(
          candidates: nowPair.where((uid) => uid != widget.playerUid).toList(),
        ),
      );
    }
  }

  /// 個別チャット相手選択ダイアログ（順番ペア対応）
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

  // --- 個別チャット開始 ---
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
    //ここで画面遷移して移動
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PrivateChatScreen(
        roomId: widget.roomId,
        sessionId: privateId,
        timeLimitSeconds: PrivateChatScreen.defaultTimeLimitSeconds,
        round: 1, // 必要に応じて
      ),
    ));

    /*setState(() {
      isPrivateChatMode = true;
      selectedPartnerUid = partnerUid;
      selectedPartnerName = partnerName;
      privateRoomId = privateId;
      privateChatActive = true;
      privateChatRemainingSeconds = PrivateChatScreen.defaultTimeLimitSeconds;
    });*/
  }

  // --- 個別チャット終了と順番進行 ---
  void _onFinishPrivateChat() async {
    _exitPrivateChat();
    // ホストだけ次へ
    if (widget.playerUid == hostUid) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'privateChatTurn': privateChatTurn + 1});
    }
  }

  void _exitPrivateChat() {
    _privateChatTimer?.cancel();
    setState(() {
      isPrivateChatMode = false;
      selectedPartnerUid = null;
      selectedPartnerName = null;
      privateRoomId = null;
      privateChatActive = false;
      privateChatRemainingSeconds = 0;
    });
  }

  @override
  void dispose() {
    _privateChatTimer?.cancel();
    super.dispose();
  }

  // --- 個別チャット順番ボタンUI ---
  Widget _buildPrivateChatOrderButton() {
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
    // 自分の順番のときだけボタン
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.forum, color: Colors.white),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
        label: const Text("個別チャットを開始", style: TextStyle(color: Colors.white)),
        onPressed: _tryEnterPrivateChat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ★個別チャット中はPrivateChatScreenで表示
    if (isPrivateChatMode && privateRoomId != null) {
      return PrivateChatScreen(
        roomId: widget.roomId,
        sessionId: privateRoomId!,
        timeLimitSeconds: privateChatRemainingSeconds > 0
            ? privateChatRemainingSeconds
            : PrivateChatScreen.defaultTimeLimitSeconds,
        round: 1, // 必要に応じて管理
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

        // 個別チャットフェーズ情報
        privateChatPhase = data['privateChatPhase'] ?? false;
        privateChatTurn = data['privateChatTurn'] ?? 0;
        privateChatPairs = List<List<String>>.from(
          (data['privateChatPairs'] ?? []).map<List<String>>(
            (e) => List<String>.from(e),
          ),
        );

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
                  IconButton(
                    icon: const Icon(Icons.forum, color: Colors.amber),
                    tooltip: '個別チャットを開始',
                    onPressed: () {
                      if (privateChatPhase) {
                        _tryEnterPrivateChat();
                      } else {
                        showDialog(
                          context: context,
                          builder: (_) => _buildPrivateChatSelector(),
                        );
                      }
                    },
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
                      _buildPrivateChatOrderButton(),
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
                            onPressed: _sendMessage,
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

// --- チャット吹き出しウィジェット ---
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