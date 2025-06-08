/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/foundation.dart';

/// A simple logger utility class for the Guardian app
class Logger {
  /// Log levels
  static const int _levelVerbose = 0;
  static const int _levelDebug = 1;
  static const int _levelInfo = 2;
  static const int _levelWarning = 3;
  static const int _levelError = 4;

  /// Current log level
  static int _currentLevel = kDebugMode ? _levelVerbose : _levelInfo;

  /// Set the current log level
  static void setLogLevel(int level) {
    _currentLevel = level;
  }

  /// Log a verbose message
  static void verbose(String message) {
    if (_currentLevel <= _levelVerbose) {
      debugPrint('🔍 VERBOSE: $message');
    }
  }

  /// Log a debug message
  static void debug(String message) {
    if (_currentLevel <= _levelDebug) {
      debugPrint('🐞 DEBUG: $message');
    }
  }

  /// Log an info message
  static void info(String message) {
    if (_currentLevel <= _levelInfo) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log a warning message
  static void warning(String message) {
    if (_currentLevel <= _levelWarning) {
      debugPrint('⚠️ WARNING: $message');
    }
  }

  /// Log an error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_currentLevel <= _levelError) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
}
