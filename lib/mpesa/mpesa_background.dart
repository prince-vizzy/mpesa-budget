import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/notification_service.dart';

const MethodChannel _backgroundChannel = MethodChannel('mpesa_background');

/// Entrypoint for the headless engine the native listener starts when an M-Pesa
/// notification arrives while the app UI is closed.
///
/// This isolate has no widget tree — it only parses, stores and notifies, using
/// exactly the same code path as the foreground app.
@pragma('vm:entry-point')
void mpesaBackgroundEntry() {
  WidgetsFlutterBinding.ensureInitialized();

  _backgroundChannel.setMethodCallHandler((call) async {
    if (call.method == 'process') {
      await _drain();
    }
  });

  // Tell the native side we are live, then pick up whatever is already queued.
  _backgroundChannel.invokeMethod('ready').whenComplete(_drain);
}

Future<void> _drain() async {
  try {
    await NotificationService.initializeHeadless();
    await NotificationService.drainAndProcess();
  } catch (e, stack) {
    debugPrint('mpesaBackgroundEntry error: $e\n$stack');
  } finally {
    // Native is holding a wake lock for this pass so the CPU can't doze
    // mid-processing — release it now that we are actually done, rather than
    // relying on its safety timeout every single time.
    try {
      await _backgroundChannel.invokeMethod('processingComplete');
    } catch (e) {
      debugPrint('mpesaBackgroundEntry processingComplete error: $e');
    }
  }
}
