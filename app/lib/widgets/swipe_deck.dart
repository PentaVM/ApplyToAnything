import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/job.dart';
import 'job_card.dart';

enum SwipeDir { left, right, up }

/// Permite disparar swipes programáticos desde los botones.
class SwipeDeckController {
  _SwipeDeckState? _state;

  void swipe(SwipeDir dir) => _state?._trigger(dir);

  void _attach(_SwipeDeckState state) => _state = state;
  void _detach(_SwipeDeckState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// Mazo de tarjetas estilo Tinder:
///  · arrastra a la derecha → postular  (verde, "APLICAR")
///  · arrastra a la izquierda → descartar (rosa, "PASO")
///  · arrastra hacia arriba → guardar (violeta, "GUARDAR")
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.jobs,
    required this.controller,
    required this.onDecide,
  });

  final List<Job> jobs;
  final SwipeDeckController controller;
  final void Function(Job job, SwipeDir dir) onDecide;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  SwipeDir? _flying;
  Offset _exitFrom = Offset.zero;
  Offset _exitTo = Offset.zero;

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_flying == null) _drag = Offset.zero;
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _exit.dispose();
    super.dispose();
  }

  bool get _busy => _flying != null || widget.jobs.isEmpty;

  void _trigger(SwipeDir dir) {
    if (_busy || !mounted) return;
    final size = MediaQuery.of(context).size;
    _exitFrom = _drag;
    switch (dir) {
      case SwipeDir.left:
        _exitTo = Offset(-size.width * 1.3, _drag.dy - 60);
      case SwipeDir.right:
        _exitTo = Offset(size.width * 1.3, _drag.dy - 60);
      case SwipeDir.up:
        _exitTo = Offset(_drag.dx * 0.4, -size.height);
    }
    setState(() => _flying = dir);
    _exit.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      final job = widget.jobs.first;
      widget.onDecide(job, dir);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_busy) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_busy) return;
    final v = d.velocity.pixelsPerSecond;
    if (_drag.dx > 110 || v.dx > 700) {
      _trigger(SwipeDir.right);
      return;
    }
    if (_drag.dx < -110 || v.dx < -700) {
      _trigger(SwipeDir.left);
      return;
    }
    if (_drag.dy < -130 || v.dy < -800) {
      _trigger(SwipeDir.up);
      return;
    }
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = widget.jobs;
    if (jobs.isEmpty) return const _EmptyDeck();

    return Stack(
      children: [
        // Tarjetas de abajo (efecto pila)
        for (var i = math.min(2, jobs.length - 1); i >= 1; i--)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, -14.0 * i),
              child: Transform.scale(
                scale: 1 - 0.05 * i,
                child: IgnorePointer(child: JobCard(job: jobs[i])),
              ),
            ),
          ),
        // Tarjeta superior arrastrable
        Positioned.fill(
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: _exit,
              builder: (context, _) {
                final Offset off;
                if (_flying != null) {
                  off = Offset.lerp(_exitFrom, _exitTo,
                          Curves.easeOutCubic.transform(_exit.value))!;
                } else {
                  off = _drag;
                }
                final rot = (off.dx / 24).clamp(-0.45, 0.45).toDouble();
                final likeOp = (off.dx / 90).clamp(0.0, 1.0).toDouble();
                final nopeOp = (-off.dx / 90).clamp(0.0, 1.0).toDouble();
                final upOp = (-off.dy / 110).clamp(0.0, 1.0).toDouble();

                return Transform.translate(
                  offset: off,
                  child: Transform.rotate(
                    angle: rot,
                    child: Stack(
                      children: [
                        JobCard(job: jobs.first, top: true),
                        _Stamp(
                          label: 'APLICAR',
                          color: AppTheme.green,
                          icon: Icons.check_rounded,
                          rotation: -0.3,
                          alignment: Alignment.topLeft,
                          opacity: likeOp,
                        ),
                        _Stamp(
                          label: 'PASO',
                          color: AppTheme.accent,
                          icon: Icons.close_rounded,
                          rotation: 0.3,
                          alignment: Alignment.topRight,
                          opacity: nopeOp,
                        ),
                        _Stamp(
                          label: 'GUARDAR',
                          color: AppTheme.accent2,
                          icon: Icons.star_rounded,
                          rotation: 0,
                          alignment: Alignment.topCenter,
                          opacity: upOp,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.icon,
    required this.rotation,
    required this.alignment,
    required this.opacity,
  });

  final String label;
  final Color color;
  final IconData icon;
  final double rotation;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.all(28),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(14),
              color: Colors.black38,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore_rounded, size: 72, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No hay más ofertas en el mazo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Pulsa «Cargar más ofertas» o ajusta los filtros.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
