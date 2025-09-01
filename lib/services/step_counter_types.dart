/// Shared enums and types for step counter services

/// Activity states for filtering
enum ActivityState {
  walking,
  running,
  still,
  vehicle,
  unknown,
}

/// Step event data
class StepEvent {
  final int timestamp;
  final int totalSteps;
  final ActivityState activityState;
  final bool boutActive;

  StepEvent({
    required this.timestamp,
    required this.totalSteps,
    required this.activityState,
    required this.boutActive,
  });
}
