import 'package:flutter/material.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
