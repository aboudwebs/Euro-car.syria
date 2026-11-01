// Signed-out area: switches between sign-in and registration without a Navigator, and sends the Android back
// button from registration to the sign-in screen.

import 'package:flutter/material.dart';

import '../../core/referral.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key, this.initialReferral});

  final ReferralInput? initialReferral;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _registering = widget.initialReferral?.isSigned ?? false;
  }

  @override
  void didUpdateWidget(covariant AuthFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialReferral?.isSigned == true && oldWidget.initialReferral != widget.initialReferral) {
      _show(registering: true);
    }
  }

  void _show({required bool registering}) {
    setState(() => _registering = registering);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_registering,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _show(registering: false);
        }
      },
      child: _registering
          ? RegisterScreen(key: const ValueKey<String>('register'), onBack: () => _show(registering: false), initialReferral: widget.initialReferral)
          : LoginScreen(key: const ValueKey<String>('login'), onRegister: () => _show(registering: true)),
    );
  }
}
