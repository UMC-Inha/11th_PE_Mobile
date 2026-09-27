import 'package:flutter/material.dart';
import 'package:movie_log_app/core/theme/app_colors.dart';
import 'package:movie_log_app/features/profile/presentation/widgets/genre_chip.dart';
import 'package:movie_log_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:movie_log_app/features/profile/presentation/widgets/stat_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 110,
        title: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text('내 프로필'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 44, 32, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileHeader(),
              const SizedBox(height: 54),
              Row(
                children: const [
                  Expanded(child: StatItem(label: '본 영화', value: '342')),
                  SizedBox(width: 16),
                  Expanded(child: StatItem(label: '평점', value: '4.2')),
                  SizedBox(width: 16),
                  Expanded(child: StatItem(label: '즐겨찾기', value: '58')),
                ],
              ),
              const SizedBox(height: 70),
              const Text(
                '선호하는 장르',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: const [
                  GenreChip(label: '드라마'),
                  GenreChip(label: 'SF'),
                  GenreChip(label: '애니메이션'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
