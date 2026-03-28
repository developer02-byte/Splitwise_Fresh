import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URL strategy so /login works instead of /#/login
  usePathUrlStrategy();

  runApp(
    const ProviderScope(
      child: SplitEaseApp(),
    ),
  );
}
