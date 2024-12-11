import 'package:flutter/material.dart';
import 'package:flutter_application_1/SecondPage.dart';
class FirstPage extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(1)")
      ),
      body : Center(
        child: TextButton(
          child: Text("２ページ目に遷移する"),
          // （1） 前の画面に戻る
          onPressed: (){
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (context) => SecondPage()
            ));
          },
        ),
      )
    );
  }
}