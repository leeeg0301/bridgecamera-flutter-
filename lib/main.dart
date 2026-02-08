import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const BridgeCameraApp());
}

class BridgeCameraApp extends StatelessWidget {
  const BridgeCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '점검도우미',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
