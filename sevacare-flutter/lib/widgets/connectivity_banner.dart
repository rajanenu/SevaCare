import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';

/// Thin animated banner that appears at the top of content when offline.
/// Disappears automatically when connectivity is restored.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.maybeWhen(
      data: (online) => !online,
      orElse: () => false,
    );

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState:
          isOffline ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.errorSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: context.colors.danger.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 15, color: context.colors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No internet connection — showing cached data',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.colors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}
