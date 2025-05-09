import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pişir - Ana Sayfa")),
      body: Center(child: Text("Tarif Önerileri Burada")),
    );
  }
}