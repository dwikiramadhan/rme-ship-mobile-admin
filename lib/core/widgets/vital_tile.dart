import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Port of the prototype's `VitalItem` — a compact icon + label + value tile
/// used in the 2-column vitals grid.
class VitalTile extends StatelessWidget {
  const VitalTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w800, fontFamily: 'PlusJakartaSans'),
                    children: [
                      TextSpan(text: value),
                      TextSpan(text: ' $unit', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
