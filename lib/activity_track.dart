// lib/services/activity_tracker.dart
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/activity_data.dart';
import 'dart:math';

class ActivityTracker {
  bool _isTracking = false;
  StreamSubscription? _accelerometerSubscription;
  final StreamController<ActivityData> _activityStreamController =
  StreamController<ActivityData>.broadcast();

  // Variables to track movement and patterns
  int _movementCounter = 0;
  double _movementIntensity = 0;
  DateTime? _lastMovementTime;
  final List<ActivityData> _activityHistory = [];

  Stream<ActivityData> get activityStream => _activityStreamController.stream;
  List<ActivityData> get activityHistory => List.unmodifiable(_activityHistory);

  Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;
    _lastMovementTime = DateTime.now();

    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _processMovement(event);
    });

    // Start periodic activity analysis
    Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }

      _analyzeActivityPeriod();
    });
  }

  void _processMovement(AccelerometerEvent event) {
    final now = DateTime.now();

    // Calculate movement magnitude
    final double magnitude = _calculateMagnitude(event.x, event.y, event.z);

    // If movement exceeds threshold, count it
    if (magnitude > 2.0) { // Adjust threshold as needed
      _movementCounter++;
      _movementIntensity += magnitude;
      _lastMovementTime = now;
    }
  }

  double _calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  void _analyzeActivityPeriod() {
    final now = DateTime.now();
    final timeSinceLastMove = _lastMovementTime != null
        ? now.difference(_lastMovementTime!)
        : Duration.zero;

    // Calculate average movement intensity
    final avgIntensity = _movementCounter > 0
        ? _movementIntensity / _movementCounter
        : 0.0;

    // Create activity data
    final activityData = ActivityData(
      timestamp: now,
      movementCount: _movementCounter,
      movementIntensity: avgIntensity,
      timeSinceLastMove: timeSinceLastMove,
    );

    // Add to history and broadcast
    _activityHistory.add(activityData);
    _activityStreamController.add(activityData);

    // Limit history size to avoid memory issues
    if (_activityHistory.length > 288) { // 24 hours at 5-minute intervals
      _activityHistory.removeAt(0);
    }

    // Reset counters for next period
    _movementCounter = 0;
    _movementIntensity = 0;
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  ActivityPrediction predictActivityLevel() {
    if (_activityHistory.length < 12) { // Need at least 1 hour of data
      return ActivityPrediction.unknown;
    }

    // Calculate average movement in recent periods
    final recentActivities = _activityHistory.sublist(
        _activityHistory.length - 12
    );

    final avgMovement = recentActivities.fold<double>(
        0, (sum, data) => sum + data.movementCount
    ) / recentActivities.length;

    if (avgMovement < 10) {
      return ActivityPrediction.low;
    } else if (avgMovement < 50) {
      return ActivityPrediction.moderate;
    } else {
      return ActivityPrediction.high;
    }
  }

  bool shouldSuggestBreak() {
    if (_activityHistory.length < 12) return false;

    // Get last hour of activity
    final recentActivities = _activityHistory.sublist(
        _activityHistory.length - 12
    );

    // Check if activity has been consistently high for an hour
    final allHigh = recentActivities.every((data) => data.movementCount > 50);

    // Check if time since last break is long enough
    final timeSinceLastBreak = _getTimeSinceLastBreak();

    return allHigh && timeSinceLastBreak.inMinutes > 90;
  }

  Duration _getTimeSinceLastBreak() {
    // Find the last period of low activity
    for (int i = _activityHistory.length - 1; i >= 0; i--) {
      if (_activityHistory[i].movementCount < 10) {
        return DateTime.now().difference(_activityHistory[i].timestamp);
      }
    }

    // If no break found, return a large duration
    return Duration(hours: 24);
  }

  void dispose() {
    stopTracking();
    _activityStreamController.close();
  }
}

enum ActivityPrediction {
  low,
  moderate,
  high,
  unknown
}

// Need to add these imports at the top
