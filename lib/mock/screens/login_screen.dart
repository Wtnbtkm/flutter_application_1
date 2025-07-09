import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/launch_screen.dart';

// マーダーミステリー用カラーパレットとフォント
const Color mmBackground = Color(0xFF1C1B2F);
const Color mmCard = Color(0xFF292845);
const Color mmAccent = Color(0xFFE84A5F);
const String mmFont = 'MurderMysteryFont'; // assets/fontsに追加＆pubspec.yamlに登録想定

// ログイン画面
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _email = '';
  String _password = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mmBackground,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 7,
        shadowColor: mmAccent.withOpacity(0.4),
        centerTitle: true,
        leading: const Icon(Icons.person_pin, color: mmAccent),
        title: Text(
          'Mystery Login',
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // タイトル
                  Text(
                    'ログイン',
                    style: const TextStyle(
                      fontFamily: mmFont,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: mmAccent,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '— 事件現場への扉 —',
                    style: const TextStyle(
                      fontFamily: mmFont,
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // メールアドレス入力
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      labelStyle: const TextStyle(
                        fontFamily: mmFont,
                        color: mmAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: mmCard.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: mmAccent, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: mmAccent, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.email, color: mmAccent),
                    ),
                    style: const TextStyle(
                      fontFamily: mmFont,
                      color: Colors.white,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => setState(() => _email = value),
                  ),
                  const SizedBox(height: 16),

                  // パスワード入力
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      labelStyle: const TextStyle(
                        fontFamily: mmFont,
                        color: mmAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: mmCard.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: mmAccent, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: mmAccent, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: mmAccent),
                    ),
                    style: const TextStyle(
                      fontFamily: mmFont,
                      color: Colors.white,
                    ),
                    obscureText: true,
                    onChanged: (value) => setState(() => _password = value),
                  ),
                  const SizedBox(height: 32),

                  // ログインボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: Text(
                        'ログイン',
                        style: const TextStyle(
                          fontFamily: mmFont,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mmAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        elevation: 5,
                        shadowColor: mmAccent.withOpacity(0.4),
                      ),
                      onPressed: () async {
                        try {
                          await _auth.signInWithEmailAndPassword(
                            email: _email,
                            password: _password,
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LaunchScreen()),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ログイン失敗: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // パスワードリセットボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_reset, color: mmAccent),
                      label: Text(
                        'パスワードリセット',
                        style: const TextStyle(
                          fontFamily: mmFont,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: mmCard.withOpacity(0.5),
                        foregroundColor: mmAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: mmAccent, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        try {
                          await _auth.sendPasswordResetEmail(email: _email);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('リセットメールを送信しました')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ログアウトボタン
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white54),
                      label: Text(
                        'ログアウト',
                        style: const TextStyle(
                          fontFamily: mmFont,
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await _auth.signOut();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ログアウトしました')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}