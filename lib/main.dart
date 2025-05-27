// lib/main.dart
import 'package:flutter/material.dart';
import 'package:persona/screens/home.dart';
import 'package:provider/provider.dart';

import 'activity_track.dart';
import 'audio.dart';
import 'ml_serviece.dart';
import 'model/model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final mlService = MLService();
  await mlService.initialize();

  final audioService = AudioService(mlService: mlService);
  final activityTracker = ActivityTracker();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProfile()),
        Provider.value(value: audioService),
        Provider.value(value: activityTracker),
        Provider.value(value: mlService),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persona',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}