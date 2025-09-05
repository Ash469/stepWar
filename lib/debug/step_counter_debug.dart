import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import '../services/step_tracking_service.dart';

class StepCounterDebug {
  static Future<void> runDiagnostics() async {
    if (!kDebugMode) return;
    
    print("🔍 ===== STEP COUNTER DIAGNOSTICS =====");
    
    // 1. Check all permissions
    await _checkPermissions();
    
    // 2. Test pedometer plugin directly
    await _testPedometerPlugin();
    
    // 3. Test step tracking service
    await _testStepTrackingService();
    
    print("🔍 ===== DIAGNOSTICS COMPLETE =====");
  }
  
  static Future<void> _checkPermissions() async {
    print("🔐 Checking permissions...");
    
    final permissions = [
      Permission.sensors,
      Permission.activityRecognition,
      Permission.notification,
    ];
    
    for (final permission in permissions) {
      final status = await permission.status;
      final name = permission.toString().split('.').last;
      print("  📋 $name: $status");
      
      if (status != PermissionStatus.granted) {
        print("    ⚠️  Not granted - requesting...");
        final newStatus = await permission.request();
        print("    📋 After request: $newStatus");
      }
    }
  }
  
  static Future<void> _testPedometerPlugin() async {
    print("🚶 Testing pedometer plugin directly...");
    
    try {
      StreamSubscription<StepCount>? testSub;
      int stepCount = 0;
      
      testSub = Pedometer.stepCountStream.listen(
        (StepCount event) {
          stepCount++;
          print("  📈 Pedometer event #$stepCount:");
          print("    Steps: ${event.steps}");
          print("    Timestamp: ${event.timeStamp}");
        },
        onError: (error) {
          print("  ❌ Pedometer error: $error");
        },
      );
      
      // Listen for 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      await testSub.cancel();
      
      if (stepCount == 0) {
        print("  ⚠️  No pedometer events received in 10 seconds");
        print("    This could indicate:");
        print("    - Missing permissions");
        print("    - Plugin not working");
        print("    - Device not moving");
      } else {
        print("  ✅ Pedometer plugin working - received $stepCount events");
      }
      
    } catch (e) {
      print("  ❌ Failed to test pedometer plugin: $e");
    }
  }
  
  static Future<void> _testStepTrackingService() async {
    print("⚙️ Testing step tracking service...");
    
    try {
      final service = StepTrackingService();
      
      // Initialize
      final initialized = await service.initialize();
      print("  📋 Initialized: $initialized");
      
      if (initialized) {
        print("  📊 Current steps:");
        print("    Daily: ${service.dailySteps}");
        print("    Total: ${service.totalSteps}");
        print("    Session: ${service.sessionSteps}");
        
        // Start tracking
        await service.startTracking();
        print("  ✅ Tracking started");
        
        // Listen to step stream for 5 seconds
        StreamSubscription? streamSub;
        int streamEvents = 0;
        
        streamSub = service.stepsStream.listen((steps) {
          streamEvents++;
          print("  📈 Step stream event #$streamEvents: $steps steps");
        });
        
        await Future.delayed(const Duration(seconds: 5));
        await streamSub.cancel();
        
        if (streamEvents == 0) {
          print("  ⚠️  No step stream events received");
        } else {
          print("  ✅ Step stream working - $streamEvents events");
        }
        
        service.dispose();
      } else {
        print("  ❌ Failed to initialize step tracking service");
      }
      
    } catch (e) {
      print("  ❌ Failed to test step tracking service: $e");
    }
  }
  
  /// Run a simple step test - manually add steps and verify
  static Future<void> runStepTest() async {
    if (!kDebugMode) return;
    
    print("🧪 ===== MANUAL STEP TEST =====");
    
    final service = StepTrackingService();
    
    try {
      final initialized = await service.initialize();
      
      if (initialized) {
        print("📊 Before test:");
        print("  Daily: ${service.dailySteps}");
        print("  Total: ${service.totalSteps}");
        
        // Manually add some test steps
        service.addSteps(10, source: 'test');
        print("➕ Added 10 test steps");
        
        print("📊 After test:");
        print("  Daily: ${service.dailySteps}");
        print("  Total: ${service.totalSteps}");
        
        // Test step stream
        StreamSubscription? streamSub;
        streamSub = service.stepsStream.listen((steps) {
          print("📈 Step stream updated: $steps steps");
        });
        
        await Future.delayed(const Duration(seconds: 1));
        await streamSub.cancel();
        
        print("✅ Manual step test completed");
      } else {
        print("❌ Cannot run step test - initialization failed");
      }
    } catch (e) {
      print("❌ Step test failed: $e");
    }
    
    print("🧪 ===== STEP TEST COMPLETE =====");
  }
  
  /// Check device capabilities
  static Future<void> checkDeviceCapabilities() async {
    if (!kDebugMode) return;
    
    print("📱 ===== DEVICE CAPABILITIES =====");
    
    // This is a basic check - more detailed checks would require platform-specific code
    try {
      print("🔋 Testing if pedometer stream is available...");
      
      final completer = Completer<bool>();
      StreamSubscription<StepCount>? testSub;
      
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      testSub = Pedometer.stepCountStream.listen(
        (event) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            print("  ❌ Pedometer error: $error");
            completer.complete(false);
          }
        },
      );
      
      final available = await completer.future;
      await testSub.cancel();
      
      if (available) {
        print("  ✅ Device supports step counting");
      } else {
        print("  ❌ Device may not support step counting or permissions missing");
      }
      
    } catch (e) {
      print("  ❌ Error checking device capabilities: $e");
    }
    
    print("📱 ===== CAPABILITY CHECK COMPLETE =====");
  }
}
