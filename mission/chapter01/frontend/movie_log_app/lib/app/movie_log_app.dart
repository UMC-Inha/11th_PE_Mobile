import 'package:flutter/material.dart';
import 'package:movie_log_app/core/theme/app_colors.dart';
import 'package:movie_log_app/features/profile/presentation/profile_screen.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      home: const ProfileScreen(),
    );
  }
}
