import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../toolbar/toolbar_chrome_scope.dart';
import 'adaptive_blur_view.dart';
import 'detent_sheet.dart';
import 'ios_bottom_sheet_route.dart';

export 'detent_sheet.dart' show AdaptiveSheetDetent;

/// An adaptive modal bottom sheet that renders platform-specific styles
///
/// On iOS, a sheet that only opens at full height is the system page sheet,
/// `showCupertinoSheet`: the page behind it recedes. Below full height:
/// On iOS 26+: A floating Liquid Glass sheet on a native `UIVisualEffectView`
/// background that meets the screen edges at its full height
/// On iOS <26 (iOS 18 and below): the opaque edge-to-edge iOS sheet
/// On Android: Material 3 `showModalBottomSheet`
///
/// On every platform the sheet rests at [AdaptiveSheetDetent]s and snaps
/// between them; dragging it down past the smallest one dismisses it. The
/// contents are your own widgets, so they share the app's theme, providers
/// and navigator.
class AdaptiveBottomSheet {
  AdaptiveBottomSheet._();

  /// Shows an adaptive bottom sheet whose contents [builder] or
  /// [scrollableBuilder] builds. Pass exactly one.
  ///
  /// [scrollableBuilder] gets a controller the sheet creates and disposes;
  /// give it to the contents' scroll view.
  ///
  /// The sheet opens at [initialDetent] (the smallest of [detents] when null)
  /// and rests at [detents]. The contents get the sheet's height below the
  /// drag handle; give a long list its own scroll view.
  ///
  /// [isDismissible] lets a tap outside the sheet or a drag down dismiss it.
  /// [showDragHandle] draws the grabber (iOS) or drag handle (Android).
  /// [useRootNavigator] picks the navigator the sheet is pushed on; the
  /// full-height iOS sheet always uses the root one.
  /// [backgroundColor] replaces the glass on iOS 26+ and the default surface
  /// elsewhere. [blurStyle] picks the glass material of the iOS 26+ sheet
  /// below full height.
  ///
  /// Returns a Future that resolves to the value the sheet was popped with,
  /// or null when it was dismissed.
  static Future<T?> show<T>({
    required BuildContext context,
    WidgetBuilder? builder,
    ScrollableWidgetBuilder? scrollableBuilder,
    List<AdaptiveSheetDetent> detents = const [AdaptiveSheetDetent.large],
    AdaptiveSheetDetent? initialDetent,
    bool isDismissible = true,
    bool showDragHandle = true,
    bool useRootNavigator = true,
    Color? backgroundColor,
    BlurStyle blurStyle = BlurStyle.systemMaterial,
  }) {
    assert(
      (builder == null) != (scrollableBuilder == null),
      'Pass either builder or scrollableBuilder',
    );
    assert(detents.isNotEmpty, 'A sheet needs at least one detent');
    assert(
      initialDetent == null || detents.contains(initialDetent),
      'initialDetent must be one of detents',
    );

    final barrierLabel = Localizations.of<CupertinoLocalizations>(
      context,
      CupertinoLocalizations,
    )?.modalBarrierDismissLabel;
    final WidgetBuilder contentBuilder =
        builder ??
        (context) => _OwnScrollController(builder: scrollableBuilder!);

    // iOS - the system page sheet, with the page behind it scaled back
    final fullHeightOnly = DetentSheet.sizesOf(detents).first >= 1.0;
    if (PlatformInfo.isIOS && fullHeightOnly) {
      return showCupertinoSheet<T>(
        context: context,
        enableDrag: isDismissible,
        // Newer Flutter releases deprecate builder for scrollableBuilder,
        // which the Flutter version CI builds with does not have yet.
        // ignore: deprecated_member_use
        builder: (context) => _ToolbarCover(
          child: _CupertinoSheetContents(
            showDragHandle: showDragHandle,
            backgroundColor: backgroundColor,
            child: contentBuilder(context),
          ),
        ),
      );
    }

    // iOS 26+ - Floating Liquid Glass sheet
    if (PlatformInfo.isIOS26OrHigher()) {
      return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
        IOSBottomSheetRoute<T>(
          builder: contentBuilder,
          detents: detents,
          initialDetent: initialDetent,
          isDismissible: isDismissible,
          showDragHandle: showDragHandle,
          backgroundColor: backgroundColor,
          blurStyle: blurStyle,
          barrierLabel: barrierLabel,
        ),
      );
    }

    // iOS 18 and below: showCupertinoSheet has no detents; draw the classic
    // sheet at them
    if (PlatformInfo.isIOS) {
      return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
        IOSBottomSheetRoute<T>(
          builder: contentBuilder,
          detents: detents,
          initialDetent: initialDetent,
          isDismissible: isDismissible,
          showDragHandle: showDragHandle,
          backgroundColor: backgroundColor,
          liquidGlass: false,
          barrierLabel: barrierLabel,
        ),
      );
    }

    // Android - Material 3 bottom sheet
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      // The detent sheet inside handles dragging, snapping and dismissing,
      // and draws the handle so that dragging it moves the sheet.
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: backgroundColor,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DetentSheet(
          detents: detents,
          initialDetent: initialDetent,
          isDismissible: isDismissible,
          dragHandle: showDragHandle ? const _MaterialDragHandle() : null,
          chromeBuilder: (context, extent, child) => child,
          builder: contentBuilder,
        ),
      ),
    );
  }
}

/// The surface of the full-height iOS page sheet: [showCupertinoSheet] only
/// clips its page, so the background and text style come from here.
class _CupertinoSheetContents extends StatelessWidget {
  const _CupertinoSheetContents({
    required this.showDragHandle,
    required this.backgroundColor,
    required this.child,
  });

  final bool showDragHandle;
  final Color? backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color =
        backgroundColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.systemBackground,
          context,
        );
    return ColoredBox(
      color: color,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: Column(
            children: [
              if (showDragHandle) const SheetGrabber(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Material 3 drag handle, drawn inside the detent sheet so that dragging
/// it moves the sheet.
class _MaterialDragHandle extends StatelessWidget {
  const _MaterialDragHandle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = theme.bottomSheetTheme.dragHandleSize ?? const Size(32, 4);
    final color =
        theme.bottomSheetTheme.dragHandleColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return SizedBox(
      height: kMinInteractiveDimension,
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size.height / 2),
          ),
        ),
      ),
    );
  }
}

/// Owns the controller a [ScrollableWidgetBuilder] gets.
class _OwnScrollController extends StatefulWidget {
  const _OwnScrollController({required this.builder});

  final ScrollableWidgetBuilder builder;

  @override
  State<_OwnScrollController> createState() => _OwnScrollControllerState();
}

class _OwnScrollControllerState extends State<_OwnScrollController> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// Fades the fixed toolbar out as the page sheet rises over it: the toolbar
/// is drawn above every route, and the page sheet reaches past it.
class _ToolbarCover extends StatefulWidget {
  const _ToolbarCover({required this.child});

  final Widget child;

  @override
  State<_ToolbarCover> createState() => _ToolbarCoverState();
}

class _ToolbarCoverState extends State<_ToolbarCover> {
  ValueSetter<double>? _report;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _report ??= ToolbarChromeScope.sheetCoverReporterOf(context);
    final animation = ModalRoute.of(context)?.animation;
    if (animation == _animation) return;
    _animation?.removeListener(_reportCover);
    _animation = animation?..addListener(_reportCover);
  }

  void _reportCover() => _report?.call(_animation!.value.clamp(0.0, 1.0));

  @override
  void dispose() {
    _animation?.removeListener(_reportCover);
    _report?.call(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
