/// Stub for non-web platforms.
/// WebRTC JS test screen is only supported on web.
library;

import 'package:flutter/material.dart';

class WebRTCJsTestScreen extends StatelessWidget {
  const WebRTCJsTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('WebRTC JS Test is only available on web.')),
    );
  }
}
