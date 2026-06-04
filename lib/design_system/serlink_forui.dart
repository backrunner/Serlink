import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'serlink_context.dart';
import 'serlink_dimensions.dart';
import 'serlink_effects.dart';

enum SerlinkButtonVariant { primary, secondary, outline, ghost, danger }

enum SerlinkButtonSize { xs, sm, md, lg }

Future<T?> showSerlinkDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  return showFDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    builder: (context, _, _) => builder(context),
  );
}

class SerlinkDialog extends StatelessWidget {
  const SerlinkDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.constraints,
    this.maxWidth = 920,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final BoxConstraints? constraints;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FDialog.raw(
      clipBehavior: Clip.antiAlias,
      constraints:
          constraints ??
          BoxConstraints(minWidth: math.min(360, maxWidth), maxWidth: maxWidth),
      builder: (context, style) {
        final contentStyle = style.contentStyle.horizontal;
        final titleStyle = contentStyle.titleTextStyle.copyWith(
          color: t.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.2,
        );
        final bodyStyle = contentStyle.bodyTextStyle.copyWith(
          color: t.textSecondary,
          fontSize: 13.5,
          height: 1.42,
        );
        return DefaultTextStyle.merge(
          style: TextStyle(color: t.textPrimary),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding:
                      titlePadding ?? const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: DefaultTextStyle.merge(
                    style: titleStyle,
                    child: title!,
                  ),
                ),
              if (content != null)
                Flexible(
                  child: Padding(
                    padding:
                        contentPadding ??
                        const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: DefaultTextStyle.merge(
                      style: bodyStyle,
                      child: content!,
                    ),
                  ),
                ),
              if (actions.isNotEmpty)
                Padding(
                  padding:
                      actionsPadding ??
                      const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: actions,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SerlinkFilledButton extends StatelessWidget {
  const SerlinkFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null,
       label = null,
       variant = SerlinkButtonVariant.primary;

  const SerlinkFilledButton.tonal({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null,
       label = null,
       variant = SerlinkButtonVariant.secondary;

  const SerlinkFilledButton.danger({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null,
       label = null,
       variant = SerlinkButtonVariant.danger;

  const SerlinkFilledButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  }) : child = null,
       variant = SerlinkButtonVariant.primary;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final SerlinkButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return _SerlinkButtonCore(
      onPressed: onPressed,
      variant: variant,
      size: SerlinkButtonSize.lg,
      prefix: icon,
      child: child ?? label!,
    );
  }
}

class SerlinkOutlinedButton extends StatelessWidget {
  const SerlinkOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null,
       label = null;

  const SerlinkOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return _SerlinkButtonCore(
      onPressed: onPressed,
      variant: SerlinkButtonVariant.outline,
      size: SerlinkButtonSize.lg,
      prefix: icon,
      child: child ?? label!,
    );
  }
}

class SerlinkTextButton extends StatelessWidget {
  const SerlinkTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null,
       label = null,
       danger = false;

  const SerlinkTextButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  }) : child = null,
       danger = false;

  const SerlinkTextButton.danger({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null,
       label = null,
       danger = true;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return _SerlinkButtonCore(
      onPressed: onPressed,
      variant: danger
          ? SerlinkButtonVariant.danger
          : SerlinkButtonVariant.ghost,
      size: SerlinkButtonSize.lg,
      prefix: icon,
      child: child ?? label!,
    );
  }
}

class SerlinkIconButton extends StatelessWidget {
  const SerlinkIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.style,
    this.padding,
    this.constraints,
    this.visualDensity,
    this.splashRadius,
    this.iconSize,
    this.color,
    this.selectedIcon,
    this.isSelected,
    this.variant = SerlinkButtonVariant.ghost,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;
  final double? splashRadius;
  final double? iconSize;
  final Color? color;
  final Widget? selectedIcon;
  final bool? isSelected;
  final SerlinkButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = isSelected == true && selectedIcon != null
        ? selectedIcon!
        : icon;
    final styleStates = <WidgetState>{
      if (onPressed == null) WidgetState.disabled,
      if (isSelected == true) WidgetState.selected,
    };
    final styleFixedSize = style?.fixedSize?.resolve(styleStates);
    final styleMinimumSize = style?.minimumSize?.resolve(styleStates);
    final stylePadding = style?.padding?.resolve(styleStates);
    final styleColor = style?.foregroundColor?.resolve(styleStates);
    final side =
        _iconButtonSide(constraints) ??
        _sizeSide(styleFixedSize) ??
        _sizeSide(styleMinimumSize);
    Widget button = FButton.icon(
      onPress: onPressed,
      variant: _foruiButtonVariant(variant),
      size: _iconButtonSize(side),
      selected: isSelected ?? false,
      style: FButtonStyleDelta.delta(
        iconContentStyle: FButtonIconContentStyleDelta.delta(
          constraints: side == null
              ? null
              : BoxConstraints.tight(Size.square(side)),
          padding: EdgeInsetsGeometryDelta.value(
            padding ?? stylePadding ?? EdgeInsets.zero,
          ),
        ),
      ),
      child: IconTheme.merge(
        data: IconThemeData(size: iconSize, color: color ?? styleColor),
        child: resolvedIcon,
      ),
    );
    if (tooltip case final tooltip?) {
      button = FTooltip(
        tipBuilder: (context, _) => Text(tooltip),
        child: Semantics(label: tooltip, button: true, child: button),
      );
    }
    return button;
  }
}

class SerlinkTooltip extends StatelessWidget {
  const SerlinkTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FTooltip(
      tipBuilder: (context, _) => Text(message),
      child: Semantics(label: message, child: child),
    );
  }
}

class SerlinkLoadingIndicator extends StatelessWidget {
  const SerlinkLoadingIndicator({super.key, this.semanticsLabel});

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return FCircularProgress(
      size: FCircularProgressSizeVariant.lg,
      semanticsLabel: semanticsLabel,
    );
  }
}

class SerlinkMenuAction {
  const SerlinkMenuAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

class SerlinkMenuButton extends StatelessWidget {
  const SerlinkMenuButton({
    super.key,
    required this.actions,
    required this.icon,
    this.tooltip,
    this.enabled = true,
  });

  final List<SerlinkMenuAction> actions;
  final Widget icon;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FPopoverMenu(
      menuBuilder: (context, controller, _) => [
        FItemGroup(
          children: [
            for (final action in actions)
              FItem(
                title: Text(action.label),
                prefix: action.icon == null
                    ? null
                    : Icon(action.icon, size: 16),
                onPress: () {
                  controller.hide();
                  action.onPressed();
                },
              ),
          ],
        ),
      ],
      builder: (context, controller, _) => SerlinkIconButton(
        tooltip: tooltip,
        onPressed: enabled ? controller.toggle : null,
        icon: icon,
      ),
    );
  }
}

class SerlinkContextMenu extends StatefulWidget {
  const SerlinkContextMenu({
    super.key,
    required this.actions,
    required this.child,
    this.enabled = true,
  });

  final List<SerlinkMenuAction> actions;
  final Widget child;
  final bool enabled;

  @override
  State<SerlinkContextMenu> createState() => _SerlinkContextMenuState();
}

class _SerlinkContextMenuState extends State<SerlinkContextMenu> {
  static const double _menuWidth = 184;
  static const double _rowHeight = 38;
  static const double _verticalPadding = 6;
  static const double _screenMargin = 8;

  OverlayEntry? _entry;

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
  }

  void _showMenuAt(Offset globalPosition) {
    if (!widget.enabled || widget.actions.isEmpty) {
      return;
    }
    _hideMenu();

    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null || overlayBox == null || !overlayBox.hasSize) {
      return;
    }

    final overlaySize = overlayBox.size;
    final localPosition = overlayBox.globalToLocal(globalPosition);
    final availableWidth = math.max(0.0, overlaySize.width - _screenMargin * 2);
    final availableHeight = math.max(
      _rowHeight,
      overlaySize.height - _screenMargin * 2,
    );
    final menuWidth = math.min(_menuWidth, availableWidth);
    final naturalHeight =
        widget.actions.length * _rowHeight + _verticalPadding * 2;
    final menuHeight = math.min(naturalHeight, availableHeight);

    var left = localPosition.dx;
    if (left + menuWidth + _screenMargin > overlaySize.width) {
      left = localPosition.dx - menuWidth;
    }
    final maxLeft = math.max(
      _screenMargin,
      overlaySize.width - menuWidth - _screenMargin,
    );
    left = left.clamp(_screenMargin, maxLeft).toDouble();

    var top = localPosition.dy;
    if (top + menuHeight + _screenMargin > overlaySize.height) {
      top = localPosition.dy - menuHeight;
    }
    final maxTop = math.max(
      _screenMargin,
      overlaySize.height - menuHeight - _screenMargin,
    );
    top = top.clamp(_screenMargin, maxTop).toDouble();

    _entry = OverlayEntry(
      builder: (context) => _SerlinkContextMenuOverlay(
        left: left,
        top: top,
        width: menuWidth,
        maxHeight: menuHeight,
        actions: widget.actions,
        onDismiss: _hideMenu,
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: widget.enabled
          ? (details) => _showMenuAt(details.globalPosition)
          : null,
      onLongPressStart: widget.enabled
          ? (details) => _showMenuAt(details.globalPosition)
          : null,
      child: widget.child,
    );
  }
}

class _SerlinkContextMenuOverlay extends StatelessWidget {
  const _SerlinkContextMenuOverlay({
    required this.left,
    required this.top,
    required this.width,
    required this.maxHeight,
    required this.actions,
    required this.onDismiss,
  });

  final double left;
  final double top;
  final double width;
  final double maxHeight;
  final List<SerlinkMenuAction> actions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            onSecondaryTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.surfaceRaised,
                borderRadius: SerlinkRadii.control,
                border: Border.all(color: t.borderSubtle),
                boxShadow: serlinkShadow(t, elevation: 12),
              ),
              child: ClipRRect(
                borderRadius: SerlinkRadii.control,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in actions)
                        _SerlinkContextMenuItem(
                          action: action,
                          onSelected: () {
                            onDismiss();
                            action.onPressed();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SerlinkContextMenuItem extends StatefulWidget {
  const _SerlinkContextMenuItem({
    required this.action,
    required this.onSelected,
  });

  final SerlinkMenuAction action;
  final VoidCallback onSelected;

  @override
  State<_SerlinkContextMenuItem> createState() =>
      _SerlinkContextMenuItemState();
}

class _SerlinkContextMenuItemState extends State<_SerlinkContextMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            height: _SerlinkContextMenuState._rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _hovered
                  ? t.accentPrimary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                if (widget.action.icon != null) ...[
                  Icon(widget.action.icon, size: 16, color: t.textSecondary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SerlinkTextField extends StatelessWidget {
  const SerlinkTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.expands = false,
    this.readOnly = false,
    this.enabled = true,
    this.inputFormatters,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.selectAllOnFocus,
    this.scrollController,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool expands;
  final bool readOnly;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final GestureTapCallback? onTap;
  final bool? selectAllOnFocus;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final inputDecoration = decoration ?? const InputDecoration();
    final collapsed = inputDecoration.isCollapsed ?? false;
    final borderless =
        inputDecoration.border == InputBorder.none ||
        inputDecoration.enabledBorder == InputBorder.none;
    if (collapsed && borderless) {
      return _SerlinkInlineTextInput(
        controller: controller,
        focusNode: focusNode,
        hint: inputDecoration.hintText,
        hintStyle: inputDecoration.hintStyle,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        textAlign: textAlign,
        autofocus: autofocus,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        expands: expands,
        readOnly: readOnly,
        enabled: enabled,
        inputFormatters: inputFormatters,
        style: style,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onEditingComplete: onEditingComplete,
        onTap: onTap,
        selectAllOnFocus: selectAllOnFocus,
        scrollController: scrollController,
      );
    }
    return FTextField(
      control: FTextFieldControl.managed(
        controller: controller,
        onChange: (value) => onChanged?.call(value.text),
      ),
      size: collapsed ? FTextFieldSizeVariant.sm : FTextFieldSizeVariant.lg,
      label: inputDecoration.labelText == null
          ? null
          : Text(inputDecoration.labelText!),
      hint: inputDecoration.hintText,
      description: inputDecoration.helperText == null
          ? null
          : Text(inputDecoration.helperText!),
      error: inputDecoration.errorText == null
          ? null
          : Text(inputDecoration.errorText!),
      prefixBuilder: inputDecoration.prefixIcon == null
          ? null
          : (context, fieldStyle, variants) => FTextField.prefixIconBuilder(
              context,
              fieldStyle,
              variants,
              inputDecoration.prefixIcon!,
            ),
      suffixBuilder: inputDecoration.suffixIcon == null
          ? null
          : (context, fieldStyle, variants) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: IconTheme(
                data: fieldStyle.iconStyle.resolve(variants),
                child: inputDecoration.suffixIcon!,
              ),
            ),
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      expands: expands,
      readOnly: readOnly,
      enabled: enabled,
      inputFormatters: inputFormatters,
      onSubmit: onSubmitted,
      onEditingComplete: onEditingComplete,
      onTap: onTap,
      selectAllOnFocus: selectAllOnFocus,
      scrollController: scrollController,
      style: _textFieldStyleDelta(
        textStyle: style,
        hintStyle: inputDecoration.hintStyle,
        contentPadding: inputDecoration.contentPadding,
        borderless: borderless,
        collapsed: collapsed,
      ),
    );
  }
}

class _SerlinkInlineTextInput extends StatefulWidget {
  const _SerlinkInlineTextInput({
    this.controller,
    this.focusNode,
    this.hint,
    this.hintStyle,
    this.keyboardType,
    this.textInputAction,
    required this.textCapitalization,
    required this.textAlign,
    required this.autofocus,
    required this.obscureText,
    required this.autocorrect,
    required this.enableSuggestions,
    this.minLines,
    this.maxLines,
    this.maxLength,
    required this.expands,
    required this.readOnly,
    required this.enabled,
    this.inputFormatters,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.selectAllOnFocus,
    this.scrollController,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final TextStyle? hintStyle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool expands;
  final bool readOnly;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final GestureTapCallback? onTap;
  final bool? selectAllOnFocus;
  final ScrollController? scrollController;

  @override
  State<_SerlinkInlineTextInput> createState() =>
      _SerlinkInlineTextInputState();
}

class _SerlinkInlineTextInputState extends State<_SerlinkInlineTextInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsController;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(_SerlinkInlineTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TextEditingController();
      _ownsController = widget.controller == null;
      _controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChanged() {
    if (widget.selectAllOnFocus == true && _focusNode.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final baseStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    final textStyle = baseStyle.copyWith(
      color: widget.enabled ? baseStyle.color ?? t.textPrimary : t.textMuted,
      height: baseStyle.height ?? 1.2,
    );
    final hintStyle = textStyle
        .copyWith(color: t.textMuted)
        .merge(widget.hintStyle);
    final showHint =
        widget.hint != null &&
        widget.hint!.isNotEmpty &&
        _controller.text.isEmpty;
    final inputFormatters = [
      ...?widget.inputFormatters,
      if (widget.maxLength case final maxLength?)
        LengthLimitingTextInputFormatter(maxLength),
    ];
    final field = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      child: EditableText(
        controller: _controller,
        focusNode: _focusNode,
        readOnly: widget.readOnly || !widget.enabled,
        showCursor: widget.enabled && !widget.readOnly,
        autofocus: widget.autofocus && widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        textAlign: widget.textAlign,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        minLines: widget.minLines,
        maxLines: widget.expands ? null : widget.maxLines,
        expands: widget.expands,
        inputFormatters: inputFormatters.isEmpty ? null : inputFormatters,
        scrollController: widget.scrollController,
        style: textStyle,
        cursorColor: t.accentPrimary,
        backgroundCursorColor: Colors.transparent,
        selectionColor: t.accentPrimary.withValues(alpha: 0.22),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: widget.onEditingComplete,
      ),
    );
    return Focus(
      canRequestFocus: widget.enabled,
      descendantsAreFocusable: widget.enabled,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            field,
            if (showHint)
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Text(
                    widget.hint!,
                    overflow: TextOverflow.ellipsis,
                    style: hintStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SerlinkTextFormField extends StatelessWidget {
  const SerlinkTextFormField({
    super.key,
    this.controller,
    this.decoration,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return SerlinkTextField(
      controller: controller,
      decoration: decoration,
      textInputAction: textInputAction,
      onSubmitted: onFieldSubmitted,
    );
  }
}

class SerlinkSwitch extends StatelessWidget {
  const SerlinkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return _SerlinkSwitchFrame(
      value: value,
      onChanged: onChanged,
      semanticsLabel: semanticsLabel,
    );
  }
}

const double _serlinkSwitchScale = 0.72;
const double _serlinkSwitchBaseWidth = 59;
const double _serlinkSwitchBaseHeight = 39;
const Size _serlinkSwitchBaseSize = Size(
  _serlinkSwitchBaseWidth,
  _serlinkSwitchBaseHeight,
);
const Size _serlinkSwitchSize = Size(
  _serlinkSwitchBaseWidth * _serlinkSwitchScale,
  _serlinkSwitchBaseHeight * _serlinkSwitchScale,
);

class _SerlinkSwitchFrame extends StatelessWidget {
  const _SerlinkSwitchFrame({
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _serlinkSwitchSize,
      child: OverflowBox(
        minWidth: _serlinkSwitchBaseSize.width,
        maxWidth: _serlinkSwitchBaseSize.width,
        minHeight: _serlinkSwitchBaseSize.height,
        maxHeight: _serlinkSwitchBaseSize.height,
        child: Transform.scale(
          scale: _serlinkSwitchScale,
          child: FSwitch(
            value: value,
            onChange: onChanged,
            enabled: onChanged != null,
            semanticsLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}

class SerlinkCheckbox extends StatelessWidget {
  const SerlinkCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FCheckbox(
      value: value ?? false,
      enabled: onChanged != null,
      onChange: onChanged == null ? null : (value) => onChanged!(value),
    );
  }
}

class SerlinkCheckboxListTile extends StatelessWidget {
  const SerlinkCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
    this.dense,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: contentPadding ?? EdgeInsets.zero,
      child: FCheckbox(
        value: value ?? false,
        onChange: onChanged == null ? null : (value) => onChanged!(value),
        enabled: onChanged != null,
        label: title,
        description: subtitle,
      ),
    );
  }
}

class SerlinkSwitchListTile extends StatelessWidget {
  const SerlinkSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onChanged != null;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? t.textPrimary : t.textMuted,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: enabled ? t.textSecondary : t.textMuted,
      fontSize: 12.2,
      height: 1.28,
    );

    return Padding(
      padding: contentPadding ?? EdgeInsets.zero,
      child: MergeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: subtitle == null ? 0 : 1),
                child: SerlinkSwitch(value: value, onChanged: onChanged),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DefaultTextStyle.merge(style: titleStyle, child: title),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(
                        style: subtitleStyle,
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SerlinkButtonCore extends StatelessWidget {
  const _SerlinkButtonCore({
    required this.onPressed,
    required this.variant,
    required this.size,
    required this.child,
    this.prefix,
  });

  final VoidCallback? onPressed;
  final SerlinkButtonVariant variant;
  final SerlinkButtonSize size;
  final Widget child;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    return FButton(
      onPress: onPressed,
      variant: _foruiButtonVariant(variant),
      size: _foruiButtonSize(size),
      mainAxisSize: MainAxisSize.min,
      prefix: prefix,
      child: child,
    );
  }
}

FButtonVariant _foruiButtonVariant(SerlinkButtonVariant variant) {
  return switch (variant) {
    SerlinkButtonVariant.primary => FButtonVariant.primary,
    SerlinkButtonVariant.secondary => FButtonVariant.secondary,
    SerlinkButtonVariant.outline => FButtonVariant.outline,
    SerlinkButtonVariant.ghost => FButtonVariant.ghost,
    SerlinkButtonVariant.danger => FButtonVariant.destructive,
  };
}

FButtonSizeVariant _foruiButtonSize(SerlinkButtonSize size) {
  return switch (size) {
    SerlinkButtonSize.xs => FButtonSizeVariant.xs,
    SerlinkButtonSize.sm => FButtonSizeVariant.sm,
    SerlinkButtonSize.md => FButtonSizeVariant.md,
    SerlinkButtonSize.lg => FButtonSizeVariant.lg,
  };
}

FButtonSizeVariant _iconButtonSize(double? side) {
  if (side == null) {
    return FButtonSizeVariant.sm;
  }
  if (side <= 24) {
    return FButtonSizeVariant.xs;
  }
  if (side <= 32) {
    return FButtonSizeVariant.sm;
  }
  if (side <= 36) {
    return FButtonSizeVariant.md;
  }
  return FButtonSizeVariant.lg;
}

double? _iconButtonSide(BoxConstraints? constraints) {
  if (constraints == null) {
    return null;
  }
  final width = constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : constraints.minWidth;
  final height = constraints.maxHeight.isFinite
      ? constraints.maxHeight
      : constraints.minHeight;
  final side = width == 0 ? height : (height == 0 ? width : width);
  if (side <= 0 || side.isInfinite) {
    return null;
  }
  return side;
}

double? _sizeSide(Size? size) {
  if (size == null) {
    return null;
  }
  final side = size.shortestSide;
  if (side <= 0 || side.isInfinite) {
    return null;
  }
  return side;
}

FVariantsDelta<
  FTextFieldVariantConstraint,
  FTextFieldVariant,
  TextStyle,
  TextStyleDelta
>
_textFieldTextStyleDelta(TextStyle style) {
  return FVariantsDelta.delta([
    FVariantOperation.all(TextStyleDelta.value(style)),
  ]);
}

FTextFieldStyleDelta _textFieldStyleDelta({
  required TextStyle? textStyle,
  required TextStyle? hintStyle,
  required EdgeInsetsGeometry? contentPadding,
  required bool borderless,
  required bool collapsed,
}) {
  return FTextFieldStyleDelta.delta(
    contentPadding: contentPadding == null && !collapsed
        ? null
        : EdgeInsetsGeometryDelta.value(contentPadding ?? EdgeInsets.zero),
    color: borderless ? _textFieldColorDelta(Colors.transparent) : null,
    border: borderless ? _textFieldBorderDelta(InputBorder.none) : null,
    contentTextStyle: textStyle == null
        ? null
        : _textFieldTextStyleDelta(textStyle),
    hintTextStyle: hintStyle == null
        ? null
        : _textFieldTextStyleDelta(hintStyle),
  );
}

FVariantsValueDelta<
  FTextFieldVariantConstraint,
  FTextFieldVariant,
  Color?,
  Delta
>
_textFieldColorDelta(Color color) {
  return FVariantsValueDelta.delta([FVariantValueDeltaOperation.all(color)]);
}

FVariantsValueDelta<
  FTextFieldVariantConstraint,
  FTextFieldVariant,
  InputBorder,
  Delta
>
_textFieldBorderDelta(InputBorder border) {
  return FVariantsValueDelta.delta([FVariantValueDeltaOperation.all(border)]);
}
