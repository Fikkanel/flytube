import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service wrapper for Android Picture-in-Picture mode.
/// Communicates with native Android via MethodChannel.
class PipService {
  static const _channel = MethodChannel('id.fikkan.flytube/pip');
  
  final _pipStateController = StreamController<bool>.broadcast();
  
  /// Stream that emits true when entering PiP, false when exiting.
  Stream<bool> get onPipChanged => _pipStateController.stream;
  
  bool _isInPip = false;
  bool get isInPip => _isInPip;

  PipService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onPipChanged') {
      final isInPip = call.arguments['isInPip'] as bool;
      _isInPip = isInPip;
      _pipStateController.add(isInPip);
      debugPrint('PiP state changed: $isInPip');
    }
  }

  /// Enter Picture-in-Picture mode. Returns true if successful.
  Future<bool> enterPip() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to enter PiP: $e');
      return false;
    }
  }

  /// Check if the device supports Picture-in-Picture (Android 8.0+).
  Future<bool> isPipSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPipSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check PiP support: $e');
      return false;
    }
  }

  /// Check if currently in PiP mode.
  Future<bool> isPipActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPipActive');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Tell native Android whether to auto-enter PiP when user presses home.
  Future<void> setShouldEnterPip(bool enabled) async {
    try {
      await _channel.invokeMethod('setShouldEnterPip', {'enabled': enabled});
    } catch (e) {
      debugPrint('Failed to set PiP flag: $e');
    }
  }

  void dispose() {
    _pipStateController.close();
  }
}
