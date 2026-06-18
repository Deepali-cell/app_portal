import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/brand_wordmark.dart';
import '../application/auth_controller.dart';
import '../application/lock_controller.dart';

/// Biometric gate shown once per session when a stored session is restored.
/// If the device has no biometrics, it unlocks automatically.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    final biometrics = ref.read(biometricServiceProvider);
    if (!await biometrics.isAvailable()) {
      _unlock();
      return;
    }
    setState(() => _checking = true);
    final ok = await biometrics.authenticate(reason: 'Unlock TCB Portal');
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() => _checking = false);
    }
  }

  void _unlock() {
    if (!mounted) return;
    ref.read(sessionUnlockedProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const BrandWordmark(size: 72, showLabel: false),
              const SizedBox(height: AppDimens.xxl),
              Icon(Icons.fingerprint, size: 56, color: AppColors.navy),
              const SizedBox(height: AppDimens.lg),
              Text(
                'Locked',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Verify it\'s you to continue',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              if (_checking)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppDimens.xl),
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else ...[
                BrandButton(
                  label: 'Unlock',
                  icon: Icons.lock_open_outlined,
                  onPressed: _attempt,
                ),
                const SizedBox(height: AppDimens.md),
                TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Sign out instead'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
