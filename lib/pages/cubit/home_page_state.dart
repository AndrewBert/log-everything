import 'package:equatable/equatable.dart';

class HomePageState extends Equatable {
  final bool isInputFocused;
  final String appVersion;
  final bool showWhatsNewDialog;
  final String? snackBarMessage;
  final int titleTapCount;
  final String? lastSeenVersion;
  final bool isVersionLoading;
  final bool isChatOpen;

  const HomePageState({
    this.isInputFocused = false,
    this.appVersion = '',
    this.showWhatsNewDialog = false,
    this.snackBarMessage,
    this.titleTapCount = 0,
    this.lastSeenVersion,
    this.isVersionLoading = false,
    this.isChatOpen = false,
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
    isChatOpen,
  ];

  HomePageState copyWith({
    bool? isInputFocused,
    String? appVersion,
    bool? showWhatsNewDialog,
    String? snackBarMessage,
    bool clearSnackBarMessage = false,
    int? titleTapCount,
    String? lastSeenVersion,
    bool? isVersionLoading,
    bool? isChatOpen,
  }) {
    return HomePageState(
      isInputFocused: isInputFocused ?? this.isInputFocused,
      appVersion: appVersion ?? this.appVersion,
      showWhatsNewDialog: showWhatsNewDialog ?? this.showWhatsNewDialog,
      snackBarMessage: clearSnackBarMessage ? null : snackBarMessage ?? this.snackBarMessage,
      titleTapCount: titleTapCount ?? this.titleTapCount,
      lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion,
      isVersionLoading: isVersionLoading ?? this.isVersionLoading,
      isChatOpen: isChatOpen ?? this.isChatOpen,
    );
  }
}
