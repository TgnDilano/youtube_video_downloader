import 'package:flutter/material.dart';
import 'package:ytdlapp/ui/app_theme.dart';
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
      title: 'Tubemate',
      theme: buildTubemateTheme(context),
      home: const TubemateClone(),
    );
  }
}
