import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Simple brand mark: a rounded navy tile with the TCB monogram. Acts as a
/// placeholder until a real logo asset is supplied.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 64, this.showLabel = true});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          alignment: Alignment.center,
          child: Text(
            'TCB',
            style: TextStyle(
              color: AppColors.canvas,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: AppDimens.md),
          Text(
            'Employee Portal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}
