import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Any synchronous pre-flight configuration runs here (e.g. SharedPreferences, Sqflite init)
  
  runApp(
    const ProviderScope(
      child: SplitEaseApp(),
    ),
  );
}
