import 'dart:math' as math;
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Advanced step detection algorithm using signal processing techniques
/// Implements peak detection, frequency analysis, and pattern recognition
class StepDetectionAlgorithm {
  // Signal processing parameters
  static const int _bufferSize = 25; // Reduced buffer size for faster response
  static const double _noiseThreshold = 0.3; // Reduced noise threshold for more sensitivity
  static const double _stepThreshold = 1.0; // Reduced step threshold for better detection
  static const int _minPeakDistance = 5; // Reduced minimum distance for faster detection
  static const double _lowPassAlpha = 0.15; // Increased for more responsive filtering

  // Peak detection state
  final Queue<AccelerometerSample> _sampleBuffer = Queue<AccelerometerSample>();
  final Queue<double> _magnitudeBuffer = Queue<double>();
  final Queue<double> _filteredBuffer = Queue<double>();
  
  // Peak tracking
  final List<Peak> _recentPeaks = [];
  double _lastFilteredValue = 0.0;
  int _lastPeakIndex = 0;

  // Step pattern validation
  final List<int> _stepIntervals = [];
  static const int _maxIntervalHistory = 10;

  // Callback for detected steps
  void Function(int timestamp, double confidence)? onStepDetected;

  /// Process new accelerometer data
  void processAccelerometerData(double x, double y, double z, int timestamp) {
    final sample = AccelerometerSample(x, y, z, timestamp);
    _addSample(sample);
    
    // Calculate magnitude
    final magnitude = math.sqrt(x * x + y * y + z * z);
    _addMagnitude(magnitude);
    
    // Apply low-pass filter
    final filtered = _applyLowPassFilter(magnitude);
    _addFilteredValue(filtered);
    
    // Detect peaks in filtered signal
    _detectPeaks();
    
    // Validate step patterns
    _validateStepPattern();
  }

  /// Add sample to buffer
  void _addSample(AccelerometerSample sample) {
    _sampleBuffer.add(sample);
    if (_sampleBuffer.length > _bufferSize) {
      _sampleBuffer.removeFirst();
    }
  }

  /// Add magnitude to buffer
  void _addMagnitude(double magnitude) {
    _magnitudeBuffer.add(magnitude);
    if (_magnitudeBuffer.length > _bufferSize) {
      _magnitudeBuffer.removeFirst();
    }
  }

  /// Apply low-pass filter to reduce noise
  double _applyLowPassFilter(double newValue) {
    _lastFilteredValue = _lastFilteredValue + _lowPassAlpha * (newValue - _lastFilteredValue);
    return _lastFilteredValue;
  }

  /// Add filtered value to buffer
  void _addFilteredValue(double filtered) {
    _filteredBuffer.add(filtered);
    if (_filteredBuffer.length > _bufferSize) {
      _filteredBuffer.removeFirst();
    }
  }

  /// Detect peaks in the filtered signal
  void _detectPeaks() {
    if (_filteredBuffer.length < 3) return;

    final buffer = _filteredBuffer.toList();
    final currentIndex = buffer.length - 2; // Check the second-to-last value
    
    // Skip if too close to last detected peak
    if (currentIndex - _lastPeakIndex < _minPeakDistance) return;

    final current = buffer[currentIndex];
    final previous = buffer[currentIndex - 1];
    final next = buffer[currentIndex + 1];

    // Check if current value is a local maximum
    if (current > previous && current > next && current > _stepThreshold) {
      // Calculate peak prominence (difference from surrounding valleys)
      final prominence = _calculatePeakProminence(buffer, currentIndex);
      
      if (prominence > _noiseThreshold) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final peak = Peak(
          index: currentIndex,
          value: current,
          prominence: prominence,
          timestamp: timestamp,
        );
        
        _addPeak(peak);
        _lastPeakIndex = currentIndex;
      }
    }
  }

  /// Calculate peak prominence to distinguish from noise
  double _calculatePeakProminence(List<double> buffer, int peakIndex) {
    final peakValue = buffer[peakIndex];
    
    // Find the minimum values on both sides of the peak
    double leftMin = peakValue;
    double rightMin = peakValue;
    
    // Look left
    for (int i = peakIndex - 1; i >= 0 && i >= peakIndex - 10; i--) {
      leftMin = math.min(leftMin, buffer[i]);
    }
    
    // Look right
    for (int i = peakIndex + 1; i < buffer.length && i <= peakIndex + 10; i++) {
      rightMin = math.min(rightMin, buffer[i]);
    }
    
    // Prominence is the minimum difference from either side
    return peakValue - math.max(leftMin, rightMin);
  }

  /// Add peak to recent peaks list
  void _addPeak(Peak peak) {
    _recentPeaks.add(peak);
    
    // Keep only recent peaks (last 5 seconds worth)
    final cutoffTime = peak.timestamp - 5000;
    _recentPeaks.removeWhere((p) => p.timestamp < cutoffTime);
    
    if (kDebugMode) {
      print('🔍 Peak detected: ${peak.value.toStringAsFixed(2)} (prominence: ${peak.prominence.toStringAsFixed(2)})');
    }
  }

  /// Validate step pattern from recent peaks
  void _validateStepPattern() {
    if (_recentPeaks.length < 2) return;

    final latestPeak = _recentPeaks.last;
    final previousPeak = _recentPeaks[_recentPeaks.length - 2];
    
    final interval = latestPeak.timestamp - previousPeak.timestamp;
    
    // Validate interval (corresponds to reasonable step cadence)
    if (interval >= 250 && interval <= 1500) { // 40-240 spm range
      _addStepInterval(interval);
      
      // Calculate confidence based on pattern consistency
      final confidence = _calculateStepConfidence(latestPeak, interval);
      
      if (confidence > 0.4) { // Reduced from 60% to 40% for faster response
        onStepDetected?.call(latestPeak.timestamp, confidence);
      }
    }
  }

  /// Add step interval to history for pattern analysis
  void _addStepInterval(int interval) {
    _stepIntervals.add(interval);
    if (_stepIntervals.length > _maxIntervalHistory) {
      _stepIntervals.removeAt(0);
    }
  }

  /// Calculate step confidence based on multiple factors
  double _calculateStepConfidence(Peak peak, int interval) {
    double confidence = 0.0;
    
    // Factor 1: Peak prominence (30% weight)
    final prominenceScore = math.min(peak.prominence / 2.0, 1.0);
    confidence += prominenceScore * 0.3;
    
    // Factor 2: Interval consistency (40% weight)
    final intervalScore = _calculateIntervalConsistency(interval);
    confidence += intervalScore * 0.4;
    
    // Factor 3: Peak value (20% weight)
    final valueScore = math.min((peak.value - _stepThreshold) / 2.0, 1.0);
    confidence += valueScore * 0.2;
    
    // Factor 4: Pattern regularity (10% weight)
    final patternScore = _calculatePatternRegularity();
    confidence += patternScore * 0.1;
    
    return math.min(confidence, 1.0);
  }

  /// Calculate how consistent the current interval is with recent intervals
  double _calculateIntervalConsistency(int currentInterval) {
    if (_stepIntervals.length < 3) return 0.5; // Neutral score
    
    final recentIntervals = _stepIntervals.length > 5 
        ? _stepIntervals.sublist(_stepIntervals.length - 5) 
        : _stepIntervals;
    final avgInterval = recentIntervals.reduce((a, b) => a + b) / recentIntervals.length;
    
    // Calculate standard deviation
    double variance = 0;
    for (final interval in recentIntervals) {
      variance += math.pow(interval - avgInterval, 2);
    }
    final stdDev = math.sqrt(variance / recentIntervals.length);
    
    // Score based on how close current interval is to the average
    final deviation = (currentInterval - avgInterval).abs();
    final normalizedDeviation = stdDev > 0 ? deviation / stdDev : 0.0;
    
    // Return high score for consistent intervals
    return math.max(0.0, 1.0 - normalizedDeviation / 2.0);
  }

  /// Calculate pattern regularity score
  double _calculatePatternRegularity() {
    if (_recentPeaks.length < 4) return 0.5;
    
    final peaks = _recentPeaks.length > 4 
        ? _recentPeaks.sublist(_recentPeaks.length - 4) 
        : _recentPeaks;
    final intervals = <int>[];
    
    for (int i = 1; i < peaks.length; i++) {
      intervals.add(peaks[i].timestamp - peaks[i-1].timestamp);
    }
    
    if (intervals.isEmpty) return 0.5;
    
    // Calculate coefficient of variation
    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
    double variance = 0;
    for (final interval in intervals) {
      variance += math.pow(interval - avg, 2);
    }
    final stdDev = math.sqrt(variance / intervals.length);
    final cv = avg > 0 ? stdDev / avg : 1.0;
    
    // Lower coefficient of variation = more regular pattern
    return math.max(0.0, 1.0 - cv);
  }

  /// Get current algorithm state for debugging
  AlgorithmState getState() {
    return AlgorithmState(
      bufferSize: _sampleBuffer.length,
      recentPeaks: _recentPeaks.length,
      averageInterval: _stepIntervals.isNotEmpty 
          ? _stepIntervals.reduce((a, b) => a + b) / _stepIntervals.length 
          : 0.0,
      lastFilteredValue: _lastFilteredValue,
    );
  }

  /// Reset algorithm state
  void reset() {
    _sampleBuffer.clear();
    _magnitudeBuffer.clear();
    _filteredBuffer.clear();
    _recentPeaks.clear();
    _stepIntervals.clear();
    _lastFilteredValue = 0.0;
    _lastPeakIndex = 0;
  }

  /// Dispose of resources
  void dispose() {
    reset();
    onStepDetected = null;
  }
}

/// Accelerometer sample data
class AccelerometerSample {
  final double x, y, z;
  final int timestamp;

  AccelerometerSample(this.x, this.y, this.z, this.timestamp);

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

/// Peak data for step detection
class Peak {
  final int index;
  final double value;
  final double prominence;
  final int timestamp;

  Peak({
    required this.index,
    required this.value,
    required this.prominence,
    required this.timestamp,
  });
}

/// Algorithm state for monitoring
class AlgorithmState {
  final int bufferSize;
  final int recentPeaks;
  final double averageInterval;
  final double lastFilteredValue;

  AlgorithmState({
    required this.bufferSize,
    required this.recentPeaks,
    required this.averageInterval,
    required this.lastFilteredValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'buffer_size': bufferSize,
      'recent_peaks': recentPeaks,
      'average_interval_ms': averageInterval,
      'last_filtered_value': lastFilteredValue,
    };
  }
}
