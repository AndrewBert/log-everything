part of 'todos_carousel_cubit.dart';

class TodosCarouselState extends Equatable {
  final Set<String> completedTodoIds;
  final Map<String, DateTime> removalSchedule;

  const TodosCarouselState({
    this.completedTodoIds = const {},
    this.removalSchedule = const {},
  });

  TodosCarouselState copyWith({
    Set<String>? completedTodoIds,
    Map<String, DateTime>? removalSchedule,
  }) {
    return TodosCarouselState(
      completedTodoIds: completedTodoIds ?? this.completedTodoIds,
      removalSchedule: removalSchedule ?? this.removalSchedule,
    );
  }

  @override
  List<Object?> get props => [
        completedTodoIds,
        removalSchedule,
      ];
}