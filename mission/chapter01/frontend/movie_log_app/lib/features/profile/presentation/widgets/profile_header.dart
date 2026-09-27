import 'package:flutter/material.dart';
import 'package:movie_log_app/core/theme/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 256,
          height: 256,
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Color(0xFFD2B8FF),
            shape: BoxShape.circle,
          ),
          child: const CircleAvatar(
            backgroundColor: Color(0xFF35313D),
            backgroundImage: NetworkImage(
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330'
              '?auto=format&fit=crop&w=600&q=85',
            ),
          ),
        ),
        const SizedBox(height: 34),
        const Text(
          '무비러버',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 42,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은\n영화를 보고 기록하는 것을 좋아합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF56515D),
            fontSize: 25,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 48),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 50,
              vertical: 18,
            ),
          ),
          child: const Text(
            '프로필 수정',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
