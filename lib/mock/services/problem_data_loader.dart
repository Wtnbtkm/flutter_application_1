// 問題IDに応じて配役・証拠・ストーリーなどを取得するクラス（例）
class ProblemDataLoader {
  static Future<Map<String, dynamic>> loadProblem(String problemId) async {
    // FirestoreやローカルJSONからロードする実装例
    // return await Firestore.instance.collection('problems').doc(problemId).get();
    // or rootBundle.loadString('assets/problems/$problemId.json');
    throw UnimplementedError();
  }
}