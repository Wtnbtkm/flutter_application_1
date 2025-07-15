import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/problem_list_screen.dart';
import 'package:flutter_application_1/mock/screens/player_registration_screen.dart';
import 'package:flutter_application_1/mock/screens/settings_screen.dart';
import 'package:flutter_application_1/mock/screens/launch_screen.dart';
import 'package:flutter_application_1/mock/screens/login_screen.dart';
//ホーム画面の実装
// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Widget mysteryButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: ElevatedButton.icon(
        icon: icon != null
            ? Icon(icon, color: mmAccent)
            : const SizedBox.shrink(),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: mmCard,
          foregroundColor: Colors.white,
          elevation: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: mmAccent, width: 2.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        leading: const Icon(Icons.menu_book, color: mmAccent),
        title: Text(
          'Mystery Home',
          style: const TextStyle(
            fontFamily: mmFont,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: mmAccent, blurRadius: 3)],
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // マーダーミステリー風タイトル
                  Text(
                    'ようこそ、事件の舞台へ',
                    style: const TextStyle(
                      fontFamily: mmFont,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: mmAccent,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(2,2)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '— ホーム画面 —',
                    style: const TextStyle(
                      fontFamily: mmFont,
                      fontSize: 18,
                      color: Colors.white70,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 34),
                  // ボタン郡
                  mysteryButton(
                    text: '起動画面へ',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LaunchScreen()),
                      );
                    },
                    icon: Icons.flash_on,
                  ),
                  mysteryButton(
                    text: '問題一覧へ',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProblemListScreen()),
                      );
                    },
                    icon: Icons.list_alt,
                  ),
                  mysteryButton(
                    text: '設定画面へ',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                    icon: Icons.settings,
                  ),
                  mysteryButton(
                    text: 'ログイン画面へ',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    icon: Icons.lock_open,
                  ),
                  mysteryButton(
                    text: 'プレイヤー名の登録',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlayerRegistrationScreen()),
                      );
                    },
                    icon: Icons.person_add,
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: Text(
                      '「真実」を暴く覚悟はできているか…？',
                      style: const TextStyle(
                        fontFamily: mmFont,
                        fontStyle: FontStyle.italic,
                        color: Colors.white38,
                        fontSize: 15,
                        letterSpacing: 1.5,
                        shadows: [Shadow(color: mmAccent, blurRadius: 2)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}