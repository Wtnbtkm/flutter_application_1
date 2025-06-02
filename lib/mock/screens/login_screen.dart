import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/launch_screen.dart';

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
      appBar: AppBar(title: const Text('ログイン画面')),
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // メールアドレス入力
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => setState(() => _email = value),
                  ),
                  const SizedBox(height: 16),

                  // パスワード入力
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: (value) => setState(() => _password = value),
                  ),
                  const SizedBox(height: 32),

                  // ログインボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('ログイン'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('パスワードリセット'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                      icon: const Icon(Icons.logout),
                      label: const Text('ログアウト'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        await _auth.signOut();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ログアウトしました')),
                        );
                      },
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