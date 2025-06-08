/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:guardian/core/services/emergency_service.dart';
import 'package:guardian/core/utils/logger.dart';

/// A service for managing Bluetooth connections to safety devices
class BluetoothService {
  static BluetoothDevice? _connectedDevice;
  static bool _isScanning = false;
  static StreamSubscription? _scanSubscription;
  static StreamSubscription? _connectionSubscription;
  static StreamSubscription? _notificationSubscription;

  /// Get the currently connected device
  static BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Check if Bluetooth is available and enabled
  static Future<bool> isBluetoothReady() async {
    try {
      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        Logger.warning("Bluetooth is not supported on this device");
        return false;
      }

      // Check if Bluetooth is turned on
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        Logger.warning("Bluetooth is not turned on");
        return false;
      }

      return true;
    } catch (e) {
      Logger.error("Error checking Bluetooth status", e);
      return false;
    }
  }

  /// Start scanning for Bluetooth devices
  static Future<bool> startScan({int timeout = 10}) async {
    if (_isScanning) return true;

    try {
      // Check if Bluetooth is ready
      if (!await isBluetoothReady()) {
        return false;
      }

      // Start scanning
      _isScanning = true;

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          Logger.info('Device found: ${result.device.platformName} (${result.device.remoteId})');
        }
      });

      // Start the scan with timeout
      await FlutterBluePlus.startScan(timeout: Duration(seconds: timeout));

      return true;
    } catch (e) {
      Logger.error("Error starting Bluetooth scan", e);
      _isScanning = false;
      return false;
    }
  }

  /// Stop scanning for devices
  static Future<bool> stopScan() async {
    if (!_isScanning) return true;

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
      return true;
    } catch (e) {
      Logger.error("Error stopping Bluetooth scan", e);
      return false;
    }
  }

  /// Connect to a Bluetooth device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Connect to the device
      await device.connect();
      _connectedDevice = device;

      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionSubscription?.cancel();
          _notificationSubscription?.cancel();
          Logger.info("Device disconnected");
        }
      });

      Logger.info("Connected to device: ${device.platformName}");
      return true;
    } catch (e) {
      Logger.error("Error connecting to device", e);
      return false;
    }
  }

  /// Disconnect from the current device
  static Future<bool> disconnectFromDevice() async {
    if (_connectedDevice == null) return true;

    try {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionSubscription?.cancel();
      _notificationSubscription?.cancel();
      Logger.info("Disconnected from device");
      return true;
    } catch (e) {
      Logger.error("Error disconnecting from device", e);
      return false;
    }
  }

  /// Simulate connecting to a safety device
  /// This is a mock implementation for demonstration purposes
  static Future<bool> connectToSafetyDevice() async {
    Logger.info("Simulating connection to safety device");

    // In a real app, you would:
    // 1. Scan for devices
    // 2. Find your safety device by name or service UUID
    // 3. Connect to it
    // 4. Set up notifications for emergency triggers

    // For demo purposes, we'll just simulate a successful connection
    await Future.delayed(const Duration(seconds: 2));

    Logger.info("Connected to safety device (simulated)");
    return true;
  }

  /// Simulate triggering an emergency from a connected device
  /// This is a mock implementation for demonstration purposes
  static Future<void> simulateEmergencyTrigger() async {
    Logger.info("Simulating emergency trigger from device");

    // Trigger the emergency alert
    await EmergencyService.triggerEmergencyAlert();
  }

  /// Clean up resources
  static void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    disconnectFromDevice();
  }
}

