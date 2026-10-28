// The "active:scale-[0.97]" press feedback of the web app's buttons: the control shrinks a little while a finger
// is on it. A Listener is used, so it never takes part in the gesture arena and does not change tap behaviour.

import 'package:flutter/material.dart';

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) {
      setState(() => _down = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) => _set(true),
      onPointerUp: (PointerUpEvent event) => _set(false),
      onPointerCancel: (PointerCancelEvent event) => _set(false),
      child: AnimatedScale(
        scale: _down && widget.enabled ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
