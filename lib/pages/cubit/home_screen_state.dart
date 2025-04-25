import 'package:equatable/equatable.dart';

class HomeScreenState extends Equatable {
  final bool isInputFocused;
  final String appVersion;
  final bool showWhatsNewDialog;
  final String? snackBarMessage;
  final int titleTapCount;
  final String? lastSeenVersion;
  final bool isVersionLoading;

  const HomeScreenState({
    this.isInputFocused = false,
    this.appVersion = '',
    this.showWhatsNewDialog = false,
    this.snackBarMessage,
    this.titleTapCount = 0,
    this.lastSeenVersion,
    this.isVersionLoading = false,
  });

  @override
  List<Object?> get props => [
    isInputFocused,
    appVersion,
    showWhatsNewDialog,
    snackBarMessage,
    titleTapCount,
    lastSeenVersion,
    isVersionLoading,
  ];

  HomeScreenState copyWith({
    bool? isInputFocused,
    String? appVersion,
    bool? showWhatsNewDialog,
    String? snackBarMessage,
    bool clearSnackBarMessage = false,
    int? titleTapCount,
    String? lastSeenVersion,
    bool? isVersionLoading,
  }) {
    return HomeScreenState(
      isInputFocused: isInputFocused ?? this.isInputFocused,
      appVersion: appVersion ?? this.appVersion,
      showWhatsNewDialog: showWhatsNewDialog ?? this.showWhatsNewDialog,
      snackBarMessage:
          clearSnackBarMessage ? null : snackBarMessage ?? this.snackBarMessage,
      titleTapCount: titleTapCount ?? this.titleTapCount,
      lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion,
      isVersionLoading: isVersionLoading ?? this.isVersionLoading,
    );
  }
}
