import 'package:flutter/material.dart';
import 'package:flutter_application_1/list/CouponListItem.dart';

class CouponListView extends StatelessWidget{

  Function onPressed;
  CouponListView(this.onPressed);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        child: listViewBuilder()
    );
  }

  Widget buildListView(){
    return ListView(
      children: [
        CouponListItem(onPressed),
        CouponListItem(onPressed),
        CouponListItem(onPressed),
      ],
    );
  }


  //  データの個数に従って、表示する場合
  final items = [0,1,2,3,4,5,6];

  Widget listViewBuilder(){
    return ListView.builder(
      itemCount: items.length,
        itemBuilder: (BuildContext context, int index) {
          return CouponListItem(onPressed);
        }
    );
  }
}