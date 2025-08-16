part of 'insight_display_cubit.dart';

class InsightDisplayState extends Equatable {
  final bool isExpanded;
  final bool isTruncated;

  const InsightDisplayState({
    this.isExpanded = false,
    this.isTruncated = false,
  });

  InsightDisplayState copyWith({
    bool? isExpanded,
    bool? isTruncated,
  }) {
    return InsightDisplayState(
      isExpanded: isExpanded ?? this.isExpanded,
      isTruncated: isTruncated ?? this.isTruncated,
    );
  }

  @override
  List<Object?> get props => [isExpanded, isTruncated];
}
