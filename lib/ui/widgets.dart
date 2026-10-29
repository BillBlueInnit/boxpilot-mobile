import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../i18n/i18n.dart';
import 'adaptive.dart';

/// Colours that mean the same thing on both platforms.
class StatusColors {
  static Color good(BuildContext c) =>
      isCupertino ? CupertinoColors.systemGreen.resolveFrom(c) : const Color(0xFF2E7D32);
  static Color fair(BuildContext c) =>
      isCupertino ? CupertinoColors.systemOrange.resolveFrom(c) : const Color(0xFFEF6C00);
  static Color bad(BuildContext c) =>
      isCupertino ? CupertinoColors.systemRed.resolveFrom(c) : Theme.of(c).colorScheme.error;
  static Color muted(BuildContext c) =>
      isCupertino ? CupertinoColors.secondaryLabel.resolveFrom(c) : Theme.of(c).colorScheme.onSurfaceVariant;
  static Color accent(BuildContext c) =>
      isCupertino ? CupertinoTheme.of(c).primaryColor : Theme.of(c).colorScheme.primary;

  /// For a latency in ms (`-1` failed).
  static Color latency(BuildContext c, int ms) {
    if (ms < 0) return bad(c);
    if (ms < 300) return good(c);
    if (ms < 800) return fair(c);
    return bad(c);
  }
}

/// `128 ms`, `timeout` or a spinner, coloured by quality. Tap to test.
class LatencyBadge extends StatelessWidget {
  const LatencyBadge({super.key, required this.delay, this.testing = false, this.onTap});

  final int? delay;
  final bool testing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (testing) {
      child = SizedBox.square(
        dimension: 14,
        child: isCupertino
            ? const CupertinoActivityIndicator(radius: 7)
            : const CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (delay == null) {
      child = Icon(
        isCupertino ? CupertinoIcons.bolt : Icons.bolt_outlined,
        size: 16,
        color: StatusColors.muted(context),
      );
    } else {
      final ms = delay!;
      child = Text(
        ms < 0 ? tr('latency.timeout') : '$ms ms',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: StatusColors.latency(context, ms),
        ),
      );
    }
    return Semantics(
      button: onTap != null,
      label: tr('btn.test_latency'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: testing ? null : onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: child),
      ),
    );
  }
}

/// Up / down speed lines over the last minute.
class TrafficChart extends StatelessWidget {
  const TrafficChart({super.key, required this.history, this.height = 96});

  final TrafficHistory history;
  final double height;

  @override
  Widget build(BuildContext context) {
    final up = StatusColors.accent(context);
    final down = isCupertino ? CupertinoColors.systemTeal.resolveFrom(context) : Theme.of(context).colorScheme.tertiary;
    final grid = StatusColors.muted(context).withValues(alpha: 0.18);
    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: history,
          builder: (context, _) =>
              CustomPaint(size: Size.infinite, painter: _ChartPainter(history.up, history.down, up, down, grid)),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.up, this.down, this.upColor, this.downColor, this.gridColor)
    : peak = math.max(1, [...up, ...down].fold<int>(0, math.max));

  final List<int> up;
  final List<int> down;
  final Color upColor;
  final Color downColor;
  final Color gridColor;
  final int peak;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _series(canvas, size, down, downColor);
    _series(canvas, size, up, upColor);
  }

  void _series(Canvas canvas, Size size, List<int> values, Color color) {
    if (values.length < 2) return;
    final dx = size.width / (values.length - 1);
    Offset at(int i) => Offset(i * dx, size.height - (values[i] / peak) * (size.height - 4) - 2);
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = at(i - 1), p1 = at(i);
      final mid = (p0.dx + p1.dx) / 2;
      line.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// The big round connect button. iOS 26: a native Liquid Glass button
/// (prominent while connected). Android: a Material 3 tonal / filled circle.
class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key, required this.running, required this.busy, required this.onPressed});

  final bool running;
  final bool busy;
  final VoidCallback onPressed;

  static const size = 132.0;

  void _press() {
    HapticFeedback.mediumImpact();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final label = running ? tr('btn.disconnect') : tr('btn.connect');
    if (isCupertino) {
      return Semantics(
        button: true,
        label: label,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: size,
                child: AdaptiveButton.sfSymbol(
                  onPressed: busy ? null : _press,
                  sfSymbol: SFSymbol('power', size: 44, color: running ? CupertinoColors.white : null),
                  style: running ? AdaptiveButtonStyle.prominentGlass : AdaptiveButtonStyle.glass,
                  color: running ? CupertinoTheme.of(context).primaryColor : null,
                  useSmoothRectangleBorder: false,
                  borderRadius: BorderRadius.circular(size / 2),
                ),
              ),
              if (busy) const IgnorePointer(child: CupertinoActivityIndicator(radius: 16)),
            ],
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final bg = running ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = running ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (busy)
              SizedBox.square(
                dimension: size,
                child: CircularProgressIndicator(strokeWidth: 4, color: scheme.primary, strokeCap: StrokeCap.round),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: size - 16,
              height: size - 16,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: running
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : _press,
                  child: Icon(Icons.power_settings_new_rounded, size: 48, color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded card for dashboard content: Material filled card or an iOS grouped cell.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        pressedOpacity: onTap == null ? 1 : 0.6,
        onPressed: onTap,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(26),
          ),
          child: DefaultTextStyle(style: CupertinoTheme.of(context).textTheme.textStyle, child: child),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A small label + value pair (speed, totals).
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value, this.color, this.icon});

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = StatusColors.muted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color ?? muted), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 13, color: muted)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isCupertino ? CupertinoColors.label.resolveFrom(context) : null,
          ),
        ),
      ],
    );
  }
}

/// A node name after its country badge (flag and code, like the desktop's
/// code badge). On Android a long press tells where the country came from.
class NodeName extends StatelessWidget {
  const NodeName({super.key, required this.name, this.country, this.origin, this.ip, this.style, this.maxLines = 1});

  final String name;
  final String? country;

  /// `name`, `ip` or `exit` (see the bridge's `Member`).
  final String? origin;
  final String? ip;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = Text(name, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    if (country == null) return text;
    return Row(
      children: [
        CountryBadge(code: country!, origin: origin, ip: ip),
        const SizedBox(width: 8),
        Flexible(child: text),
      ],
    );
  }
}

class CountryBadge extends StatelessWidget {
  const CountryBadge({super.key, required this.code, this.origin, this.ip});

  final String code;
  final String? origin;
  final String? ip;

  String? get _source => switch (origin) {
    'name' => tr('geo.from_name'),
    'ip' => tr('geo.from_ip', [ip]),
    'exit' => tr('geo.from_exit', [ip]),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final muted = StatusColors.muted(context);
    final fill = isCupertino
        ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(5)),
      child: Text(
        '${flagEmoji(code)} $code',
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final source = _source;
    final labelled = Semantics(label: source == null ? code : '$code, $source', child: badge);
    // iOS has no tooltips; Android shows the source on long press.
    if (isCupertino || source == null) return labelled;
    return Tooltip(message: source, triggerMode: TooltipTriggerMode.longPress, child: labelled);
  }
}

/// The Auto strategy's explanation. The engine makes Auto's picks, and iOS pauses
/// it with the app, so the iPhone hint says so.
String autoHint(String strategy) {
  final hint = tr('auto.${strategy}_hint');
  return isCupertino ? '$hint ${tr('auto.ios_managed')}' : hint;
}
