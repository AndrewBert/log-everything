import 'package:equatable/equatable.dart'; // <-- Import Equatable

// Extend Equatable
class HomeScreenState extends Equatable {
  final bool isInputFocused;
  final String appVersion;
  final bool showWhatsNewDialog;
  final String? snackBarMessage; // Nullable
  final int titleTapCount; // Added based on file content

  const HomeScreenState({
    this.isInputFocused = false,
    this.appVersion = '',
    this.showWhatsNewDialog = false,
    this.snackBarMessage,
    this.titleTapCount = 0,
  });

  // Implement props getter
  @override
  List<Object?> get props => [
    isInputFocused,
    appVersion,
    showWhatsNewDialog,
    snackBarMessage,
    titleTapCount,
  ];

  HomeScreenState copyWith({
    bool? isInputFocused,
    String? appVersion,
    bool? showWhatsNewDialog,
    String? snackBarMessage,
    bool clearSnackBarMessage = false,
    int? titleTapCount,
  }) {
    return HomeScreenState(
      isInputFocused: isInputFocused ?? this.isInputFocused,
      appVersion: appVersion ?? this.appVersion,
      showWhatsNewDialog: showWhatsNewDialog ?? this.showWhatsNewDialog,
      snackBarMessage:
          clearSnackBarMessage ? null : snackBarMessage ?? this.snackBarMessage,
      titleTapCount: titleTapCount ?? this.titleTapCount,
    );
  }
}
