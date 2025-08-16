import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';

part 'insight_display_state.dart';

class InsightDisplayCubit extends Cubit<InsightDisplayState> {
  InsightDisplayCubit() : super(const InsightDisplayState());

  // CP: Calculate if text is truncated based on actual constraints
  void checkTruncation({
    required double availableWidth,
    required Insight? insight,
    required TextStyle textStyle,
  }) {
    if (insight == null || insight.content.isEmpty) {
      emit(state.copyWith(isTruncated: false));
      return;
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: '"${insight.content}"', // Include quotes as displayed
        style: textStyle,
      ),
      maxLines: 4,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: availableWidth);
    final newTruncatedState = textPainter.didExceedMaxLines;

    if (newTruncatedState != state.isTruncated) {
      emit(state.copyWith(isTruncated: newTruncatedState));
    }
  }

  void toggleExpanded() {
    emit(state.copyWith(isExpanded: !state.isExpanded));
  }

  void expand() {
    if (!state.isExpanded) {
      emit(state.copyWith(isExpanded: true));
    }
  }

  void collapse() {
    if (state.isExpanded) {
      emit(state.copyWith(isExpanded: false));
    }
  }

  // CP: Reset state when insight changes
  void reset() {
    emit(const InsightDisplayState());
  }
}
