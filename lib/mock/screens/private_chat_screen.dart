import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivateChatScreen extends StatefulWidget {
  final String roomId;
  final String sessionId;
  final int timeLimitSeconds;
  final int round;

  static const int defaultTimeLimitSeconds = 60;

  const PrivateChatScreen({
    Key? key,
    required this.roomId,
    required this.sessionId,
    this.timeLimitSeconds = defaultTimeLimitSeconds,
    this.round = 1,
  }) : super(key: key);

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  User? user;
  String? myName, myRole, peerUid, peerName, peerRole;
  TextEditingController textController = TextEditingController();
  int secondsLeft = 0;
  Timer? _timer;
  bool timeUp = false;
  int _fetchRetry = 0;
  bool _fetchFailed = false;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.timeLimitSeconds;
    user = FirebaseAuth.instance.currentUser;
    _fetchNamesAndRoles();
    _startTimer();
  }

  Future<void> _fetchNamesAndRoles() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('privateChats')
          .doc(widget.sessionId)
          .get();
      if (!doc.exists || doc.data()?['participants'] == null) {
        if (_fetchRetry < 30) {
          _fetchRetry++;
          Future.delayed(const Duration(milliseconds: 300), _fetchNamesAndRoles);
        } else {
          setState(() => _fetchFailed = true);
        }
        return;
      }

      List participantsRaw = doc.data()!['participants'];
      List<String> participants;
      if (participantsRaw.isNotEmpty && participantsRaw.first is Map) {
        participants = [];
        for (var pair in participantsRaw) {
          if (pair is Map) {
            if (pair['a'] != null) participants.add(pair['a']);
            if (pair['b'] != null) participants.add(pair['b']);
          }
        }
      } else {
        participants = participantsRaw.map((e) => e.toString()).toList();
      }
      if (participants.length < 2) {
        if (_fetchRetry < 30) {
          _fetchRetry++;
          Future.delayed(const Duration(milliseconds: 300), _fetchNamesAndRoles);
        } else {
          setState(() => _fetchFailed = true);
        }
        return;
      }
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (_fetchRetry < 30) {
          _fetchRetry++;
          Future.delayed(const Duration(milliseconds: 300), _fetchNamesAndRoles);
        } else {
          setState(() => _fetchFailed = true);
        }
        return;
      }
      String? myUid = user!.uid;
      peerUid = participants.firstWhere((id) => id != myUid, orElse: () => "");
      if (peerUid == null || peerUid == "") {
        if (_fetchRetry < 30) {
          _fetchRetry++;
          Future.delayed(const Duration(milliseconds: 300), _fetchNamesAndRoles);
        } else {
          setState(() => _fetchFailed = true);
        }
        return;
      }
      final myPlayerDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(myUid)
          .get();
      final peerPlayerDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(peerUid)
          .get();

      setState(() {
        myName = myPlayerDoc.data()?['playerName'] ?? user!.displayName ?? 'あなた';
        myRole = myPlayerDoc.data()?['role'] ?? '';
        peerName = peerPlayerDoc.data()?['playerName'] ?? '相手';
        peerRole = peerPlayerDoc.data()?['role'] ?? '';
        _fetchFailed = false;
      });
    } catch (e, st) {
      setState(() => _fetchFailed = true);
    }
  }

  void _endPrivateChat() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .doc(widget.sessionId)
        .update({'active': false});
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft > 0) {
        setState(() {
          secondsLeft--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          timeUp = true;
        });
        _endPrivateChat();
        Future.microtask(() {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (textController.text.trim().isEmpty || user == null || timeUp) return;
    final msg = {
      'from': user!.uid,
      'to': peerUid,
      'text': textController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('privateChats')
        .doc(widget.sessionId)
        .collection('messages')
        .add(msg);
    textController.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    textController.dispose();
    super.dispose();
  }

  // --- キャラクター情報ダイアログ(自分用) ---
  Future<void> _showMyCharacterInfo() async {
    final myDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(user!.uid)
        .get();
    final myData = myDoc.data() ?? {};

    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();
    final problemId = roomDoc.data()?['problemId'];
    Map<String, dynamic>? problemData;
    if (problemId != null) {
      final problemSnap = await FirebaseFirestore.instance
          .collection('problems')
          .doc(problemId)
          .get();
      problemData = problemSnap.data();
    }

    final evidenceList = List.from(myData['evidence'] ?? []);
    final winConditionsList = List.from(myData['winConditions'] ?? []);
    final description = myData['description'] ?? '';
    final List<Map<String, dynamic>> commonEvidenceList =
        List<Map<String, dynamic>>.from(problemData?['commonEvidence'] ?? []);
    final List<int> chosenEvidenceIndexes =
        List<int>.from(myData['chosenCommonEvidence'] ?? []);
    final myCommonEvidenceList = [
      for (final i in chosenEvidenceIndexes)
        if (i >= 0 && i < commonEvidenceList.length) commonEvidenceList[i]
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
                      '事件の舞台: ${problemData['title'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.amber,
                        letterSpacing: 2,
                      )),
                  const SizedBox(height: 8),
                  Text(problemData['story'] ?? '',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white70)),
                  const Divider(
                      color: Colors.amber,
                      height: 28,
                      thickness: 1.2),
                ],
                Text(
                    'あなたの役職: ${myData['role'] ?? ''}',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('あなたが選んだ共通証拠',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800])),
                      ...myCommonEvidenceList.map<Widget>(
                        (e) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('- ${e['title']}',
                                style: const TextStyle(
                                    color: Colors.white)),
                            if ((e['detail'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
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
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFF23232A);
    final Color barColor = Colors.black87;
    final Color mainAmber = Colors.amber[800]!;
    final Color userBubble = mainAmber;
    final Color peerBubble = Colors.white10;
    final Color inputBg = Colors.black38;
    final Color sendIconColor = Colors.amber;

    if (_fetchFailed) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'チャット相手の情報が取得できませんでした。\nしばらくして再度お試しください。',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _fetchRetry = 0;
                    _fetchFailed = false;
                  });
                  _fetchNamesAndRoles();
                },
                child: const Text("再試行"),
              )
            ],
          ),
        ),
      );
    }

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: Text("サインイン情報の取得中...", style: TextStyle(color: Colors.white))),
      );
    }

    if (peerUid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // タイマー・相手表示部分のウィジェット
    Widget timerAndPeerInfo = Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイマー表示（中央で大きく）
          Text(
            '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 48,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          // 相手情報の表示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                peerName != null && peerRole != null
                    ? '$peerName（$peerRole）さんとチャット中'
                    : 'チャット相手不明',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: barColor,
        title: Text(
          peerName != null && peerRole != null
              ? '${peerRole}（${peerName}）との個別チャット'
              : '個別チャット',
          style: const TextStyle(letterSpacing: 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.amber),
            tooltip: "あなたのキャラクター情報",
            onPressed: _showMyCharacterInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          timerAndPeerInfo,
          Container(
            color: Colors.black45,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  '個別チャットは制限時間内のみ有効です',
                  style: const TextStyle(color: Colors.amber, fontSize: 15),
                ),
                if (timeUp)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      '（終了）',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('privateChats')
                  .doc(widget.sessionId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('エラーが発生しました: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'まだメッセージがありません\n最初のメッセージを送ってみましょう',
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView(
                  reverse: false,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['from'] == user?.uid;
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(widget.roomId)
                          .collection('players')
                          .doc(data['from'])
                          .get(),
                      builder: (context, snap) {
                        String senderName = '';
                        String senderRole = '';
                        if (snap.hasData && snap.data != null) {
                          final sdata = snap.data!.data() as Map<String, dynamic>?;
                          senderName = sdata?['playerName'] ?? '';
                          senderRole = sdata?['role'] ?? '';
                        }
                        return Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                backgroundColor: mainAmber,
                                child: Text(
                                    senderRole.isNotEmpty
                                        ? senderRole[0]
                                        : '?',
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isMe ? userBubble : peerBubble,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 2),
                                    bottomRight: Radius.circular(isMe ? 2 : 18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderRole.isNotEmpty && senderName.isNotEmpty
                                          ? '$senderRole（$senderName）'
                                          : (senderName.isNotEmpty ? senderName : '名無し'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isMe ? Colors.white : mainAmber,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              CircleAvatar(
                                backgroundColor: mainAmber,
                                child: Text(
                                    senderRole.isNotEmpty
                                        ? senderRole[0]
                                        : '?',
                                    style: const TextStyle(color: Colors.white)),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          if (!timeUp)
            Container(
              color: inputBg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      enabled: !timeUp,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'メッセージを入力',
                        hintStyle: const TextStyle(color: Colors.white54),
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
                    icon: const Icon(Icons.send),
                    onPressed: (!timeUp && textController.text.trim().isNotEmpty)
                        ? _sendMessage
                        : null,
                    color: sendIconColor,
                  ),
                ],
              ),
            ),
          if (timeUp)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'チャット時間は終了しました。',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}