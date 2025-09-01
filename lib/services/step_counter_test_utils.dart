import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'production_step_counter.dart';
import 'step_analytics_service.dart';

/// Test and validation utilities for the production step counter
/// Provides tools for tuning parameters and validating accuracy
class StepCounterTestUtils {
  static final StepCounterTestUtils _instance = StepCounterTestUtils._internal();
  factory StepCounterTestUtils() => _instance;
  StepCounterTestUtils._internal();

  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  final StepAnalyticsService _analytics = StepAnalyticsService();
  
  // Test session tracking
  bool _testSessionActive = false;
  int _testSessionStartTime = 0;
  int _expectedSteps = 0;
  int _actualSteps = 0;

  // Simulation parameters
  static const double _simulationFrequency = 50.0; // Hz
  Timer? _simulationTimer;

  /// Start a test session with expected step count
  Future<void> startTestSession({required int expectedSteps}) async {
    if (_testSessionActive) {
      throw StateError('Test session already active');
    }

    _testSessionActive = true;
    _testSessionStartTime = DateTime.now().millisecondsSinceEpoch;
    _expectedSteps = expectedSteps;
    _actualSteps = _stepCounter.dailySteps;

    _analytics.initialize();
    await _stepCounter.initialize();
    await _stepCounter.startTracking();

    // Listen to step events
    _stepCounter.stepsStream.listen((steps) {
      if (_testSessionActive) {
        _actualSteps = steps;
      }
    });

    if (kDebugMode) {
      print('🧪 Test session started - Expected: $_expectedSteps steps');
    }
  }

  /// End test session and return results
  TestSessionResult endTestSession() {
    if (!_testSessionActive) {
      throw StateError('No active test session');
    }

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = endTime - _testSessionStartTime;
    final finalSteps = _stepCounter.dailySteps;
    final stepsCounted = finalSteps - (_actualSteps - _expectedSteps);

    _testSessionActive = false;
    _simulationTimer?.cancel();

    final result = TestSessionResult(
      expectedSteps: _expectedSteps,
      actualSteps: stepsCounted,
      duration: duration,
      accuracy: _expectedSteps > 0 ? stepsCounted / _expectedSteps : 0.0,
      analyticsReport: _analytics.getReport(),
      counterMetrics: _stepCounter.getMetrics(),
    );

    if (kDebugMode) {
      print('🧪 Test session completed:');
      print('   Expected: ${_expectedSteps}');
      print('   Actual: $stepsCounted');
      print('   Accuracy: ${(result.accuracy * 100).toStringAsFixed(1)}%');
      print('   Duration: ${(duration / 1000).toStringAsFixed(1)}s');
    }

    return result;
  }

  /// Simulate walking with realistic accelerometer data
  void simulateWalking({
    required int steps,
    double cadence = 120.0, // steps per minute
    double intensity = 1.0, // 0.5 = light walk, 1.0 = normal, 1.5 = brisk
  }) {
    if (!_testSessionActive) {
      throw StateError('Start a test session first');
    }

    final stepInterval = 60000 / cadence; // milliseconds between steps
    final samplesPerStep = (_simulationFrequency * stepInterval / 1000).round();
    
    int stepCount = 0;
    int sampleCount = 0;

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _simulationFrequency).round()),
      (timer) {
        if (stepCount >= steps) {
          timer.cancel();
          return;
        }

        // Generate realistic walking pattern
        final stepPhase = (sampleCount % samplesPerStep) / samplesPerStep;
        final walkingSignal = _generateWalkingSignal(stepPhase, intensity);

        // Add some noise
        final noise = (math.Random().nextDouble() - 0.5) * 0.2;
        final x = walkingSignal.x + noise;
        final y = walkingSignal.y + noise;
        final z = walkingSignal.z + noise;

        // Inject the simulated data
        _stepCounter.debugInjectAccelerometerData(x, y, z);

        sampleCount++;
        if (sampleCount >= samplesPerStep) {
          stepCount++;
          sampleCount = 0;
        }
      },
    );

    if (kDebugMode) {
      print('🚶 Simulating $steps steps at ${cadence.toStringAsFixed(1)} spm');
    }
  }

  /// Simulate non-walking activities (false positive tests)
  void simulateNonWalkingActivity(NonWalkingActivity activity, int durationSeconds) {
    if (!_testSessionActive) {
      throw StateError('Start a test session first');
    }

    _simulationTimer?.cancel();

    final samples = (_simulationFrequency * durationSeconds).round();
    int sampleCount = 0;

    _simulationTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _simulationFrequency).round()),
      (timer) {
        if (sampleCount >= samples) {
          timer.cancel();
          return;
        }

        final signal = _generateNonWalkingSignal(activity, sampleCount);
        _stepCounter.debugInjectAccelerometerData(signal.x, signal.y, signal.z);
        
        sampleCount++;
      },
    );

    if (kDebugMode) {
      print('🎭 Simulating ${activity.name} for ${durationSeconds}s');
    }
  }

  /// Generate realistic walking accelerometer signal
  AccelerometerSignal _generateWalkingSignal(double phase, double intensity) {
    // Typical walking creates a sinusoidal pattern with harmonics
    final primaryFreq = 2 * math.pi * phase;
    final harmonicFreq = 4 * math.pi * phase;
    
    // Y-axis (vertical) shows the strongest walking signal
    final y = 9.8 + intensity * (
      1.5 * math.sin(primaryFreq) + 
      0.3 * math.sin(harmonicFreq)
    );
    
    // X and Z axes show secondary movement
    final x = intensity * (
      0.8 * math.sin(primaryFreq + math.pi / 4) +
      0.2 * math.sin(harmonicFreq + math.pi / 3)
    );
    
    final z = intensity * (
      0.6 * math.cos(primaryFreq) +
      0.15 * math.cos(harmonicFreq + math.pi / 6)
    );

    return AccelerometerSignal(x, y, z);
  }

  /// Generate non-walking activity signals for false positive testing
  AccelerometerSignal _generateNonWalkingSignal(NonWalkingActivity activity, int sampleIndex) {
    final random = math.Random(sampleIndex); // Deterministic for reproducible tests
    
    switch (activity) {
      case NonWalkingActivity.handShaking:
        // High frequency, low amplitude movements
        final freq = 2 * math.pi * sampleIndex * 8 / _simulationFrequency;
        return AccelerometerSignal(
          2.0 * math.sin(freq) * (random.nextDouble() + 0.5),
          9.8 + 0.5 * math.cos(freq) * (random.nextDouble() + 0.5),
          0.8 * math.sin(freq * 1.3) * (random.nextDouble() + 0.5),
        );

      case NonWalkingActivity.carDriving:
        // Low frequency vibrations with occasional bumps
        final baseVibration = 0.1 * math.sin(2 * math.pi * sampleIndex * 15 / _simulationFrequency);
        final bump = sampleIndex % 200 == 0 ? random.nextDouble() * 2.0 : 0.0;
        return AccelerometerSignal(
          baseVibration + bump * (random.nextDouble() - 0.5),
          9.8 + baseVibration + bump,
          baseVibration + bump * (random.nextDouble() - 0.5),
        );

      case NonWalkingActivity.phoneInPocket:
        // Random small movements
        return AccelerometerSignal(
          (random.nextDouble() - 0.5) * 0.3,
          9.8 + (random.nextDouble() - 0.5) * 0.2,
          (random.nextDouble() - 0.5) * 0.3,
        );

      case NonWalkingActivity.sitting:
        // Very minimal movement
        return AccelerometerSignal(
          (random.nextDouble() - 0.5) * 0.05,
          9.8 + (random.nextDouble() - 0.5) * 0.05,
          (random.nextDouble() - 0.5) * 0.05,
        );
    }
  }

  /// Run comprehensive accuracy tests
  Future<List<TestSessionResult>> runAccuracyTestSuite() async {
    final results = <TestSessionResult>[];

    // Test different walking speeds
    final walkingTests = [
      (steps: 50, cadence: 80.0, name: 'slow_walk'),
      (steps: 100, cadence: 120.0, name: 'normal_walk'),
      (steps: 75, cadence: 160.0, name: 'brisk_walk'),
      (steps: 50, cadence: 200.0, name: 'fast_walk'),
    ];

    for (final test in walkingTests) {
      await startTestSession(expectedSteps: test.steps);
      simulateWalking(steps: test.steps, cadence: test.cadence);
      
      // Wait for simulation to complete
      await Future.delayed(Duration(seconds: (test.steps * 60 / test.cadence + 2).round()));
      
      final result = endTestSession();
      result.testName = test.name;
      results.add(result);
      
      // Brief pause between tests
      await Future.delayed(const Duration(seconds: 2));
    }

    return results;
  }

  /// Run false positive tests
  Future<List<TestSessionResult>> runFalsePositiveTestSuite() async {
    final results = <TestSessionResult>[];

    final falsePositiveTests = [
      (activity: NonWalkingActivity.handShaking, duration: 30, name: 'hand_shaking'),
      (activity: NonWalkingActivity.carDriving, duration: 60, name: 'car_driving'),
      (activity: NonWalkingActivity.phoneInPocket, duration: 45, name: 'pocket_movement'),
      (activity: NonWalkingActivity.sitting, duration: 30, name: 'sitting'),
    ];

    for (final test in falsePositiveTests) {
      await startTestSession(expectedSteps: 0); // Expect no steps
      simulateNonWalkingActivity(test.activity, test.duration);
      
      // Wait for simulation to complete
      await Future.delayed(Duration(seconds: test.duration + 2));
      
      final result = endTestSession();
      result.testName = test.name;
      results.add(result);
      
      // Brief pause between tests
      await Future.delayed(const Duration(seconds: 2));
    }

    return results;
  }

  /// Generate comprehensive test report
  String generateTestReport(List<TestSessionResult> results) {
    if (results.isEmpty) return 'No test results available';

    final buffer = StringBuffer();
    buffer.writeln('StepWars Production Step Counter - Test Report');
    buffer.writeln('=' * 50);
    buffer.writeln();

    double totalAccuracy = 0.0;
    int accuracyTests = 0;
    int falsePositives = 0;

    for (final result in results) {
      buffer.writeln('Test: ${result.testName ?? 'Unknown'}');
      buffer.writeln('Expected Steps: ${result.expectedSteps}');
      buffer.writeln('Actual Steps: ${result.actualSteps}');
      buffer.writeln('Accuracy: ${(result.accuracy * 100).toStringAsFixed(1)}%');
      buffer.writeln('Duration: ${(result.duration / 1000).toStringAsFixed(1)}s');
      
      if (result.expectedSteps > 0) {
        totalAccuracy += result.accuracy;
        accuracyTests++;
      } else if (result.actualSteps > 0) {
        falsePositives += result.actualSteps;
      }
      
      // Analytics breakdown
      buffer.writeln('Rejection Breakdown:');
      result.analyticsReport.rejectionBreakdown.forEach((filter, count) {
        buffer.writeln('  $filter: $count');
      });
      buffer.writeln();
    }

    // Summary
    buffer.writeln('SUMMARY');
    buffer.writeln('-' * 20);
    if (accuracyTests > 0) {
      buffer.writeln('Average Accuracy: ${(totalAccuracy / accuracyTests * 100).toStringAsFixed(1)}%');
    }
    buffer.writeln('Total False Positives: $falsePositives');
    buffer.writeln('Tests Completed: ${results.length}');

    return buffer.toString();
  }

  /// Dispose of test utilities
  void dispose() {
    _simulationTimer?.cancel();
    _testSessionActive = false;
  }
}

/// Test session result data
class TestSessionResult {
  final int expectedSteps;
  final int actualSteps;
  final int duration; // milliseconds
  final double accuracy; // 0.0 to 1.0+
  final AnalyticsReport analyticsReport;
  final StepCounterMetrics counterMetrics;
  String? testName;

  TestSessionResult({
    required this.expectedSteps,
    required this.actualSteps,
    required this.duration,
    required this.accuracy,
    required this.analyticsReport,
    required this.counterMetrics,
    this.testName,
  });

  Map<String, dynamic> toJson() {
    return {
      'test_name': testName,
      'expected_steps': expectedSteps,
      'actual_steps': actualSteps,
      'duration_ms': duration,
      'accuracy': accuracy,
      'analytics': analyticsReport.toJson(),
      'metrics': counterMetrics.toJson(),
    };
  }
}

/// Non-walking activities for false positive testing
enum NonWalkingActivity {
  handShaking,
  carDriving,
  phoneInPocket,
  sitting,
}

/// Accelerometer signal data
class AccelerometerSignal {
  final double x, y, z;
  
  AccelerometerSignal(this.x, this.y, this.z);
}
