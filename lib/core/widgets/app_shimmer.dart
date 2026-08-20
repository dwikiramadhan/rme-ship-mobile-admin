import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Smooth, looping shimmer effect controller and wrapper.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.1, 0.5, 0.9],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Generic rounded rectangle box for skeleton loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Single skeleton item representing a master list row.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 38, height: 38, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBox(width: 140, height: 13, borderRadius: 4),
                const SizedBox(height: 6),
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: 10,
                  borderRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 64, height: 22, borderRadius: 12),
        ],
      ),
    );
  }
}

/// A full list of shimmering skeleton items.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: padding ?? const EdgeInsets.all(12),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => const SkeletonListTile(),
      ),
    );
  }
}

/// Shimmering placeholder for patient detail view matching the 4 clinical cards.
class SkeletonPatientDetail extends StatelessWidget {
  const SkeletonPatientDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: Identitas Pasien
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonBox(width: 48, height: 48, borderRadius: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SkeletonBox(width: 160, height: 16, borderRadius: 4),
                              SizedBox(height: 6),
                              SkeletonBox(width: 220, height: 12, borderRadius: 4),
                            ],
                          ),
                        ),
                        const SkeletonBox(width: 54, height: 26, borderRadius: 8),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        SkeletonBox(width: 120, height: 24, borderRadius: 8),
                        SkeletonBox(width: 130, height: 24, borderRadius: 8),
                        SkeletonBox(width: 140, height: 24, borderRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),

            // Card 2: Keluhan Awal
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      SkeletonBox(width: 27, height: 27, borderRadius: 8),
                      SizedBox(width: 8),
                      SkeletonBox(width: 110, height: 13, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 120, height: 10, borderRadius: 3),
                        SizedBox(height: 6),
                        SkeletonBox(height: 14, borderRadius: 4),
                        SizedBox(height: 4),
                        SkeletonBox(width: 180, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      SkeletonBox(width: 110, height: 24, borderRadius: 8),
                      SkeletonBox(width: 130, height: 24, borderRadius: 8),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),

            // Card 3: Tanda Vital
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      SkeletonBox(width: 27, height: 27, borderRadius: 8),
                      SizedBox(width: 8),
                      SkeletonBox(width: 95, height: 13, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 11),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final int crossAxisCount = w >= 700
                          ? 5
                          : (w >= 440 ? 3 : 2);
                      final double childAspectRatio = w >= 700
                          ? 2.1
                          : (w >= 440 ? 2.6 : 2.5);
                      return GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: childAspectRatio,
                        children: List.generate(
                          5,
                          (_) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.card2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const SkeletonBox(width: 34, height: 34, borderRadius: 8),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SkeletonBox(width: 48, height: 9, borderRadius: 2),
                                      SizedBox(height: 4),
                                      SkeletonBox(width: 70, height: 14, borderRadius: 3),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),

            // Card 4: Diagnosa & Resep
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
                          SkeletonBox(width: 27, height: 27, borderRadius: 8),
                          SizedBox(width: 8),
                          SkeletonBox(width: 170, height: 13, borderRadius: 4),
                        ],
                      ),
                      SkeletonBox(width: 80, height: 22, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 100, height: 10, borderRadius: 3),
                        SizedBox(height: 6),
                        SkeletonBox(width: 200, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SkeletonBox(width: 90, height: 13, borderRadius: 3),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const SkeletonBox(width: 23, height: 23, borderRadius: 7),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonBox(width: 130, height: 13, borderRadius: 3),
                              SizedBox(height: 4),
                              SkeletonBox(width: 90, height: 10, borderRadius: 3),
                            ],
                          ),
                        ),
                        const SkeletonBox(width: 42, height: 18, borderRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
