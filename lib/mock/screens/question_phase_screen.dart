// QuestionPhaseScreen質問・弁論画面（順番処理 + チャット + タイマー）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont';

class QuestionPhaseScreen extends StatefulWidget {
  final String roomId;
  final int questionTimeLimit;
  final List<String> players;

  const QuestionPhaseScreen({
    Key? key,
    required this.roomId,
    required this.players,
    this.questionTimeLimit = 30,
  }) : super(key: key);

  @override
  State<QuestionPhaseScreen> createState() => _QuestionPhaseScreenState();
}

class _QuestionPhaseScreenState extends State<QuestionPhaseScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<String> suspicionOrder = [];
  int currentIndex = 0;
  int secondsLeft = 0;
  Timer? timer;
  String? currentSuspectUid;
  String? currentSuspectName;
  Map<String, Map<String, String>> playerInfo = {}; // uid -> {name, role}
  final TextEditingController _chatController = TextEditingController();

  String? myName;
  String? myRole;

  @override
  void initState() {
    super.initState();
    _loadPlayerInfo().then((_) => _loadSuspicionOrder());
  }

  Future<void> _loadPlayerInfo() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .get();
    for (var doc in snapshot.docs) {
      playerInfo[doc.id] = {
        'name': doc.data()['playerName'] ?? '名無し',
        'role': doc.data()['role'] ?? '役職不明',
      };
    }
    myName = playerInfo[user?.uid]?['name'] ?? '自分';
    myRole = playerInfo[user?.uid]?['role'] ?? '不明';
  }

  Future<void> _loadSuspicionOrder() async {
    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('suspicions')
        .get();
    final Map<String, int> count = {};
    for (var doc in snap.docs) {
      final suspect = doc.data()['suspect'] ?? '';
      if (suspect.isNotEmpty) count[suspect] = (count[suspect] ?? 0) + 1;
    }
    final sorted = count.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    suspicionOrder = sorted.map((e) => e.key).toList();
    _startNextPhase();
  }

  void _startNextPhase() {
    if (currentIndex >= suspicionOrder.length) return;
    currentSuspectUid = suspicionOrder[currentIndex];
    currentSuspectName = playerInfo[currentSuspectUid]?['name'] ?? '???';
    secondsLeft = widget.questionTimeLimit;
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        secondsLeft--;
        if (secondsLeft <= 0) {
          timer?.cancel();
          currentIndex++;
          _startNextPhase();
        }
      });
    });
  }

  void _sendChat() async {
    if (_chatController.text.trim().isEmpty || user == null) return;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('questionChats')
        .add({
      'uid': user!.uid,
      'message': _chatController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    _chatController.clear();
  }

  Widget _buildChatArea() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: mmCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mmAccent),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('questionChats')
              .orderBy('timestamp')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            return ListView(
              padding: const EdgeInsets.all(8),
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final uid = data['uid'] ?? '';
                final name = playerInfo[uid]?['name'] ?? '名無し';
                final role = playerInfo[uid]?['role'] ?? '役職不明';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '[$name／$role]：${data['message']}',
                    style: const TextStyle(color: Colors.white, fontFamily: mmFont),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        title: const Text('質疑応答フェーズ', style: TextStyle(fontFamily: mmFont)),
        backgroundColor: mmCard,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myName != null && myRole != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'あなたは【$myName／$myRole】です',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: mmFont,
                  ),
                ),
              ),
            if (currentSuspectName != null)
              Text(
                '【現在の回答者】：$currentSuspectName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mmAccent,
                  fontFamily: mmFont,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '残り時間：$secondsLeft 秒',
              style: const TextStyle(color: Colors.white, fontFamily: mmFont),
            ),
            const SizedBox(height: 10),
            _buildChatArea(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white, fontFamily: mmFont),
                    decoration: InputDecoration(
                      hintText: '質問を書く...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: mmCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendChat,
                  child: const Icon(Icons.send, color: Colors.white),
                  style: ElevatedButton.styleFrom(backgroundColor: mmAccent),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
