import 'package:flutter/material.dart';
import 'package:flutter_application_1/mock/screens/home_screen.dart';
import 'package:flutter_application_1/mock/widgets/custom_button.dart';
//起動画面
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景画像を全体に表示
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/036b6f93-9ccf-4934-90bd-cca91f62e000.png', // ミステリー風の背景画像を用意してください
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.6), // 暗めのフィルターを追加
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'マーダーミステリー',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4.0,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'ホーム画面',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                backgroundColor: Colors.deepPurple.shade900,
                textColor: Colors.white,
                borderRadius: 20.0,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}