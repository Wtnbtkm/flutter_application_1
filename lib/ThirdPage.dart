import 'package:flutter/material.dart';
import 'package:flutter_application_1/FourPage.dart';

class ThirdPage extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(3)")
      ),
      body : Center(
        child: TextButton(
          child: Text("4ページへ遷移する"),
          // （4)ページ目に遷移する
          onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context) => FourPage()));
          },
        ),
      )
    );
  }
}