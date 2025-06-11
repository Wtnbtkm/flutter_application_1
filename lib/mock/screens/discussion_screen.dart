// 推理・チャット画面
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool choosingPhase = true;
  String? playerName;
  String? role;
  String? myUid;

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadInitData();
  }

  Future<void> _loadInitData() async {
    // Try Firestore first, else load from assets
    DocumentSnapshot<Map<String, dynamic>>? problemSnap;
    try {
      problemSnap = await FirebaseFirestore.instance
          .collection('problems')
          .doc(widget.problemId)
          .get();
    } catch (e) {
      problemSnap = null;
    }
    Map<String, dynamic> problemData;
    if (problemSnap != null && problemSnap.exists) {
      problemData = problemSnap.data() ?? {};
    } else {
      // assets fallback
      final jsonString = await rootBundle.loadString('assets/problems/${widget.problemId}.json');
      problemData = json.decode(jsonString);
    }
    // ここでMap<String, dynamic>型のリストに変換 (title/detail両方あり)
    commonEvidence = [];
    if (problemData['commonEvidence'] != null) {
      if (problemData['commonEvidence'] is List) {
        for (final e in problemData['commonEvidence']) {
          if (e is String) {
            commonEvidence.add({'title': e, 'detail': ''});
          } else if (e is Map<String, dynamic>) {
            commonEvidence.add(e);
          }
        }
      }
    }

    // Load room order, host
    final roomSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();
    final roomData = roomSnap.data() ?? {};
    hostUid = roomData['hostUid'];
    playerOrder = List<String>.from(roomData['players'] ?? []);
    evidenceTurn = roomData['evidenceTurn'] ?? 0;

    // Load my playerData
    final mySnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.playerUid)
        .get();
    final myData = mySnap.data() ?? {};
    playerName = myData['playerName'] ?? '';
    role = myData['role'] ?? '';

    setState(() {
      loading = false;
    });
  }

  Future<void> chooseEvidence(int idx) async {
    // Get my chosen
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

    // EvidenceTurnの制御（全員分Firestoreから取得して2つずつ終わったらフェーズ終了）
    final playersSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .get();
    Map<String, List<int>> allChosenTemp = {};
    for (final doc in playersSnap.docs) {
      allChosenTemp[doc.id] = List<int>.from(doc.data()['chosenCommonEvidence'] ?? []);
    }
    bool allDone = allChosenTemp.values.every((list) => list.length >= 2);

    if (allDone) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'evidenceChoosingPhase': false});
    } else {
      // 順番を進める
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF23232A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
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
            // 全員の選択状況
            allChosen = {};
            for (final doc in psnap.data!.docs) {
              allChosen[doc.id] = List<int>.from((doc.data() as Map<String, dynamic>)['chosenCommonEvidence'] ?? []);
              if (doc.id == widget.playerUid) {
                myChosen = allChosen[doc.id]!;
              }
            }

            // 証拠選択フェーズ
            if (evidenceChoosingPhase) {
              final isMyTurn = playerOrder.isNotEmpty && playerOrder[evidenceTurn] == widget.playerUid;
              final selectedCount = myChosen.length;
              final alreadyChosen = allChosen.values.expand((e) => e).toSet();

              return Scaffold(
                backgroundColor: const Color(0xFF23232A),
                appBar: AppBar(
                  backgroundColor: Colors.black87,
                  title: const Text('推理・チャット', style: TextStyle(letterSpacing: 2)),
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
                            style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isMyTurn && selectedCount < 2) ...[
                        Text(
                          "あなたの番です。共通証拠を選んでください（あと${2 - selectedCount}つ）",
                          style: const TextStyle(color: Colors.white, fontSize: 17),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < commonEvidence.length; i++)
                              ElevatedButton(
                                onPressed: alreadyChosen.contains(i) ? null : () => chooseEvidence(i),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: alreadyChosen.contains(i) ? Colors.grey : Colors.amber[800],
                                ),
                                child: Text(commonEvidence[i]['title'], style: const TextStyle(color: Colors.white)),
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
                          style: const TextStyle(color: Colors.white, fontSize: 17),
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

            // 証拠選択フェーズ終了→通常チャット＋配役・証拠確認
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black87,
                title: const Text('推理・チャット', style: TextStyle(letterSpacing: 2)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.assignment_ind, color: Colors.amber),
                    onPressed: () {
                      // 配役・証拠確認ダイアログ
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.black87,
                          title: const Text('あなたの情報', style: TextStyle(color: Colors.amber)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('配役: $role', style: const TextStyle(color: Colors.white)),
                              Text('プレイヤー名: $playerName', style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 10),
                              Text('あなたが選んだ共通証拠', style: const TextStyle(color: Colors.amber)),
                              for (final i in myChosen)
                                ListTile(
                                  dense: true,
                                  title: Text(commonEvidence[i]['title'], style: const TextStyle(color: Colors.white)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.info, color: Colors.amber),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: Colors.black87,
                                          title: Text(commonEvidence[i]['title'], style: const TextStyle(color: Colors.amber)),
                                          content: Text(commonEvidence[i]['detail'] ?? "詳細なし", style: const TextStyle(color: Colors.white)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              style: TextButton.styleFrom(foregroundColor: Colors.amber),
                                              child: const Text("閉じる"),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(foregroundColor: Colors.amber),
                              child: const Text("閉じる"),
                            )
                          ],
                        ),
                      );
                    },
                  )
                ],
              ),
              backgroundColor: const Color(0xFF23232A),
              body: SafeArea(
                child: Column(
                  children: [
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
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data!.docs;
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            itemCount: docs.length,
                            itemBuilder: (context, idx) {
                              final data = docs[idx].data() as Map<String, dynamic>;
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

/// チャット吹き出しウィジェット
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
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
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                      style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 16),
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