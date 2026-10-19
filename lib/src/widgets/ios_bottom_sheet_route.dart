import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

import '../toolbar/hosted_top_toolbar.dart' show kHostedToolbarHeight;
import '../toolbar/toolbar_chrome_scope.dart';
import 'adaptive_blur_view.dart';
import 'detent_sheet.dart';

const double _kTopGap = 10;

const double _kFloatingInset = 8;

const double _kGlassRadius = 36;

const double _kLegacyRadius = 10;

const double _kToolbarFadeDistance = 40;

class IOSBottomSheetRoute<T> extends PopupRoute<T> {
  IOSBottomSheetRoute({
    required this.builder,
    this.detents = const [AdaptiveSheetDetent.large],
    this.initialDetent,
    this.isDismissible = true,
    this.showDragHandle = true,
    this.backgroundColor,
    this.blurStyle = BlurStyle.systemMaterial,
    this.liquidGlass = true,
    String? barrierLabel,
    super.settings,
  }) : assert(detents.isNotEmpty),
       _barrierLabel = barrierLabel;

  final WidgetBuilder builder;

  final List<AdaptiveSheetDetent> detents;

  final AdaptiveSheetDetent? initialDetent;

  final bool isDismissible;

  final bool showDragHandle;

  final Color? backgroundColor;

  final BlurStyle blurStyle;

  final bool liquidGlass;

  final String? _barrierLabel;

  double _extent = 0;
  double _available = 0;
  double _topPadding = 0;

  ValueSetter<double>? _reportCover;

  @override
  Color? get barrierColor => const Color(0x33000000);

  @override
  bool get barrierDismissible => isDismissible;

  @override
  String? get barrierLabel => _barrierLabel ?? 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  void install() {
    super.install();
    animation!.addListener(_reportToolbarCover);
  }

  @override
  void dispose() {
    animation?.removeListener(_reportToolbarCover);
    _reportCover?.call(0);
    super.dispose();
  }

  void _reportToolbarCover() {
    final report = _reportCover;
    if (report == null || _available <= 0) return;
    final shown = _extent * _available;
    final top =
        _topPadding +
        _kTopGap +
        (_available - shown) +
        (1 - animation!.value) * shown;
    final toolbarBottom = _topPadding + kHostedToolbarHeight;
    final cover =
        (toolbarBottom + _kToolbarFadeDistance - top) / _kToolbarFadeDistance;
    report(cover.clamp(0.0, 1.0));
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    _reportCover ??= ToolbarChromeScope.sheetCoverReporterOf(context);
    final mediaQuery = MediaQuery.of(context);
    _topPadding = mediaQuery.padding.top;
    _available =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top -
        _kTopGap;
    return Padding(
      padding: EdgeInsets.only(
        top: mediaQuery.padding.top + _kTopGap,
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: MediaQuery(
        data: mediaQuery
            .removeViewInsets(removeBottom: true)
            .removePadding(removeTop: true),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          child: DetentSheet(
            detents: detents,
            initialDetent: initialDetent,
            isDismissible: isDismissible,
            dragHandle: showDragHandle ? const SheetGrabber() : null,
            chromeBuilder: _buildChrome,
            builder: builder,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.fastEaseInToSlowEaseOut,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }

  Widget _buildChrome(BuildContext context, double extent, Widget child) {
    _extent = extent;
    _reportToolbarCover();
    final full = liquidGlass
        ? ((extent - 0.9) / 0.1).clamp(0.0, 1.0) * _fullHeightFactor
        : 1.0;
    final inset = lerpDouble(_kFloatingInset, 0, full)!;
    final topRadius = liquidGlass ? _kGlassRadius : _kLegacyRadius;
    final bottomRadius = liquidGlass
        ? lerpDouble(_kGlassRadius, 0, full)!
        : 0.0;
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(topRadius),
      bottom: Radius.circular(bottomRadius),
    );

    final mediaQuery = MediaQuery.of(context);
    final contents = MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(
          bottom: (mediaQuery.padding.bottom - inset).clamp(
            0.0,
            double.infinity,
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: child,
        ),
      ),
    );

    final Widget surface;
    if (backgroundColor != null || !liquidGlass) {
      final color =
          backgroundColor ??
          CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground,
            context,
          );
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(color: color, child: contents),
      );
    } else {
      surface = AdaptiveBlurView(
        blurStyle: blurStyle,
        borderRadius: borderRadius,
        child: contents,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            if (liquidGlass)
              const BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 30,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: surface,
      ),
    );
  }

  double get _fullHeightFactor =>
      DetentSheet.sizesOf(detents).last >= 1.0 ? 1.0 : 0.0;
}
