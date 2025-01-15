import 'package:flutter/material.dart';
import 'package:flutter_application_1/FivePage.dart';

class FourPage extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(4)")
      ),
      body : Center(
        child: TextButton(
          child: Text("5ページへ遷移する"),
          // （5)ページ目に遷移する
          onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context) => FivePage()));
          },
        ),
      )
    );
  }
}