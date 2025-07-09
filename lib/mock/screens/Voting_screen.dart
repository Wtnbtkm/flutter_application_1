import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 投票画面
class VotingScreen extends StatefulWidget {
  final String roomId;
  final List<Map<String, dynamic>> players; // [{'uid': ..., 'name': ...}, ...]
  final int votingTimeLimit; // 投票時間制限（秒）

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

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.votingTimeLimit;
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

  Future<void> _submitVote() async {
    if (selectedPlayerUid == null || user == null) return;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('votes')
        .doc(user!.uid)
        .set({
      'votedUid': selectedPlayerUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    Navigator.pushReplacementNamed(context, '/result', arguments: widget.roomId);
  }

  void _onVoteTimeout() {
    // タイムアップ時に投票しなければ自動遷移（投票しなかった場合はnull扱い）
    if (selectedPlayerUid != null) {
      _submitVote();
    } else {
      // 未投票として記録
      if (user != null) {
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .collection('votes')
            .doc(user!.uid)
            .set({
          'votedUid': null,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      Navigator.pushReplacementNamed(context, '/result', arguments: widget.roomId);
    }
    _timer?.cancel();
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
                onPressed: selectedPlayerUid == null ? null : _submitVote,
                child: const Text('投票する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 結果発表画面
class VotingResultScreen extends StatelessWidget {
  final String roomId;
  final String criminalUid; // ゲームマスターが正解(犯人)のUIDを知っている前提

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

    // 集計
    final voteCount = <String, int>{};
    for (var doc in votesSnap.docs) {
      final votedUid = doc.data()['votedUid'];
      if (votedUid != null) {
        voteCount[votedUid] = (voteCount[votedUid] ?? 0) + 1;
      }
    }
    // 最多票
    String? maxUid;
    int maxVotes = 0;
    voteCount.forEach((uid, count) {
      if (count > maxVotes) {
        maxVotes = count;
        maxUid = uid;
      }
    });
    // 名前取得
    String maxName = '';
    if (maxUid != null) {
      final pDoc = await FirebaseFirestore.instance.collection('players').doc(maxUid).get();
      maxName = pDoc.data()?['playerName'] ?? '';
    }
    // 犯人かどうか
    final isCriminal = maxUid == criminalUid;
    // 犯人名取得
    String criminalName = '';
    final cDoc = await FirebaseFirestore.instance.collection('players').doc(criminalUid).get();
    criminalName = cDoc.data()?['playerName'] ?? '';

    return {
      'maxUid': maxUid,
      'maxName': maxName,
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
                if (result['maxUid'] != null)
                  Column(
                    children: [
                      Text(
                        '最多票: ${result['maxName']}（${result['maxVotes']}票）',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        result['isCriminal']
                            ? '正解！${result['maxName']}が犯人です！'
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
                    //その後のストーリーなどを表示させる
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