import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//投票画面（誰が怪しいかを投票するフェーズ）
class VotingScreen extends StatefulWidget {
  final String roomId;
  final List<Map<String, dynamic>> players;
  final int votingTimeLimit;

  const VotingScreen({
    Key? key,
    required this.roomId,
    required this.players,
    this.votingTimeLimit = 120,
  }) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String? selectedPlayerUid;
  int secondsLeft = 0;
  Timer? _timer;
  bool _hasNavigated = false;
  bool _isSubmitting = false;
  int totalPlayerCount = 0;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.votingTimeLimit;
    totalPlayerCount = widget.players.length;

    _startVotingWatcher(); //投票状況の監視
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft > 0) {
        setState(() => secondsLeft--);
      } else {
        _onVoteTimeout();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startVotingWatcher() {
  final votesRef = FirebaseFirestore.instance
      .collection('rooms')
      .doc(widget.roomId)
      .collection('votes');

  votesRef.snapshots().listen((snapshot) {
    final voteCount = snapshot.docs.length;
    if (voteCount >= totalPlayerCount && !_hasNavigated) {
      _navigateToResult();
    }
  });
}

  Future<void> _submitVote() async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('votes')
        .doc(user!.uid)
        .set({
      'votedUid': selectedPlayerUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _navigateToResult();
  }

  Future<void> _onVoteTimeout() async {
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('votes')
          .doc(user!.uid)
          .set({
        'votedUid': selectedPlayerUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _navigateToResult() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    late StreamSubscription<DocumentSnapshot> subscription;
    // criminalUid を監視し、取得できたら遷移
    subscription = roomRef.snapshots().listen((snapshot) async {
    final data = snapshot.data();
    final criminalUid = data?['criminalUid'];

    if (criminalUid != null && criminalUid.toString().isNotEmpty) {
      await subscription.cancel(); // 一度取得したら監視終了

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VotingResultScreen(
            roomId: widget.roomId,
            criminalUid: criminalUid,// ここは必要に応じて変更
          ),
        ),
      );
    }
  });

  // タイムアウト対策（10秒後に取得できなければ警告）
  Future.delayed(const Duration(seconds: 10), () async {
    final snapshot = await roomRef.get();
    final criminalUid = snapshot.data()?['criminalUid'];
    if (!_hasNavigated && (criminalUid == null || criminalUid.toString().isEmpty)) {
      await subscription.cancel();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('エラー'),
          content: const Text('犯人情報がまだ設定されていません。\n少し待ってから再試行してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投票フェーズ')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  '残り: $secondsLeft 秒',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '誰に投票しますか？',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (selectedPlayerUid != null)
              Text(
                '現在の選択: ${widget.players.firstWhere((p) => p['uid'] == selectedPlayerUid)['name']}',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: widget.players.map((player) {
                  final uid = player['uid'] as String;
                  final name = player['name'] as String;
                  return RadioListTile<String>(
                    value: uid,
                    groupValue: selectedPlayerUid,
                    onChanged: (value) {
                      setState(() => selectedPlayerUid = value);
                    },
                    title: Text(name),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
              onPressed: (selectedPlayerUid == null || _isSubmitting)
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      await _submitVote();
                    },
              child: const Text('投票する'),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class VotingResultScreen extends StatelessWidget {
  final String roomId;
  final String criminalUid;

  const VotingResultScreen({
    Key? key,
    required this.roomId,
    required this.criminalUid,
  }) : super(key: key);

  Future<Map<String, dynamic>> _fetchVotingResult() async {
    final votesSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('votes')
        .get();

    final voteCount = <String, int>{};
    for (var doc in votesSnap.docs) {
      final votedUid = doc.data()['votedUid'];
      if (votedUid != null) {
        voteCount[votedUid] = (voteCount[votedUid] ?? 0) + 1;
      }
    }

    // 得票数が最大のプレイヤーを複数取得
    int maxVotes = 0;
    List<String> maxUids = [];

    voteCount.forEach((uid, count) {
      if (count > maxVotes) {
        maxVotes = count;
        maxUids = [uid];
      } else if (count == maxVotes) {
        maxUids.add(uid);
      }
    });

    // プレイヤー名を取得
    List<String> maxNames = [];
    for (final uid in maxUids) {
      final doc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .doc(uid)
          .get();
      maxNames.add(doc.data()?['name'] ?? '???');
    }

    final cDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(criminalUid)
        .get();

    final criminalName = cDoc.data()?['name'] ?? '不明';
    final isCriminal = maxUids.contains(criminalUid);

    return {
      'maxUids': maxUids,
      'maxNames': maxNames,
      'maxVotes': maxVotes,
      'isCriminal': isCriminal,
      'criminalName': criminalName,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投票結果発表')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchVotingResult(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  '投票結果',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if ((result['maxNames'] as List).isNotEmpty)
                  Column(
                    children: [
                      Text(
                        '最多票: ${result['maxNames'].join(", ")}（${result['maxVotes']}票）',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        result['isCriminal']
                            ? '正解！${result['maxNames'].join(",")}が犯人です！'
                            : '残念…犯人は「${result['criminalName']}」でした',
                        style: TextStyle(
                          color: result['isCriminal'] ? Colors.green : Colors.red,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  const Text('投票がありませんでした。'),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: () {
                    // 次へ進むボタン処理（例: ホームに戻る、ゲーム終了など）
                  },
                  child: const Text('次へ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
