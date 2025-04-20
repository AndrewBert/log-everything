import 'package:equatable/equatable.dart';

class HomeScreenState extends Equatable {
  final bool isInputFocused;
  final int titleTapCount;
  final String appVersion;
  final bool isVersionLoading;
  final String? snackBarMessage; // Optional: For showing snackbars via state
  final bool showWhatsNewDialog; // Flag to trigger the dialog
  final String? lastSeenVersion; // Store the version seen by the user

  const HomeScreenState({
    this.isInputFocused = false,
    this.titleTapCount = 0,
    this.appVersion = '',
    this.isVersionLoading = false,
    this.snackBarMessage,
    this.showWhatsNewDialog = false, // Default to false
    this.lastSeenVersion, // Initially null
  });

  HomeScreenState copyWith({
    bool? isInputFocused,
    int? titleTapCount,
    String? appVersion,
    bool? isVersionLoading,
    String? snackBarMessage,
    bool clearSnackBar = false, // Helper to clear snackbar message
    bool? showWhatsNewDialog,
    String? lastSeenVersion,
    bool clearLastSeenVersion = false, // Helper if needed
  }) {
    return HomeScreenState(
      isInputFocused: isInputFocused ?? this.isInputFocused,
      titleTapCount: titleTapCount ?? this.titleTapCount,
      appVersion: appVersion ?? this.appVersion,
      isVersionLoading: isVersionLoading ?? this.isVersionLoading,
      snackBarMessage:
          clearSnackBar ? null : snackBarMessage ?? this.snackBarMessage,
      showWhatsNewDialog: showWhatsNewDialog ?? this.showWhatsNewDialog,
      lastSeenVersion:
          clearLastSeenVersion ? null : lastSeenVersion ?? this.lastSeenVersion,
    );
  }

  @override
  List<Object?> get props => [
    isInputFocused,
    titleTapCount,
    appVersion,
    isVersionLoading,
    snackBarMessage,
    showWhatsNewDialog,
    lastSeenVersion,
  ];
}
