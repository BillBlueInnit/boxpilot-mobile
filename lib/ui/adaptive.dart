// The app's small adaptive kit. Each widget renders the platform's own idiom:
// Material 3 on Android (large collapsing app bars, filled cards, dialogs,
// snackbars) and the iOS one on iPhone (Liquid Glass toolbar and tab bar on
// iOS 26, inset grouped lists, sheets, alerts, chevrons and checkmarks).

import 'dart:async';
import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

bool get isCupertino => PlatformInfo.isIOS;

/// An icon in both platform styles.
class AppIcon {
  const AppIcon(this.material, this.cupertino, [this.sfSymbol]);
  final IconData material;
  final IconData cupertino;

  /// SF Symbol for native iOS 26 bars.
  final String? sfSymbol;

  IconData get platform => isCupertino ? cupertino : material;
}

class PageMenuItem {
  const PageMenuItem(this.label, this.onSelected, {this.icon, this.destructive = false});
  final String label;
  final VoidCallback onSelected;
  final AppIcon? icon;
  final bool destructive;
}

/// A toolbar / app bar action: a button, or a menu when [menu] is set.
class PageAction {
  const PageAction({required this.icon, required this.label, this.onPressed, this.menu});
  final AppIcon icon;
  final String label;
  final VoidCallback? onPressed;
  final List<PageMenuItem>? menu;
}

/// A scrolling page with the platform's top bar.
///
/// Android: `SliverAppBar.large`, collapsing into a small bar as you scroll.
/// iOS: the native Liquid Glass toolbar (iOS 26), with a large title at the top
/// of the content that hands over to the toolbar title once scrolled away.
class AppPage extends StatefulWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.floatingActionButton,
    this.onRefresh,
    this.largeTitle = true,
    this.controller,
  });

  final String title;
  final List<Widget> slivers;
  final List<PageAction> actions;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final bool largeTitle;
  final ScrollController? controller;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  late final ScrollController _controller = widget.controller ?? ScrollController();
  bool _titleInBar = false;

  /// How far the scroll edge band under the iOS toolbar has faded in.
  final _edge = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    if (isCupertino) _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _edge.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _controller.hasClients ? _controller.offset : 0.0;
    _edge.value = (offset / 16).clamp(0.0, 1.0);
    if (!widget.largeTitle) return;
    final inBar = offset > 36;
    if (inBar != _titleInBar) setState(() => _titleInBar = inBar);
  }

  @override
  Widget build(BuildContext context) => isCupertino ? _cupertino(context) : _material(context);

  Widget _material(BuildContext context) {
    final actions = <Widget>[
      for (final a in widget.actions)
        if (a.menu == null)
          IconButton(icon: Icon(a.icon.material), tooltip: a.label, onPressed: a.onPressed)
        else
          PopupMenuButton<int>(
            icon: Icon(a.icon.material),
            tooltip: a.label,
            onSelected: (i) => a.menu![i].onSelected(),
            itemBuilder: (_) => [
              for (var i = 0; i < a.menu!.length; i++)
                PopupMenuItem(
                  value: i,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: a.menu![i].icon == null ? null : Icon(a.menu![i].icon!.material),
                    title: Text(a.menu![i].label),
                  ),
                ),
            ],
          ),
      const SizedBox(width: 4),
    ];
    final title = Text(widget.title);
    Widget scroll = CustomScrollView(
      controller: _controller,
      slivers: [
        if (widget.largeTitle)
          SliverAppBar.large(title: title, actions: actions)
        else
          SliverAppBar(title: title, actions: actions, pinned: true),
        ...widget.slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: widget.onRefresh!, edgeOffset: 152, child: scroll);
    }
    return Scaffold(body: scroll, floatingActionButton: widget.floatingActionButton);
  }

  Widget _cupertino(BuildContext context) {
    final showLarge = widget.largeTitle;
    final barTitle = !showLarge || _titleInBar ? widget.title : '';
    return AdaptiveScaffold(
      // Each page draws its own toolbar, so a sheet or a pushed page covers it.
      // The shared one above the navigator would sit on top of every sheet.
      useFixedToolbar: false,
      appBar: AdaptiveAppBar(
        title: barTitle,
        useNativeToolbar: true,
        actions: [
          for (final a in widget.actions)
            if (a.menu == null)
              AdaptiveAppBarAction(
                iosSymbol: a.icon.sfSymbol,
                icon: a.icon.cupertino,
                label: a.label,
                onPressed: a.onPressed ?? () {},
              )
            else
              AdaptiveAppBarAction(
                iosSymbol: a.icon.sfSymbol,
                icon: a.icon.cupertino,
                label: a.label,
                menuItems: [
                  for (final m in a.menu!)
                    AdaptivePopupMenuItem(label: m.label, icon: m.icon?.sfSymbol, isDestructive: m.destructive),
                ],
                onMenuItemSelected: (i, _) => a.menu![i].onSelected(),
              ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: showLarge
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: AnimatedOpacity(
                            opacity: _titleInBar ? 0 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              widget.title,
                              style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                            ),
                          ),
                        )
                      : const SizedBox(height: 8),
                ),
              ),
              if (widget.onRefresh != null) CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
              ...widget.slivers,
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _ScrollEdge(opacity: _edge),
        ],
      ),
    );
  }
}

/// The iOS 26 scroll edge effect under the toolbar: content scrolling up fades
/// into the page background instead of running into the bar's title and
/// buttons. UIKit draws it for its own scroll views only, so Flutter content
/// needs its own.
class _ScrollEdge extends StatelessWidget {
  const _ScrollEdge({required this.opacity});

  final ValueListenable<double> opacity;

  @override
  Widget build(BuildContext context) {
    // The scaffold has added the toolbar to the top padding.
    final top = MediaQuery.paddingOf(context).top;
    final height = top + 18;
    final background = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: opacity,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, (top - 10) / height, 1],
                colors: [background, background.withValues(alpha: 0.9), background.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- sections

/// A group of rows: a filled card under a header on Android, an inset grouped
/// list on iOS. Returns a sliver.
class Section extends StatelessWidget {
  const Section({super.key, this.header, this.footer, required this.children});

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SectionBox(header: header, footer: footer, children: children),
  );
}

/// [Section] as a plain box, for use inside other layouts.
class SectionBox extends StatelessWidget {
  const SectionBox({super.key, this.header, this.footer, required this.children});

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      // UIKit's grouped header and footer: footnote size, secondary label
      // colour, lined up with the rows' text (Flutter's inset grouped header
      // is a 20 pt bold title and its footer body-sized).
      final style = CupertinoTheme.of(context).textTheme.textStyle
          .copyWith(fontSize: 13, height: 1.3, color: CupertinoColors.secondaryLabel.resolveFrom(context));
      return CupertinoListSection.insetGrouped(
        header: header == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
                child: Text(header!, style: style),
              ),
        footer: footer == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 6),
                child: Text(footer!, style: style),
              ),
        hasLeading: false,
        children: children.isEmpty ? [const SizedBox.shrink()] : children,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(header!, style: text.titleSmall?.copyWith(color: scheme.primary)),
            ),
          Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Column(children: children),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(footer!, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- tiles

/// A row that opens something (chevron on iOS).
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final AppIcon? icon;
  final Color? iconColor;

  /// Current value, shown on the trailing side.
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      final red = CupertinoColors.destructiveRed.resolveFrom(context);
      return CupertinoListTile.notched(
        leading: icon == null ? null : _IosIconBadge(icon: icon!.cupertino, color: iconColor),
        title: Text(title, style: destructive ? TextStyle(color: red) : null),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2),
        // A long value gives way to the title, as in Settings.
        additionalInfo: value == null
            ? null
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
                child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
        trailing: trailing ?? (chevron && onTap != null ? const CupertinoListTileChevron() : null),
        onTap: onTap,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: icon == null
          ? null
          : Icon(icon!.material, color: destructive ? scheme.error : iconColor ?? scheme.onSurfaceVariant),
      title: Text(title, style: destructive ? TextStyle(color: scheme.error) : null),
      subtitle: subtitle == null && value == null
          ? null
          : Text(subtitle ?? value!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          (subtitle != null && value != null ? Text(value!, style: TextStyle(color: scheme.onSurfaceVariant)) : null),
      onTap: onTap,
    );
  }
}

/// The coloured rounded-square icon of iOS Settings rows.
class _IosIconBadge extends StatelessWidget {
  const _IosIconBadge({required this.icon, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color ?? CupertinoTheme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 18, color: CupertinoColors.white),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final AppIcon? icon;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoListTile.notched(
        leading: icon == null ? null : _IosIconBadge(icon: icon!.cupertino, color: iconColor),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 3),
        trailing: inSheet(context)
            ? CupertinoSwitch(value: value, onChanged: onChanged)
            : AdaptiveSwitch(value: value, onChanged: onChanged),
        onTap: onChanged == null ? null : () => onChanged!(!value),
      );
    }
    return SwitchListTile(
      secondary: icon == null ? null : Icon(icon!.material),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A row picking one of [options]. Android: a dialog with radio buttons.
/// iOS: a pushed list with a checkmark, like Settings.
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final AppIcon? icon;
  final Color? iconColor;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options[value] ?? '$value';
    return NavTile(
      title: title,
      subtitle: isCupertino ? null : current,
      icon: icon,
      iconColor: iconColor,
      value: isCupertino ? current : null,
      onTap: () async {
        final picked = await pickOption<T>(context, title: title, value: value, options: options, footer: subtitle);
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required T value,
  required Map<T, String> options,
  String? footer,
}) {
  if (isCupertino) {
    final inSheet = _SheetScroll.maybeOf(context) != null;
    Widget list(BuildContext context) => SectionBox(
      footer: footer,
      children: [
        for (final e in options.entries)
          CupertinoListTile(
            title: Text(e.value),
            trailing: e.key == value
                ? Icon(CupertinoIcons.check_mark, color: CupertinoTheme.of(context).primaryColor)
                : null,
            onTap: () => Navigator.of(context).pop(e.key),
          ),
      ],
    );
    return Navigator.of(context).push<T>(
      CupertinoPageRoute(
        builder: (context) => inSheet
            // Inside a sheet the app's glass toolbar is hidden behind it; use the sheet's own bar.
            ? CupertinoPageScaffold(
                backgroundColor: CupertinoColors.systemGroupedBackground,
                navigationBar: CupertinoNavigationBar(middle: Text(title)),
                child: SafeArea(child: ListView(children: [list(context)])),
              )
            : AppPage(
                title: title,
                largeTitle: false,
                slivers: [SliverToBoxAdapter(child: list(context))],
              ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: SingleChildScrollView(
        child: RadioGroup<T>(
          groupValue: value,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in options.entries) RadioListTile<T>(value: e.key, title: Text(e.value)),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(footer, style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('btn.cancel')))],
    ),
  );
}

/// A row with a text value, edited in a dialog.
class TextTile extends StatelessWidget {
  const TextTile({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.iconColor,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.keyboardType,
    this.validator,
    this.multiline = false,
    this.display,
  });

  final String title;
  final String? description;
  final AppIcon? icon;
  final Color? iconColor;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;
  final String? Function(String)? validator;
  final bool multiline;

  /// How the value is shown in the row (defaults to the value).
  final String? display;

  @override
  Widget build(BuildContext context) {
    final shown = display ?? (value.isEmpty ? (placeholder ?? '') : value);
    return NavTile(
      title: title,
      subtitle: isCupertino ? description : shown,
      icon: icon,
      iconColor: iconColor,
      value: isCupertino ? (multiline ? null : shown) : null,
      onTap: () async {
        final text = await promptText(
          context,
          title: title,
          message: description,
          initial: value,
          placeholder: placeholder,
          keyboardType: keyboardType,
          validator: validator,
          multiline: multiline,
        );
        if (text != null && text != value) onChanged(text);
      },
    );
  }
}

/// Asks for a line (or block) of text. `null` when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  String initial = '',
  String? placeholder,
  TextInputType? keyboardType,
  String? Function(String)? validator,
  bool multiline = false,
  String? confirmLabel,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    builder: (context) => _TextPrompt(
      title: title,
      message: message,
      initial: initial,
      placeholder: placeholder,
      keyboardType: keyboardType,
      validator: validator,
      multiline: multiline,
      confirmLabel: confirmLabel ?? tr('btn.save'),
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    this.message,
    required this.initial,
    this.placeholder,
    this.keyboardType,
    this.validator,
    required this.multiline,
    required this.confirmLabel,
  });

  final String title;
  final String? message;
  final String initial;
  final String? placeholder;
  final TextInputType? keyboardType;
  final String? Function(String)? validator;
  final bool multiline;
  final String confirmLabel;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  void _submit() {
    final text = _controller.text.trim();
    final error = widget.validator?.call(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.multiline ? 6 : 1;
    if (isCupertino) {
      return CupertinoAlertDialog(
        title: Text(widget.title),
        content: Column(
          children: [
            if (widget.message != null)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.message!)),
            CupertinoTextField(
              controller: _controller,
              placeholder: widget.placeholder,
              keyboardType: widget.multiline ? TextInputType.multiline : widget.keyboardType,
              autofocus: true,
              minLines: lines,
              maxLines: lines,
              autocorrect: false,
              onSubmitted: widget.multiline ? null : (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context), fontSize: 13),
                ),
              ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(), child: Text(tr('btn.cancel'))),
          CupertinoDialogAction(isDefaultAction: true, onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(widget.message!)),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: widget.multiline ? TextInputType.multiline : widget.keyboardType,
              minLines: lines,
              maxLines: lines,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: widget.multiline ? null : (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('btn.cancel'))),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// A yes/no question. Native alert on iOS 26, Material dialog on Android.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = Completer<bool>();
  await AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(title: tr('btn.cancel'), style: AlertActionStyle.cancel, onPressed: () => result.complete(false)),
      AlertAction(
        title: confirmLabel,
        style: destructive ? AlertActionStyle.destructive : AlertActionStyle.primary,
        onPressed: () => result.complete(true),
      ),
    ],
  );
  return result.isCompleted ? result.future : false;
}

// ---------------------------------------------------------------- forms

/// A labelled text field inside a form [SectionBox].
class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.helper,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final String? helper;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String)? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    String? validate(String? v) => validator?.call((v ?? '').trim());
    if (isCupertino) {
      if (maxLines > 1) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: CupertinoTheme.of(context).textTheme.textStyle
                    .copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
              const SizedBox(height: 6),
              CupertinoTextFormFieldRow(
                controller: controller,
                placeholder: placeholder,
                padding: EdgeInsets.zero,
                keyboardType: TextInputType.multiline,
                minLines: 4,
                maxLines: maxLines,
                autocorrect: false,
                validator: validate,
                autofocus: autofocus,
              ),
            ],
          ),
        );
      }
      return CupertinoTextFormFieldRow(
        prefix: SizedBox(width: 110, child: Text(label)),
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        autocorrect: false,
        validator: validate,
        autofocus: autofocus,
        textAlign: TextAlign.start,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextFormField(
        controller: controller,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
        minLines: maxLines > 1 ? 4 : 1,
        maxLines: maxLines,
        autocorrect: false,
        autofocus: autofocus,
        validator: validate,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Opens a form: a full-screen dialog on Android, a sheet on iOS.
Future<T?> openForm<T>(BuildContext context, WidgetBuilder builder) {
  if (isCupertino) {
    // Nested navigation: pickers opened from the form slide in inside the sheet.
    return showCupertinoSheet<T>(
      context: context,
      useNestedNavigation: true,
      scrollableBuilder: (context, controller) => _SheetScroll(controller: controller, child: builder(context)),
    );
  }
  return Navigator.of(context).push<T>(MaterialPageRoute(fullscreenDialog: true, builder: builder));
}

/// Whether [context] is inside a form sheet opened with [openForm].
///
/// Native iOS controls (platform views) are not used in sheets: under the
/// sheet's clip and transition the Flutter content around them stopped being
/// drawn. The Flutter-drawn Cupertino controls take their place there.
bool inSheet(BuildContext context) => _SheetScroll.maybeOf(context) != null;

/// A segmented control: native on iOS 26 pages, Flutter-drawn in sheets
/// (see [inSheet]), the Material one on Android.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.labels, required this.selectedIndex, required this.onValueChanged});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onValueChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino && inSheet(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: selectedIndex,
          onValueChanged: (i) {
            if (i != null) onValueChanged(i);
          },
          children: {
            for (var i = 0; i < labels.length; i++)
              i: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(labels[i])),
          },
        ),
      );
    }
    return AdaptiveSegmentedControl(labels: labels, selectedIndex: selectedIndex, onValueChanged: onValueChanged);
  }
}

/// The sheet's scroll controller, so dragging the form down dismisses the sheet.
class _SheetScroll extends InheritedWidget {
  const _SheetScroll({required this.controller, required super.child});

  final ScrollController controller;

  static ScrollController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetScroll>()?.controller;

  @override
  bool updateShouldNotify(_SheetScroll old) => old.controller != controller;
}

/// The frame of a form opened with [openForm]: Cancel / title / Save.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.saveLabel,
    required this.onSave,
    required this.children,
    this.formKey,
    this.saving = false,
  });

  final String title;
  final String saveLabel;
  final VoidCallback? onSave;
  final List<Widget> children;
  final GlobalKey<FormState>? formKey;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final body = Form(
      key: formKey,
      child: ListView(
        controller: _SheetScroll.maybeOf(context),
        padding: const EdgeInsets.only(bottom: 32),
        children: children,
      ),
    );
    if (isCupertino) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('btn.cancel')),
          ),
          middle: Text(title),
          trailing: saving
              ? const CupertinoActivityIndicator()
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onSave,
                  child: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
        ),
        child: SafeArea(
          child: Material(type: MaterialType.transparency, child: body),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: tr('btn.cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: saving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : FilledButton(onPressed: onSave, child: Text(saveLabel)),
          ),
        ],
      ),
      body: body,
    );
  }
}

// -------------------------------------------------------------- notices

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// A short message: a snackbar on Android, a glass banner on iOS.
void showNotice(String text, {bool error = false}) {
  if (!isCupertino) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, showCloseIcon: error));
    return;
  }
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GlassBanner(text: text, error: error, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _GlassBanner extends StatefulWidget {
  const _GlassBanner({required this.text, required this.error, required this.onDone});
  final String text;
  final bool error;
  final VoidCallback onDone;

  @override
  State<_GlassBanner> createState() => _GlassBannerState();
}

class _GlassBannerState extends State<_GlassBanner> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void initState() {
    super.initState();
    _anim.forward();
    Future.delayed(Duration(milliseconds: widget.error ? 4200 : 2600), () async {
      if (!mounted) return;
      await _anim.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 6,
      left: 24,
      right: 24,
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(curve),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: (dark ? const Color(0xFF2C2C2E) : CupertinoColors.white).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: (dark ? CupertinoColors.white : CupertinoColors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.error
                              ? CupertinoIcons.exclamationmark_circle_fill
                              : CupertinoIcons.checkmark_circle_fill,
                          size: 20,
                          color: widget.error ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.text,
                            style: TextStyle(
                              fontSize: 15,
                              color: dark ? CupertinoColors.white : CupertinoColors.black,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered message for empty or offline pages. Returns a sliver.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final AppIcon icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = isCupertino
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final titleStyle = isCupertino
        ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontSize: 20)
        : Theme.of(context).textTheme.titleLarge;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon.platform, size: 56, color: secondary),
            const SizedBox(height: 16),
            Text(title, style: titleStyle, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: secondary),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// A lazily built grouped list (hundreds of nodes): inset grouped rows on iOS,
/// a rounded container on Android. [header] sits above it.
class SliverGroupedList extends StatelessWidget {
  const SliverGroupedList({super.key, this.header, required this.itemCount, required this.itemBuilder});

  final Widget? header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final horizontal = isCupertino ? 20.0 : 16.0;
    final background = isCupertino
        ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
        : Theme.of(context).colorScheme.surfaceContainer;
    final radius = isCupertino ? 26.0 : 24.0;
    final divider = isCupertino
        ? CupertinoColors.separator.resolveFrom(context)
        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5);
    return SliverMainAxisGroup(
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12),
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: (context, i) {
              final first = i == 0, last = i == itemCount - 1;
              return Container(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.vertical(
                    top: first ? Radius.circular(radius) : Radius.zero,
                    bottom: last ? Radius.circular(radius) : Radius.zero,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(type: MaterialType.transparency, child: itemBuilder(context, i)),
                    if (!last)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Container(height: 0.5, color: divider),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A search field: `SearchBar` on Android, `CupertinoSearchTextField` on iOS.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.placeholder, required this.onChanged, this.controller});

  final String placeholder;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: CupertinoSearchTextField(controller: controller, placeholder: placeholder, onChanged: onChanged),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SearchBar(
        controller: controller,
        hintText: placeholder,
        leading: const Icon(Icons.search),
        elevation: const WidgetStatePropertyAll(0),
        onChanged: onChanged,
      ),
    );
  }
}
