import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalvoNoteApp());
}

class CalvoNoteApp extends StatelessWidget {
  const CalvoNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalvoNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: FutureBuilder<void>(
        future: SettingsService.instance.init(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
