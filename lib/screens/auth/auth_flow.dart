import 'package:flutter/material.dart';

import '../../core/referral.dart';
import 'unified_auth_screen.dart';

class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key, this.initialReferral});

  final ReferralInput? initialReferral;

  @override
  Widget build(BuildContext context) {
    return UnifiedAuthScreen(initialReferral: initialReferral);
  }
}
