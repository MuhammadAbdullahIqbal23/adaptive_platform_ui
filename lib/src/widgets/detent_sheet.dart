import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

@immutable
class AdaptiveSheetDetent {
  const AdaptiveSheetDetent.fraction(this.fraction)
    : assert(fraction > 0 && fraction <= 1);

  static const AdaptiveSheetDetent medium = AdaptiveSheetDetent.fraction(0.5);

  static const AdaptiveSheetDetent large = AdaptiveSheetDetent.fraction(1.0);

  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is AdaptiveSheetDetent && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => 'AdaptiveSheetDetent(${fraction.toStringAsFixed(2)})';
}

typedef SheetChromeBuilder =
    Widget Function(BuildContext context, double extent, Widget child);

class DetentSheet extends StatefulWidget {
  const DetentSheet({
    super.key,
    required this.detents,
    this.initialDetent,
    this.isDismissible = true,
    this.dragHandle,
    required this.chromeBuilder,
    required this.builder,
  }) : assert(detents.length > 0);

  final List<AdaptiveSheetDetent> detents;

  final AdaptiveSheetDetent? initialDetent;

  final bool isDismissible;

  final Widget? dragHandle;

  final SheetChromeBuilder chromeBuilder;

  final WidgetBuilder builder;

  static List<double> sizesOf(List<AdaptiveSheetDetent> detents) =>
      detents.map((d) => d.fraction).toSet().toList()..sort();

  @override
  State<DetentSheet> createState() => _DetentSheetState();
}

class _DetentSheetState extends State<DetentSheet> {
  late final ValueNotifier<double> _extent = ValueNotifier(_initialSize);
  bool _closing = false;

  List<double> get _sizes => DetentSheet.sizesOf(widget.detents);

  double get _initialSize {
    final initial = widget.initialDetent;
    assert(
      initial == null || widget.detents.contains(initial),
      'initialDetent must be one of detents',
    );
    return initial?.fraction ?? _sizes.first;
  }

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  bool _handleExtent(DraggableScrollableNotification notification) {
    _extent.value = notification.extent;
    if (widget.isDismissible && !_closing && notification.extent <= 0.001) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final sizes = _sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: _handleExtent,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: _initialSize,
            minChildSize: widget.isDismissible ? 0 : sizes.first,
            maxChildSize: sizes.last,
            snap: true,
            snapSizes: sizes,
            shouldCloseOnMinExtent: false,
            builder: (context, scrollController) {
              final scrollView = CustomScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  if (widget.dragHandle != null)
                    SliverToBoxAdapter(child: widget.dragHandle),
                  SliverLayoutBuilder(
                    builder: (context, sliver) {
                      final remaining =
                          sliver.viewportMainAxisExtent -
                          sliver.precedingScrollExtent;
                      final hidden =
                          math.max(0.0, sizes.first - _extent.value) *
                          constraints.maxHeight;
                      return SliverToBoxAdapter(
                        child: SizedBox(
                          height: math.max(0, remaining + hidden),
                          child: Builder(builder: widget.builder),
                        ),
                      );
                    },
                  ),
                ],
              );
              return ValueListenableBuilder<double>(
                valueListenable: _extent,
                builder: (context, extent, child) =>
                    widget.chromeBuilder(context, extent, child!),
                child: scrollView,
              );
            },
          ),
        );
      },
    );
  }
}

class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.tertiaryLabel,
              context,
            ),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}
