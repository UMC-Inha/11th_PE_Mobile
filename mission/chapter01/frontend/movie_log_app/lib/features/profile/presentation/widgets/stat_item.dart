import 'package:flutter/material.dart';

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 172,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5D6FF), width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF56515D),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF51358E),
              fontSize: 42,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
