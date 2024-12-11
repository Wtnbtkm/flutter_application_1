import 'package:flutter/material.dart';
import 'package:flutter_application_1/ThirdPage.dart';

class SecondPage extends StatelessWidget{
  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(2)")
      ),
      body : Center(
        child: TextButton(
          child: Text("3ページへ遷移する"),
          // （1） 前の画面に戻る
          onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context) => Thirdpage()));
          },
        ),
      )
    );
  }
}