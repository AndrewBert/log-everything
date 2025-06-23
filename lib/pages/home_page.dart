import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/utils/logger.dart';
import 'dart:async'; // Import async for Timer
import 'package:package_info_plus/package_info_plus.dart'; // Import package_info_plus
import '../utils/app_bar_keys.dart'; // Import the new app bar keys file

import 'cubit/home_page_cubit.dart';
import 'cubit/home_page_state.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
import '../widgets/entries_list.dart';
import '../widgets/filter_section.dart';
import '../widgets/input_area.dart';
import '../dialogs/manage_categories_dialog.dart';
import '../dialogs/change_category_dialog.dart';
import '../dialogs/edit_category_dialog.dart';
import '../dialogs/help_dialog.dart';
import '../dialogs/whats_new_dialog.dart';
import '../dialogs/delete_category_confirmation_dialog.dart';
import '../chat/chat.dart'; // CP: Import chat features
import '../snackbar/services/snackbar_service.dart';
import '../snackbar/widgets/contextual_snackbar_overlay.dart';
import '../snackbar/models/snackbar_message.dart';
import '../locator.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  // CP: Changed from 24-hour to 12-hour format
  final DateFormat _timeFormatter = DateFormat('h:mm a');

  // Move build method to the top
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color? defaultTitleColor = Theme.of(context).appBarTheme.titleTextStyle?.color;
    final isChatOpen = context.watch<HomePageCubit>().state.isChatOpen; // CP: Get chat state

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<HomePageCubit, HomePageState>(
            // Remove unnecessary null checks
            listenWhen: (prev, current) => !prev.showWhatsNewDialog && current.showWhatsNewDialog,
            listener: (context, state) async {
              // Remove unnecessary null check
              await _showWhatsNewDialog(context, state.appVersion);
              if (context.mounted) {
                context.read<HomePageCubit>().markWhatsNewShown();
              }
            },
          ),
          BlocListener<HomePageCubit, HomePageState>(
            // Keep null check for snackBarMessage as it IS nullable
            listenWhen: (prev, current) {
              final condition = prev.snackBarMessage != current.snackBarMessage && current.snackBarMessage != null;
              return condition;
            },
            listener: (context, state) {
              // CP: Log listener invocation for snackBarMessage
              AppLogger.info('[HomePage] SnackBar listener called. state.snackBarMessage: ${state.snackBarMessage}');
              final snackbarService = getIt<SnackbarService>();
              snackbarService.showInfo(state.snackBarMessage!, context: SnackbarContext.home);
              // CP: Log before calling clearSnackBarMessage in addPostFrameCallback
              AppLogger.info('[HomePage] Scheduling clearSnackBarMessage via addPostFrameCallback.');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // CP: Log inside addPostFrameCallback before clearing
                AppLogger.info('[HomePage] addPostFrameCallback: Clearing SnackBar message.');
                if (context.mounted) {
                  context.read<HomePageCubit>().clearSnackBarMessage();
                }
              });
            },
          ),
          // CP: Listen for entry split notifications to show toast
          BlocListener<EntryCubit, EntryState>(
            listenWhen: (prev, current) =>
                prev.splitNotification != current.splitNotification && current.splitNotification != null,
            listener: (context, state) {
              AppLogger.info('[HomePage] Split notification: ${state.splitNotification}');
              final snackbarService = getIt<SnackbarService>();
              snackbarService.showInfo(state.splitNotification!, context: SnackbarContext.home);
              // CP: Clear the notification after showing
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.read<EntryCubit>().clearSplitNotification();
                }
              });
            },
          ),
        ],
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: isChatOpen ? 1 : 0,
                  children: [
                    // CP: Entries list view - kept alive when chat is open
                    Stack(
                      children: [
                        CustomScrollView(
                          controller: context.read<HomePageCubit>().entriesScrollController,
                          slivers: [
                            SliverAppBar(
                              expandedHeight: 112.0, // 56 (app bar) + 56 (filter section with margins)
                              floating: false,
                              pinned: true, // Keep app bar always visible
                              snap: false,
                              elevation: 0, // Remove default shadow
                              surfaceTintColor: Colors.transparent, // Remove surface tint
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              title: GestureDetector(
                                key: appBarTitleGestureDetector, // Use the key from app_bar_keys.dart
                                onTap: () {
                                  context.read<HomePageCubit>().incrementTitleTap();
                                },
                                child: RichText(
                                  text: TextSpan(
                                    style:
                                        Theme.of(context).appBarTheme.titleTextStyle ??
                                        Theme.of(context).textTheme.titleLarge,
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: 'Log',
                                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: ' / Splitter',
                                        style: TextStyle(color: defaultTitleColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                BlocBuilder<HomePageCubit, HomePageState>(
                                  // Remove unnecessary null checks
                                  buildWhen: (prev, current) => prev.appVersion != current.appVersion,
                                  builder: (context, state) {
                                    // Remove unnecessary null checks
                                    if (state.appVersion.isNotEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Center(
                                          child: Text(
                                            state.appVersion, // Remove !
                                            style: TextStyle(fontSize: 12, color: Colors.black87),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.help_outline),
                                  tooltip: 'Help / About',
                                  onPressed: () => _showHelpDialog(context),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.tune,
                                  ), // CP: Changed from category_outlined to tune for clarity
                                  tooltip: 'Manage Categories',
                                  onPressed: () => _showManageCategoriesDialog(context),
                                ),
                                const SizedBox(width: 8),
                              ],
                              flexibleSpace: FlexibleSpaceBar(
                                background: Column(
                                  children: [
                                    // Space for the app bar title and actions
                                    const SizedBox(height: 56.0),
                                    // Filter section in the expanded area
                                    const FilterSection(),
                                  ],
                                ),
                              ),
                              bottom: PreferredSize(
                                preferredSize: const Size.fromHeight(0),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Check if we're in collapsed state by looking at flex space
                                    final isCollapsed = constraints.maxHeight <= 56.0;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: isCollapsed ? 1.0 : 0.0,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: isCollapsed
                                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            ..._buildEntriesSliver(context),
                            SliverPadding(
                              padding: const EdgeInsets.only(bottom: 150.0),
                            ),
                          ],
                        ),
                        const ContextualSnackbarOverlay(
                          contextFilter: SnackbarContext.home,
                          topOffset: 56.0, // Position over the filters section
                        ),
                      ],
                    ),
                    // CP: Chat view
                    const ChatBottomSheet(),
                  ],
                ),
              ),
              // CP: InputArea is now outside the conditional, so it persists
              InputArea(
                onSendPressed: (text) => _handleInput(context, text),
                showSnackBar:
                    ({
                      required context,
                      required content,
                      Duration? duration,
                      action,
                      backgroundColor,
                    }) {
                      final snackbarService = getIt<SnackbarService>();
                      if (content is Text && content.data != null && content.data!.isNotEmpty) {
                        // Determine the type based on background color or content
                        if (backgroundColor == Colors.red || backgroundColor == Colors.redAccent) {
                          snackbarService.showError(content.data!, context: SnackbarContext.home);
                        } else {
                          snackbarService.showSuccess(content.data!, context: SnackbarContext.home);
                        }
                      }
                      // If content is empty or not meaningful, don't show a snackbar
                    },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Methods Below Build ---

  List<Widget> _buildEntriesSliver(BuildContext context) {
    return EntriesList.buildSlivers(
      context: context,
      formatDateHeader: _formatDateHeader,
      getCategoryColor: _getCategoryColor,
      timeFormatter: _timeFormatter,
      onChangeCategoryPressed: (entry) => _showChangeCategoryDialog(context, entry),
      onEditPressed: (entry) => _handleEditEntry(context, entry),
      onDeletePressed: (entry) => _handleDeleteEntry(context, entry),
    );
  }

  Future<void> _showWhatsNewDialog(BuildContext context, [String? version]) async {
    String currentVersion = version ?? '';
    if (currentVersion.isEmpty) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      } catch (e, stackTrace) {
        AppLogger.error('Error getting package info for What\'s New dialog: $e', stackTrace: stackTrace);
        // Check context is still valid if async gap occurred
        if (!context.mounted) return;
        final snackbarService = getIt<SnackbarService>();
        snackbarService.showError('Could not load version info.', context: SnackbarContext.home);
        return;
      }
    }

    String displayVersion = currentVersion;
    final versionMatch = RegExp(r'v([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(currentVersion);
    if (versionMatch != null) {
      displayVersion = versionMatch.group(1) ?? currentVersion;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => WhatsNewDialog(currentVersion: displayVersion),
    );
  }

  void _handleInput(BuildContext context, String currentText) {
    final voiceCubit = context.read<VoiceInputCubit>();
    final entryCubit = context.read<EntryCubit>();
    final homePageCubit = context.read<HomePageCubit>(); // CP: Get HomePageCubit
    final chatCubit = context.read<ChatCubit>(); // CP: Get ChatCubit

    if (homePageCubit.state.isChatOpen) {
      // CP: Check if chat is open
      if (currentText.isNotEmpty) {
        chatCubit.addUserMessage(currentText);
      }
      return;
    }

    if (voiceCubit.state.isRecording) {
      AppLogger.info('Send tapped during recording. Stopping and combining text with transcription.');
      HapticFeedback.mediumImpact();

      // 1. Create temporary entry
      final DateTime processingTimestamp = DateTime.now();
      final tempEntry = Entry(
        text: currentText.isEmpty ? "Processing voice..." : currentText, // Show initial text if available
        timestamp: processingTimestamp,
        category: 'Processing...',
        isNew: true,
      );

      // 2. Show temporary entry in UI immediately
      entryCubit.showTemporaryEntry(tempEntry);

      // 3. Tell VoiceInputCubit to stop, combine, and process,
      //    passing the timestamp to identify the temporary entry later.
      voiceCubit.stopRecordingAndCombine(currentText, processingTimestamp);

      return; // VoiceInputCubit/EntryCubit will handle final state
    }

    if (currentText.isNotEmpty) {
      entryCubit.addEntry(currentText);
    }
  }

  Future<bool> _showDeleteCategoryConfirmationDialog(BuildContext context, String category) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return DeleteCategoryConfirmationDialog(category: category);
          },
        ) ??
        false;
  }

  void _showManageCategoriesDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final focusScope = FocusScope.of(context);
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: ManageCategoriesDialog(
                onShowEditCategoryDialog: (ctx, oldName, {bool focusDescription = false}) =>
                    _showEditCategoryDialog(ctx, oldName, focusDescription: focusDescription),
                onShowDeleteCategoryConfirmationDialog: (ctx, cat) => _showDeleteCategoryConfirmationDialog(ctx, cat),
              ),
            ),
            const ContextualSnackbarOverlay(contextFilter: SnackbarContext.dialog),
          ],
        ),
      ),
    ).then((_) {
      focusScope.focusedChild?.unfocus();
    });
  }

  Future<EditCategoryResult?> _showEditCategoryDialog(
    BuildContext context,
    String oldCategoryName, {
    bool focusDescription = false,
  }) async {
    return await showDialog<EditCategoryResult?>(
      context: context,
      builder: (dialogContext) {
        return EditCategoryDialog(oldCategoryName: oldCategoryName, focusDescription: focusDescription);
      },
    );
  }

  Future<void> _showChangeCategoryDialog(BuildContext context, Entry entry) async {
    final entryCubit = context.read<EntryCubit>();
    final availableCategories = entryCubit.state.categories.map((cat) => cat.name).toList()..sort();
    String? selectedCategory = entry.category;

    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Misc';
    }

    final String? newCategory = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return ChangeCategoryDialog(currentCategory: selectedCategory, availableCategories: availableCategories);
      },
    );

    if (newCategory != null && newCategory != entry.category) {
      final updatedEntry = entry.copyWith(category: newCategory);
      entryCubit.updateEntry(entry, updatedEntry);
      if (context.mounted) {
        final snackbarService = getIt<SnackbarService>();
        snackbarService.showSuccess('Category changed to "$newCategory"', context: SnackbarContext.home);
      }
    }
  }

  void _showHelpDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final focusScope = FocusScope.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return HelpDialog(onShowWhatsNewPressed: () => _showWhatsNewDialog(context));
      },
    ).then((_) {
      focusScope.focusedChild?.unfocus();
    });
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String header;
    if (dateOnly == today) {
      header = 'Today';
    } else if (dateOnly == yesterday) {
      header = 'Yesterday';
    } else {
      header = DateFormat.yMMMd().format(date);
    }
    return header;
  }

  Color _getCategoryColor(String category) {
    return CategoryColors.getColorForCategory(category);
  }

  void _handleDeleteEntry(BuildContext context, Entry entry) {
    final entryToDelete = entry;
    context.read<EntryCubit>().deleteEntry(entryToDelete);
    if (context.mounted) {
      final snackbarService = getIt<SnackbarService>();
      snackbarService.showSuccess(
        'Entry deleted',
        context: SnackbarContext.home,
        actionLabel: 'Undo',
        onActionPressed: () {
          if (context.mounted) {
            context.read<EntryCubit>().addEntryObject(entryToDelete);
          }
        },
      );
    }
  }

  // CP: New method to handle in-place editing instead of showing dialog
  void _handleEditEntry(BuildContext context, Entry entry) {
    HapticFeedback.lightImpact();
    context.read<EntryCubit>().startEditingEntry(entry);
  }
}
