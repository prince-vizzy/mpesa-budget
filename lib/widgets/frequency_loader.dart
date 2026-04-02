import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrequencyLoader extends StatefulWidget {
  final int bars;
  final double height;

  const FrequencyLoader({
    super.key,
    this.bars = 12,
    this.height = 28,
  });

  @override
  State<FrequencyLoader> createState() => _FrequencyLoaderState();
}

class _FrequencyLoaderState extends State<FrequencyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.bars, (i) {
            final phase = (_controller.value * 2 * pi) + (i * 0.45);
            final amp = (sin(phase) + 1) / 2;
            final barHeight = 4 + (widget.height - 4) * amp;
            return Container(
              width: 3,
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: i.isEven
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.45),
              ),
            );
          }),
        );
      },
    );
  }
}
