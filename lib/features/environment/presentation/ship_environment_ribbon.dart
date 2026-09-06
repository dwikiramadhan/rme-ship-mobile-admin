import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'environment_controller.dart';

/// Full-width top ribbon displaying the active ship/vessel environment
/// the user is currently logged into.
class ShipEnvironmentRibbon extends ConsumerWidget {
  const ShipEnvironmentRibbon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envState = ref.watch(activeEnvironmentProvider);
    final env = envState.valueOrNull;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0F2537), // Dark Maritime Navy
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF0284C7).withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Ship / Anchor Icon with glowing background
          Container(
            padding: const EdgeInsets.all(4.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              LucideIcons.ship,
              size: 13,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 9),

          // 2. Label & Ship Name
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'KAPAL:',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF94A3B8),
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    env != null
                        ? env.name
                        : (envState.isLoading
                            ? 'Memuat data kapal...'
                            : 'Kapal Belum Dikonfigurasi'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
                if (env != null && env.code.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  // Code Badge Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0369A1).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      env.code,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFFE0F2FE),
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Online/Status indicator & Refresh Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Terhubung',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF34D399),
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    ref.read(activeEnvironmentProvider.notifier).refresh(),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    LucideIcons.refreshCw,
                    size: 11.5,
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
