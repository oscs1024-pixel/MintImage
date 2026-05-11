import 'package:flutter/material.dart';

import '../theme.dart';

class LoadingImageCell extends StatelessWidget {
  const LoadingImageCell({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppThemeTokens.surfaceSoft, AppThemeTokens.primarySoft],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
