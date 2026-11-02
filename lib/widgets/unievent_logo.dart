import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ticket-with-star logo drawn with CustomPaint so it needs no asset.
class UniEventLogo extends StatelessWidget {
  const UniEventLogo({
    super.key,
    this.size = 96,
    this.onDark = true,
  });

  final double size;

  /// When true the tile is white and the ticket uses the brand gradient
  /// (for gradient backgrounds). When false the tile uses the gradient and
  /// the ticket is white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'UniEvent logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onDark ? AppColors.white : null,
          gradient: onDark ? null : AppColors.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: size * 0.2,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: CustomPaint(painter: _TicketStarPainter(onDark: onDark)),
      ),
    );
  }
}

class _TicketStarPainter extends CustomPainter {
  _TicketStarPainter({required this.onDark});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ticketRect = Rect.fromLTWH(w * 0.17, h * 0.3, w * 0.66, h * 0.4);

    final ticketPaint = Paint()..style = PaintingStyle.fill;
    if (onDark) {
      ticketPaint.shader = AppColors.brandGradient.createShader(ticketRect);
    } else {
      ticketPaint.color = AppColors.white;
    }

    final ticket = Path()
      ..addRRect(
        RRect.fromRectAndRadius(ticketRect, Radius.circular(w * 0.07)),
      );
    final notchRadius = w * 0.06;
    final notches = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(ticketRect.left, ticketRect.center.dy),
          radius: notchRadius,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(ticketRect.right, ticketRect.center.dy),
          radius: notchRadius,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, ticket, notches),
      ticketPaint,
    );

    // Perforation line.
    final dashPaint = Paint()
      ..color = onDark ? AppColors.white : AppColors.indigo
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dashX = ticketRect.left + ticketRect.width * 0.68;
    var y = ticketRect.top + h * 0.03;
    while (y < ticketRect.bottom - h * 0.03) {
      canvas.drawLine(
        Offset(dashX, y),
        Offset(dashX, y + h * 0.035),
        dashPaint,
      );
      y += h * 0.07;
    }

    // Star.
    final starCenter = Offset(
      ticketRect.left + ticketRect.width * 0.34,
      ticketRect.center.dy,
    );
    final starPaint = Paint()
      ..color = onDark ? AppColors.white : AppColors.orange;
    canvas.drawPath(_star(starCenter, w * 0.12, w * 0.05), starPaint);
  }

  Path _star(Offset c, double outer, double inner) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final angle = (i * math.pi / points) - math.pi / 2;
      final p = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _TicketStarPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}
