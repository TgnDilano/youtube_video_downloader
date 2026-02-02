import 'package:flutter/material.dart';
import 'package:ytdlapp/ui/home_page.dart';

void main() {
  runApp(const TubemateApp());
}

class TubemateApp extends StatelessWidget {
  const TubemateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const TubemateClone(),
    );
  }
}
