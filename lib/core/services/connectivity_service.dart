/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:guardian/core/utils/logger.dart';

/// Connection status enum
enum ConnectionStatus {
  online,
  offline,
}

/// A service for managing connectivity and offline mode
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  ConnectionStatus _status = ConnectionStatus.online;
  bool _offlineModeEnabled = false;

  /// Get current connection status
  ConnectionStatus get status => _status;

  /// Check if device is online
  bool get isOnline => _status == ConnectionStatus.online;

  /// Check if device is offline
  bool get isOffline => _status == ConnectionStatus.offline;

  /// Check if offline mode is enabled
  bool get isOfflineModeEnabled => _offlineModeEnabled;

  /// Initialize connectivity service
  void init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.isNotEmpty) {
          _updateConnectionStatus(results.first);
        } else {
          _updateConnectionStatus(ConnectivityResult.none);
        }
      },
    );
    _checkConnectivity();
    Logger.info('Connectivity service initialized');
  }

  /// Dispose connectivity service
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
    Logger.info('Connectivity service disposed');
  }

  /// Check current connectivity
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isNotEmpty) {
        _updateConnectionStatus(results.first);
      } else {
        _updateConnectionStatus(ConnectivityResult.none);
      }
    } catch (e) {
      Logger.error('Error checking connectivity', e);
      _status = ConnectionStatus.offline;
      notifyListeners();
    }
  }

  /// Update connection status
  void _updateConnectionStatus(ConnectivityResult result) {
    final oldStatus = _status;

    if (result == ConnectivityResult.none) {
      _status = ConnectionStatus.offline;
    } else {
      _status = ConnectionStatus.online;
    }

    if (oldStatus != _status) {
      Logger.info('Connection status changed: $_status');
      notifyListeners();
    }
  }

  /// Enable offline mode
  void enableOfflineMode() {
    if (!_offlineModeEnabled) {
      _offlineModeEnabled = true;
      Logger.info('Offline mode enabled');
      notifyListeners();
    }
  }

  /// Disable offline mode
  void disableOfflineMode() {
    if (_offlineModeEnabled) {
      _offlineModeEnabled = false;
      Logger.info('Offline mode disabled');
      notifyListeners();
    }
  }

  /// Toggle offline mode
  void toggleOfflineMode() {
    _offlineModeEnabled = !_offlineModeEnabled;
    Logger.info('Offline mode toggled: $_offlineModeEnabled');
    notifyListeners();
  }

  /// Check if app should use offline data
  bool shouldUseOfflineData() {
    return isOffline || isOfflineModeEnabled;
  }
}
