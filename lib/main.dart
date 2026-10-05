import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PodiumApp());
}

class PodiumApp extends StatelessWidget {
  const PodiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Podium',
      debugShowCheckedModeBanner: false,
      theme: buildPodiumTheme(),
      home: const AuthGate(),
    );
  }
}
