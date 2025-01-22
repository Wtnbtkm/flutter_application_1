import 'package:flutter/material.dart';

// カスタマイズ可能なボタン
class CustomButton extends StatelessWidget {
  final String text; // ボタンに表示するテキスト
  final VoidCallback onPressed; // ボタンが押されたときの動作
  final Color? backgroundColor; // 背景色（オプション）
  final Color? textColor; // テキストの色（オプション）
  final double? borderRadius; // ボタンの角丸（オプション）
  final EdgeInsetsGeometry? padding; // ボタン内の余白（オプション）

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.blue, // デフォルト色
    this.textColor = Colors.white, // デフォルト色
    this.borderRadius = 16.0, // デフォルトの角丸
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // デフォルトの余白
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor, // 背景色
        padding: padding, // 余白
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius!), // 角丸の形状
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor, // テキストの色
          fontSize: 16, // フォントサイズ
          fontWeight: FontWeight.bold, // フォントの太さ
        ),
      ),
    );
  }
}
