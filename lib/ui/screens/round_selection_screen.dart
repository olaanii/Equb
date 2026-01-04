import 'dart:math';

import 'package:equb/models/equb_model.dart';
import 'package:equb/services/toast_service.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoundSelectionScreen extends ConsumerStatefulWidget {
  final EqubGroup group;

  const RoundSelectionScreen({super.key, required this.group});

  @override
  ConsumerState<RoundSelectionScreen> createState() =>
      _RoundSelectionScreenState();
}

class _RoundSelectionScreenState extends ConsumerState<RoundSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String? _winner;
  bool _isSpinning = false;
  bool _showWinner = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
          _showWinner = true;
          _determineWinner();
        });
      }
    });
  }

  void _determineWinner() {
    // Basic logic to pick a random winner or next in line
    // In a real app, this should be determined by the backend or robust logic
    final members = widget.group.members;
    if (widget.group.payoutStrategy == PayoutStrategy.fixedOrder) {
      // Just pick the next one based on round index if possible, else random for demo
      _winner = members.isNotEmpty ? members.first : 'Unknown';
    } else {
      _winner = members[Random().nextInt(members.length)];
    }
  }

  void _startSpin() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _showWinner = false;
    });

    // Spin 5 times + random angle
    final randomAngle = Random().nextDouble() * 2 * pi;
    _animation = Tween<double>(
      begin: 0,
      end: 5 * 2 * pi + randomAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Round Selection', style: theme.textTheme.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_showWinner) ...[
              Text(
                'Spin to pick a winner!',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: size.width * 0.8,
                height: size.width * 0.8,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final value =
                        _controller.isAnimating ? _animation.value : 0.0;
                    return Transform.rotate(
                      angle: value,
                      child: CustomPaint(
                        painter: _WheelPainter(
                          items: widget.group.members,
                          colors: [
                            theme.colorScheme.primary,
                            theme.cardTheme.color ?? Colors.grey,
                            theme.colorScheme.secondary,
                            Colors.orangeAccent,
                            Colors.lightBlueAccent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 60),
              PrimaryButton(
                text: _isSpinning ? 'Spinning...' : 'Start Spin',
                onPressed: _startSpin, // Disable if spinning?
                // icon: Icons.refresh,
              ),
            ] else ...[
              _buildWinnerReveal(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerReveal(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.amber),
          const SizedBox(height: 24),
          Text('Congratulations!', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(
            _winner ?? 'Winner',
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: 'Complete Round',
            onPressed: () {
              ToastService.success(context, 'Round completed! Wallet updated.');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> items;
  final List<Color> colors;

  _WheelPainter({required this.items, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (items.isEmpty) return;

    final sweepAngle = 2 * pi / items.length;

    for (int i = 0; i < items.length; i++) {
      final paint =
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.fill;

      canvas.drawArc(rect, i * sweepAngle, sweepAngle, true, paint);

      // Draw text (simplified)
      // Save canvas, rotate, draw text, restore
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sweepAngle + sweepAngle / 2);

      final textSpan = TextSpan(
        text:
            items[i].length > 10 ? '${items[i].substring(0, 8)}...' : items[i],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position text slightly out from center
      textPainter.paint(canvas, Offset(radius * 0.4, -textPainter.height / 2));

      canvas.restore();
    }

    // Draw outer border
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw center pin
    final centerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
