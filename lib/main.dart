import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forcer l'orientation portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Couleur de la barre de statut Android
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const CalvoNoteApp());
}

class CalvoNoteApp extends StatelessWidget {
  const CalvoNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'CalvoNote',
      debugShowCheckedModeBanner: false,
      theme:        AppTheme.dark,
      home:         const HomeScreen(),
    );
  }
}
