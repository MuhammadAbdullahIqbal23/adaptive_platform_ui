import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../toolbar/toolbar_chrome_scope.dart';
import 'adaptive_blur_view.dart';
import 'detent_sheet.dart';
import 'ios_bottom_sheet_route.dart';

export 'detent_sheet.dart' show AdaptiveSheetDetent;

class AdaptiveBottomSheet {
  AdaptiveBottomSheet._();

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

    final fullHeightOnly = DetentSheet.sizesOf(detents).first >= 1.0;
    if (PlatformInfo.isIOS && fullHeightOnly) {
      return showCupertinoSheet<T>(
        context: context,
        enableDrag: isDismissible,
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

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
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
