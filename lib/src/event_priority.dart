/// Predefined integer event priorities.
enum EventPriority {
  lowest(-1000),
  low(-500),
  normal(0),
  high(500),
  highest(1000);

  final int value;

  // Constructor to associate values with enum constants
  const EventPriority(this.value);
}