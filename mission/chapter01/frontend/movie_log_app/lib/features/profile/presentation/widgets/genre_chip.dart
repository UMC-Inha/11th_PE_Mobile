import 'package:flutter/material.dart';
import 'package:movie_log_app/core/theme/app_colors.dart';

class GenreChip extends StatelessWidget {
  const GenreChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5B4298),
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
