import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/login_screen.dart';
import 'package:flutter_application_1/mock/screens/launch_screen.dart'; // LaunchPage をインポート
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void connectToEmulators() {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  connectToEmulators(); // ← ここを追加
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'マーダーミステリー登録',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple.shade900,
          secondary: Colors.amber.shade700,
          background: const Color(0xFF22171C),
          surface: const Color(0xFF2C2227),
        ),
        fontFamily: 'Merriweather',
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'ミステリーハウス 〜ユーザー登録〜'),
    );
  }
}

// アカウント登録処理(メールアドレス&パスワード)
Future createAccount(String email, String passWord) async {
  FirebaseAuth auth = FirebaseAuth.instance;
  await auth.createUserWithEmailAndPassword(
    email: email,
    password: passWord,
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _email = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景画像
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景画像: 薄暗い館 or レトロな紙テクスチャ
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/mystery_bg.jpg'), // あなたの画像パスに合わせて変更
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.7),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 12,
                    color: Colors.black.withOpacity(0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Colors.amber.shade700,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // タイトル
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 28,
                              fontFamily: 'Merriweather',
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  color: Colors.deepPurple.shade900,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ようこそ、闇に包まれた館へ…',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // メール欄
                          TextFormField(
                            style: TextStyle(color: Colors.amber.shade200),
                            decoration: InputDecoration(
                              labelText: 'メールアドレス',
                              labelStyle: TextStyle(color: Colors.amber.shade700),
                              fillColor: Colors.deepPurple.shade900.withOpacity(0.4),
                              filled: true,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.amber.shade700),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.email, color: Colors.amber.shade700),
                            ),
                            onChanged: (String value) {
                              setState(() {
                                _email = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          // パスワード欄
                          TextFormField(
                            style: TextStyle(color: Colors.amber.shade200),
                            decoration: InputDecoration(
                              labelText: 'パスワード',
                              labelStyle: TextStyle(color: Colors.amber.shade700),
                              fillColor: Colors.deepPurple.shade900.withOpacity(0.4),
                              filled: true,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.amber.shade700),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.lock, color: Colors.amber.shade700),
                            ),
                            obscureText: true,
                            onChanged: (String value) {
                              setState(() {
                                _password = value;
                              });
                            },
                          ),
                          const SizedBox(height: 28),
                          // 登録ボタン
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.fingerprint, color: Colors.amber.shade700),
                              label: const Text('ユーザ登録'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade900,
                                foregroundColor: Colors.amber.shade200,
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 6,
                                shadowColor: Colors.amber.shade700,
                              ),
                              onPressed: () async {
                                try {
                                  final User? user = (await FirebaseAuth.instance
                                          .createUserWithEmailAndPassword(
                                              email: _email, password: _password))
                                      .user;
                                  if (user != null) {
                                    print("ユーザ登録しました ${user.email} , ${user.uid}");
                                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                      'email': user.email!,
                                      'createdAt': Timestamp.now(),
                                    });
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("エラー: ${e.toString()}")),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ログインボタン
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.vpn_key, color: Colors.amber.shade700),
                              label: const Text('ログイン'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amber.shade200,
                                side: BorderSide(color: Colors.amber.shade700, width: 2),
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.deepPurple.shade700.withOpacity(0.6),
                              ),
                              onPressed: () async {
                                try {
                                  final User? user = (await FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                              email: _email, password: _password))
                                      .user;
                                  if (user != null) {
                                    print("ログインしました ${user.email} , ${user.uid}");
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LaunchScreen()),
                                    );
                                  }
                                } catch (e) {
                                  print(e);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("ログインに失敗しました: ${e.toString()}")),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          Divider(
                            color: Colors.amber.shade700.withOpacity(0.4),
                            thickness: 1.5,
                          ),
                          const SizedBox(height: 6),
                          // フッター
                          Text(
                            "この館では、真実は一つだけ——\nあなたの選択が運命を変える。",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}