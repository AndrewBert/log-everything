import 'package:equatable/equatable.dart';
import 'intent_type.dart';

class IntentClassification extends Equatable {
  final IntentType type;
  final double confidence;
  final DateTime timestamp;

  const IntentClassification({
    required this.type,
    required this.confidence,
    required this.timestamp,
  }) : assert(confidence >= 0.0 && confidence <= 1.0, 'Confidence must be between 0.0 and 1.0');

  @override
  List<Object?> get props => [type, confidence, timestamp];
}
