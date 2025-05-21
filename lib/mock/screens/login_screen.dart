import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ログイン画面', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),

            TextFormField(
              decoration: const InputDecoration(labelText: 'メールアドレス'),
              onChanged: (value) => setState(() => _email = value),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
              onChanged: (value) => setState(() => _password = value),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              child: const Text('ログイン'),
              onPressed: () async {
                try {
                  await _auth.signInWithEmailAndPassword(
                    email: _email,
                    password: _password,
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ログイン失敗: ${e.toString()}')),
                  );
                }
              },
            ),

            ElevatedButton(
              child: const Text('パスワードリセット'),
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

            ElevatedButton(
              child: const Text('ログアウト'),
              onPressed: () async {
                await _auth.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ログアウトしました')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
