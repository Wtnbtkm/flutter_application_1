//配役や自分の情報を知った後に公開されている証拠を選択し、選択した証拠を情報を見れる。他の人とのかぶりはダメ
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore構造例
/// rooms/{roomId}/
///   evidencePool: [ { id: 'ev1', title: '証拠1', description: '...' }, ... ]
///   evidenceSelections/{playerUid}: { evidenceId: 'ev1', playerName: '...', timestamp: ... }

///証拠選択画面ウィジェット
class EvidenceSelectionScreen extends StatefulWidget {
  final String roomId;

  const EvidenceSelectionScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<EvidenceSelectionScreen> createState() => _EvidenceSelectionScreenState();
}

class _EvidenceSelectionScreenState extends State<EvidenceSelectionScreen> {
  String? myUid;
  String? myName;
  String? selectedEvidenceId;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    // 現在ログイン中のユーザー情報を取得
    final user = FirebaseAuth.instance.currentUser;
    myUid = user?.uid;
    _fetchMyName();// プレイヤー名の取得
  }

  /// Firestoreのplayersコレクションから自分の名前を取得
  Future<void> _fetchMyName() async {
    if (myUid == null) return;
    final playerDoc = await FirebaseFirestore.instance.collection('players').doc(myUid!).get();
    setState(() {
      myName = playerDoc.data()?['playerName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? '名無し';
    });
  }

  /// 証拠を選択する処理
  Future<void> _selectEvidence(String evidenceId) async {
    if (myUid == null || myName == null) return;
    setState(() { submitting = true; });
    // まず既に誰かが選択していないか確認
    final selections = await FirebaseFirestore.instance
        .collection('rooms').doc(widget.roomId)
        .collection('evidenceSelections').get();
    final selectedIds = selections.docs.map((d) => d.data()['evidenceId'] as String).toSet();
    if (selectedIds.contains(evidenceId)) {
      // 他の人が選択済みの場合はエラー表示してreturn
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('この証拠は既に他の人が選択しています')));
      setState(() { submitting = false; });
      return;
    }
    // 選択内容をFirestoreに保存（上書き可能）
    await FirebaseFirestore.instance
        .collection('rooms').doc(widget.roomId)
        .collection('evidenceSelections').doc(myUid!)
        .set({
      'evidenceId': evidenceId,
      'playerName': myName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    setState(() {
      selectedEvidenceId = evidenceId;
      submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('証拠選択フェーズ')),
      // 部屋のドキュメント（evidencePool配列）を監視
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List evidences = data['evidencePool'] ?? [];

          // 証拠選択状況を監視
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms').doc(widget.roomId)
                .collection('evidenceSelections').snapshots(),
            builder: (context, selectSnap) {
              if (!selectSnap.hasData) return const Center(child: CircularProgressIndicator());
              // 選択状況を取得
              final selections = selectSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
              final Set selectedEvidenceIds = selections.map((s) => s['evidenceId'] as String).toSet();
              // 証拠ID→選択者名のマップ作成
              final Map<String, String> whoSelected = {
                for (var s in selections) s['evidenceId']: s['playerName']
              };
              // 自分の選択状況を取得
              final mySelection = selections.firstWhere(
                  (s) => s['playerName'] == myName, orElse: () => <String, dynamic>{});
              final String? mySelectedId = mySelection?['evidenceId'] as String?;

              return Column(
                children: [
                  const SizedBox(height: 16),
                  Text('公開証拠を1つ選択してください（他の人と重複不可）',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // 証拠リスト表示
                  Expanded(
                    child: ListView.builder(
                      itemCount: evidences.length,
                      itemBuilder: (context, idx) {
                        final ev = evidences[idx];
                        // 他の人が既に選択しているかどうか
                        final isSelectedByOther = selectedEvidenceIds.contains(ev['id']) && mySelectedId != ev['id'];
                        // 自分が選択した証拠かどうか
                        final isMine = mySelectedId == ev['id'];
                        return Card(
                          color: isMine ? Colors.lightBlue[50] : null,
                          child: ListTile(
                            title: Text(ev['title'] ?? '', style: TextStyle(fontWeight: isMine ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text(ev['description'] ?? ''),
                            trailing: isSelectedByOther
                                ? Text('選択済: ${whoSelected[ev['id']]}', style: const TextStyle(color: Colors.grey))
                                : isMine
                                    ? const Icon(Icons.check_circle, color: Colors.blue)
                                    : null,
                            // 他の人が選択済み or 選択中は押せない
                            enabled: !isSelectedByOther && !submitting && mySelectedId == null,
                            onTap: (!isSelectedByOther && !submitting && mySelectedId == null)
                                ? () => _selectEvidence(ev['id'])
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  // 自分が選択した証拠の詳細表示
                  if (mySelectedId != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('あなたが選択した証拠:'),
                          Text(
                            evidences.firstWhere((ev) => ev['id'] == mySelectedId)['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evidences.firstWhere((ev) => ev['id'] == mySelectedId)['description'] ?? '',
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}