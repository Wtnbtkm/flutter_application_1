import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/room_creation_screen.dart'; // ルーム作成画面
import 'package:flutter_application_1/mock/screens/room_join_screen.dart';   // ルーム参加画面

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

//ルームの選択画面
class RoomChoiceScreen extends StatelessWidget {
  final String problemTitle;
  final int requiredPlayers;
  final String problemId;

  const RoomChoiceScreen({
    Key? key,
    required this.problemTitle,
    required this.requiredPlayers,
    required this.problemId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        leading: const Icon(Icons.door_front_door, color: mmAccent),
        title: Text(
          'ルーム選択',
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: mmAccent, blurRadius: 3)],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: mmCard.withOpacity(0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: mmAccent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(2, 7),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.meeting_room, color: mmAccent, size: 46),
                const SizedBox(height: 10),
                Text(
                  '事件ファイル',
                  style: const TextStyle(
                    fontFamily: mmFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: mmAccent,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  problemTitle,
                  style: const TextStyle(
                    fontFamily: mmFont,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '必要人数: $requiredPlayers 人',
                  style: const TextStyle(
                    fontFamily: mmFont,
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_box, color: Colors.white),
                        label: Text(
                          'ルームを作成',
                          style: const TextStyle(
                            fontFamily: mmFont,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mmAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(color: Colors.black, width: 1),
                          ),
                          elevation: 6,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomCreationScreen(
                                problemTitle: problemTitle,
                                requiredPlayers: requiredPlayers,
                                problemId: problemId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.group, color: Colors.white),
                        label: Text(
                          'ルームに参加',
                          style: const TextStyle(
                            fontFamily: mmFont,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mmCard,
                          foregroundColor: mmAccent,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: mmAccent, width: 2),
                          ),
                          elevation: 6,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomJoinScreen(
                                problemTitle: problemTitle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}