import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
import '../utils/widget_keys.dart';

// CP: Extracted to a separate stateful widget to maintain expansion state properly
class EntryCard extends StatefulWidget {
  final Entry entry;
  final bool isNew;
  final bool isProcessing;
  final Color categoryColor;
  final DateFormat timeFormatter;
  final String Function(String) categoryDisplayName;
  final Function(Entry) onChangeCategoryPressed;
  final Function(Entry) onEditPressed;
  final Function(Entry) onDeletePressed;
  final Function(Offset) onLongPress;
  final Function(Entry)? onToggleCompletion; // CP: Optional callback for checklist toggling
  final bool isChecklistCategory; // CP: Whether this entry belongs to a checklist category

  const EntryCard({
    super.key,
    required this.entry,
    required this.isNew,
    required this.isProcessing,
    required this.categoryColor,
    required this.timeFormatter,
    required this.categoryDisplayName,
    required this.onChangeCategoryPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onLongPress,
    this.onToggleCompletion,
    required this.isChecklistCategory,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> with TickerProviderStateMixin {
  // CP: Random emoji selection for the peeping feature
  static const List<String> _peepingEmojis = ['👀', '🫣', '👻', '🤫', '🤪', '🦄'];
  late final bool _showPeepingEmoji;
  late final String _selectedEmoji;
  late final double _horizontalOffset;

  // CP: Animation controller for highlight effects with longer duration for smoothness
  late AnimationController _highlightController;
  late Animation<double> _highlightOpacity;
  late Animation<double> _highlightScale;
  late Animation<double> _borderOpacity;
  late Animation<double> _glowIntensity;

  // CP: Animation controller for rainbow flow effect when processing
  late AnimationController _rainbowController;
  late Animation<double> _rainbowAnimation;
  @override
  void initState() {
    super.initState();
    // CP: 1% chance to show a peeping emoji (rare easter egg)
    _showPeepingEmoji = (DateTime.now().millisecondsSinceEpoch % 100) < 1;
    _selectedEmoji = _peepingEmojis[DateTime.now().millisecondsSinceEpoch % _peepingEmojis.length];
    _horizontalOffset = 20.0 + (DateTime.now().millisecondsSinceEpoch % 60);

    // CP: Longer duration for smoother animations
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    ); // CP: Rainbow animation for processing entries - slower for more elegant effect
    _rainbowController = AnimationController(duration: const Duration(milliseconds: 3500), vsync: this);
    _rainbowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _rainbowController, curve: Curves.linear));

    // CP: Start rainbow animation if entry is processing
    if (widget.isProcessing) {
      _rainbowController.repeat();
    }

    // CP: Staggered animations for more fluid effect
    _highlightOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );

    _highlightScale = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _highlightController, curve: const Interval(0.2, 1.0, curve: Curves.elasticOut)));

    _borderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: const Interval(0.1, 0.8, curve: Curves.easeInOutQuart)),
    );

    _glowIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutExpo)),
    );
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _rainbowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EntryCard oldWidget) {
    super.didUpdateWidget(oldWidget); // CP: Handle processing state changes
    if (widget.isProcessing != oldWidget.isProcessing) {
      if (widget.isProcessing) {
        _rainbowController.repeat();
      } else {
        _rainbowController.stop();
        _rainbowController.reset();
      }
    }
  } // CP: Build iOS/macOS style glass rainbow gradient for magical processing effect

  LinearGradient _buildRainbowGradient() {
    final animationValue =
        _rainbowAnimation
            .value; // CP: iOS/macOS style glass rainbow colors - maximum vibrancy while maintaining glass aesthetic
    const rainbowColors = [
      Color(0xCCFF2222), // Glass Red - maximum vibrancy
      Color(0xCCFF6600), // Glass Orange - more saturated
      Color(0xCCFFBB00), // Glass Gold - brilliant gold
      Color(0xCC00EE77), // Glass Emerald - vivid green
      Color(0xCC0088FF), // Glass Sky Blue - electric blue
      Color(0xCC22BBFF), // Glass Cyan - intense cyan
      Color(0xCCAA22FF), // Glass Purple - rich purple
      Color(0xCCFF22AA), // Glass Pink - hot pink
      Color(0xCCBB44FF), // Glass Lavender - vibrant violet
      Color(0xCC44CCFF), // Glass Ice Blue - brilliant ice
    ];

    // CP: Create smooth glass effect with Apple-style transitions
    final colorCount = rainbowColors.length;
    final currentPosition = (animationValue * colorCount) % colorCount;
    final baseIndex = currentPosition.floor();
    final t = currentPosition - baseIndex;
    final nextIndex = (baseIndex + 1) % colorCount;

    // CP: Get the current glass color with smooth interpolation
    final baseGlassColor =
        Color.lerp(rainbowColors[baseIndex], rainbowColors[nextIndex], t) ??
        rainbowColors[baseIndex]; // CP: Create subtle shimmer effect like iOS glass with breathing rhythm
    final shimmerValue = (animationValue * 1.5) % 1.0; // CP: Slower, more elegant animation
    final shimmerIntensity = 0.5 + 0.35 * (1.0 + math.sin(shimmerValue * 2 * math.pi)) / 2;

    // CP: Add white highlight overlay for authentic iOS glass effect - enhanced for maximum visibility
    final whiteHighlight = Colors.white.withValues(alpha: shimmerIntensity * 0.7);

    // CP: Create the final glass color by blending with white highlight - reduced blending to preserve vibrancy
    final glassColor = Color.lerp(baseGlassColor, whiteHighlight, 0.15) ?? baseGlassColor;

    // CP: Add minimal frosted effect to maintain maximum color vibrancy
    final frostedGlass = Color.lerp(glassColor, Colors.white.withValues(alpha: 0.1), 0.1) ?? glassColor;

    // CP: Apply the iOS/macOS glass effect to the thin bar only
    return LinearGradient(
      stops: const [0.01, 0.01],
      colors: [
        frostedGlass, // CP: Final glass rainbow color with shimmer, frost, and depth
        widget.isNew
            ? Theme.of(context).cardColor.withValues(alpha: 0.96)
            : Theme.of(context).cardColor, // CP: Card background stays unchanged
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // CP: Check if this entry is currently being edited or has context menu open
    return BlocBuilder<EntryCubit, EntryState>(
      buildWhen:
          (prev, current) =>
              prev.editingEntry != current.editingEntry ||
              prev.isEditingMode != current.isEditingMode ||
              prev.contextMenuEntry != current.contextMenuEntry,
      builder: (context, state) {
        final isBeingEdited = state.isEditingMode && state.editingEntry == widget.entry;
        final hasContextMenuOpen = state.contextMenuEntry == widget.entry;
        final shouldHighlight = isBeingEdited || hasContextMenuOpen;

        // CP: Animate highlight when state changes
        if (shouldHighlight) {
          _highlightController.forward();
        } else {
          _highlightController.reverse();
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_highlightController, if (widget.isProcessing) _rainbowController]),
          builder: (context, child) {
            return Transform.scale(
              scale: shouldHighlight ? _highlightScale.value : 1.0,
              child: GestureDetector(
                onLongPressStart: (details) => widget.onLongPress(details.globalPosition),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_showPeepingEmoji)
                      Positioned(
                        left: _horizontalOffset,
                        top: -15, // CP: Position to peek over the card
                        child: Transform.rotate(
                          angle: -0.2 + (DateTime.now().millisecondsSinceEpoch % 4) * 0.1,
                          child: Text(
                            _selectedEmoji,
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1, // CP: Adjust text height to prevent layout issues
                            ),
                          ),
                        ),
                      ),
                    // CP: Enhanced highlight border overlay with staggered animated effects
                    if (shouldHighlight)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _borderOpacity.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: theme.colorScheme.primary, width: 3.0),
                              // CP: Animated glow with varying intensity
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.4 * _glowIntensity.value),
                                  blurRadius: 12.0 * _glowIntensity.value,
                                  spreadRadius: 2.0 * _glowIntensity.value,
                                ),
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2 * _glowIntensity.value),
                                  blurRadius: 20.0 * _glowIntensity.value,
                                  spreadRadius: 4.0 * _glowIntensity.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // CP: Animated background highlight with smooth opacity transition
                    if (shouldHighlight)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _highlightOpacity.value * 0.08,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      key: entryCardKey(widget.entry, filterContext: context.read<EntryCubit>().state.filterCategory),
                      decoration: BoxDecoration(
                        gradient:
                            widget.isProcessing
                                ? _buildRainbowGradient()
                                : LinearGradient(
                                  stops: const [0.01, 0.01],
                                  colors: [
                                    // CP: Keep original colors regardless of highlight state
                                    widget.categoryColor.withValues(alpha: 0.8),
                                    widget.isNew ? theme.cardColor.withValues(alpha: 0.96) : theme.cardColor,
                                  ],
                                ),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color:
                                widget.isNew
                                    ? theme.colorScheme.primary.withValues(alpha: 0.24)
                                    : Colors.black.withValues(alpha: 0.04),
                            blurRadius: widget.isNew ? 8.0 : 4.0,
                            spreadRadius: widget.isNew ? 1.0 : 0.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // CP: Add editing indicator banner at the top
                          if (isBeingEdited)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.9),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12.0),
                                  topRight: Radius.circular(12.0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 16.0, color: theme.colorScheme.onPrimary),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Editing...',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // CP: Row with optional checkbox and expandable text
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // CP: Checkbox for checklist categories or individual tasks
                                    if (widget.isChecklistCategory || widget.entry.isTask) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0, right: 12.0),
                                        child: GestureDetector(
                                          onTap: widget.onToggleCompletion != null
                                              ? () {
                                                  HapticFeedback.lightImpact();
                                                  widget.onToggleCompletion!(widget.entry);
                                                }
                                              : null,
                                          child: AnimatedContainer(
                                            key: entryCheckboxKey(widget.entry),
                                            duration: const Duration(milliseconds: 200),
                                            curve: Curves.easeInOutCubic,
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: widget.entry.isCompleted
                                                  ? theme.colorScheme.primary
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: widget.entry.isCompleted
                                                    ? theme.colorScheme.primary
                                                    : Colors.grey.shade400,
                                                width: 2,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                              boxShadow: widget.entry.isCompleted ? [
                                                BoxShadow(
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ] : null,
                                            ),
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 150),
                                              child: widget.entry.isCompleted
                                                  ? Icon(
                                                      Icons.check,
                                                      key: const ValueKey('check'),
                                                      size: 14,
                                                      color: theme.colorScheme.onPrimary,
                                                    )
                                                  : const SizedBox.shrink(key: ValueKey('empty')),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    // CP: Expandable text section
                                    Expanded(
                                      child: _ExpandableText(
                                        text: widget.entry.text,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.4,
                                          // CP: Slightly mute text when being edited to indicate it's in input field
                                          color: isBeingEdited 
                                              ? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7) 
                                              : null,
                                          // CP: Strikethrough for completed checklist items or tasks
                                          decoration: (widget.isChecklistCategory || widget.entry.isTask) && widget.entry.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationColor: Colors.grey,
                                        ),
                                        maxLines: 3,
                                        isCompleted: (widget.isChecklistCategory || widget.entry.isTask) && widget.entry.isCompleted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12.0),
                                // Bottom row with timestamp and category
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Timestamp with icon for better visual grouping
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14.0, color: Colors.grey[600]),
                                        const SizedBox(width: 4.0),
                                        Text(
                                          widget.timeFormatter.format(widget.entry.timestamp),
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    // Row for category chip and action buttons
                                    Row(
                                      children: [
                                        // Category chip with optional checklist or task icon
                                        ActionChip(
                                          key: entryCategoryChipKey(widget.entry),
                                          avatar: (widget.isChecklistCategory || widget.entry.isTask) ? Icon(
                                            widget.isChecklistCategory ? Icons.checklist : Icons.task_alt,
                                            size: 14,
                                            color: widget.isProcessing
                                                ? Colors.orange[900]
                                                : CategoryColors.getTextColorForCategory(widget.entry.category),
                                          ) : null,
                                          label: Text(
                                            widget.categoryDisplayName(widget.entry.category),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  widget.isProcessing
                                                      ? Colors.orange[900]
                                                      : CategoryColors.getTextColorForCategory(widget.entry.category),
                                            ),
                                          ),
                                          backgroundColor:
                                              widget.isProcessing
                                                  ? Colors.orange.shade100.withValues(alpha: 0.8)
                                                  : widget.categoryColor.withValues(alpha: 0.2),
                                          side: BorderSide.none,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onPressed:
                                              widget.isProcessing
                                                  ? null
                                                  : () {
                                                    HapticFeedback.lightImpact();
                                                    widget.onChangeCategoryPressed(widget.entry);
                                                  },
                                          tooltip: widget.isProcessing ? null : 'Change Category',
                                        ),
                                        const SizedBox(width: 8.0),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final bool isCompleted;

  const _ExpandableText({required this.text, this.style, this.maxLines = 3, this.isCompleted = false});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;
  bool? _hasTextOverflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_hasTextOverflow == null) {
          final textSpan = TextSpan(text: widget.text, style: widget.style);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: ui.TextDirection.ltr,
            maxLines: widget.maxLines,
          )..layout(maxWidth: constraints.maxWidth);

          _hasTextOverflow = textPainter.didExceedMaxLines;
        }

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: widget.isCompleted ? 0.6 : 1.0, // CP: Reduce opacity for completed items
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCrossFade(
                firstChild: Text(
                  widget.text,
                  style: widget.style,
                  maxLines: widget.maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Text(widget.text, style: widget.style),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              if (_hasTextOverflow ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: TextButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0), // CP: Increased tap target
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isExpanded ? 'Show less' : 'Show more',
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}