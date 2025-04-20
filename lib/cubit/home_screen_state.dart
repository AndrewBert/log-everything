import 'package:equatable/equatable.dart';

class HomeScreenState extends Equatable {
  final bool isInputFocused;
  final int titleTapCount;
  final String appVersion;
  final bool isVersionLoading;
  final String? snackBarMessage; // Optional: For showing snackbars via state

  const HomeScreenState({
    this.isInputFocused = false,
    this.titleTapCount = 0,
    this.appVersion = '',
    this.isVersionLoading = false,
    this.snackBarMessage,
  });

  HomeScreenState copyWith({
    bool? isInputFocused,
    int? titleTapCount,
    String? appVersion,
    bool? isVersionLoading,
    String? snackBarMessage,
    bool clearSnackBar = false, // Helper to clear snackbar message
  }) {
    return HomeScreenState(
      isInputFocused: isInputFocused ?? this.isInputFocused,
      titleTapCount: titleTapCount ?? this.titleTapCount,
      appVersion: appVersion ?? this.appVersion,
      isVersionLoading: isVersionLoading ?? this.isVersionLoading,
      snackBarMessage:
          clearSnackBar ? null : snackBarMessage ?? this.snackBarMessage,
    );
  }

  @override
  List<Object?> get props => [
    isInputFocused,
    titleTapCount,
    appVersion,
    isVersionLoading,
    snackBarMessage,
  ];
}
