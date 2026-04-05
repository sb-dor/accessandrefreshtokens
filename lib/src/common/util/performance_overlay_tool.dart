import 'package:flutter/foundation.dart';
import 'package:ui/ui.dart';
import 'package:accessandrefreshtoken/src/common/util/screen_util.dart';

class PerformanceOverlayTool extends StatefulWidget {
  const PerformanceOverlayTool({super.key, required this.child, this.enabled = kProfileMode});

  final Widget child;
  final bool enabled;

  @override
  State<PerformanceOverlayTool> createState() => _PerformanceOverlayToolState();
}

class _PerformanceOverlayToolState extends State<PerformanceOverlayTool> {
  @override
  Widget build(BuildContext context) => widget.enabled
      ? Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              bottom: 0,
              left: 0,
              width: context.screenSizeMaybeWhen(
                orElse: () => MediaQuery.of(context).size.width,
                desktop: () => 500,
              ),
              child: PerformanceOverlay.allEnabled(),
            ),
          ],
        )
      : widget.child;
}
