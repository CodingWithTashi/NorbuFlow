import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// A labelled text input whose text is owned by a view model.
///
/// The field is "controlled": [value] is the source of truth, so when the
/// view model replaces it (a template is chosen, a draft is regenerated) the
/// field follows without each screen managing a controller.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.labelMuted = false,
    this.optionalTag,
    this.hint,
    this.errorText,
    this.leading,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    this.fontSize = 18,
    this.documentStyle = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;

  /// Renders the label as a quiet caption rather than a bold heading.
  final bool labelMuted;
  final String? optionalTag;
  final String? hint;
  final String? errorText;

  /// Sits before the input and is as tall as it: a country code, a unit.
  final Widget? leading;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;
  final double fontSize;

  /// Light "paper" look in every theme, for text that will be printed.
  final bool documentStyle;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final multiline = (widget.maxLines ?? 2) > 1;
    final errorBorder = widget.errorText == null
        ? null
        : OutlineInputBorder(
            borderRadius: AppTheme.fieldRadius,
            borderSide: BorderSide(color: colors.error, width: 1.5),
          );

    // An address is kept as typed: the keyboard must not correct it.
    final asTyped = widget.keyboardType == TextInputType.emailAddress;
    final field = TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType:
          widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autocorrect: !asTyped,
      enableSuggestions: !asTyped,
      autofillHints: widget.autofillHints,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: type.sans(
        widget.fontSize,
        height: multiline ? 1.6 : 1.4,
        color: widget.documentStyle ? AppPalette.paperInk : colors.ink,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: type.sans(
          widget.fontSize,
          height: multiline ? 1.6 : 1.4,
          color: AppPalette.muted,
        ),
        fillColor: widget.documentStyle ? AppPalette.paper : null,
        // The wording is rendered below with an icon; here only the border
        // changes. Null falls back to the theme's borders.
        enabledBorder: errorBorder,
        focusedBorder: errorBorder,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text.rich(
            TextSpan(
              text: widget.label,
              children: [
                if (widget.optionalTag != null)
                  TextSpan(
                    text: ' ${widget.optionalTag}',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: colors.inkMuted,
                    ),
                  ),
              ],
            ),
            style: widget.labelMuted
                ? type.sans(16, color: colors.inkMuted, height: 1.4)
                : type.sans(17, weight: FontWeight.w600, height: 1.4),
          ),
          SizedBox(height: widget.labelMuted ? 6 : 8),
        ],
        if (widget.leading case final leading?)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                leading,
                Expanded(child: field),
              ],
            ),
          )
        else
          field,
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          FieldError(widget.errorText!),
        ],
      ],
    );
  }
}

/// Inline validation message: an exclamation badge plus plain words. Never
/// colour alone.
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.error,
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppIcons.alert,
              size: 14,
              color: colors.background,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.type.sans(16, color: colors.error, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped search input.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hint,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return _ControlledTextField(
      value: value,
      onChanged: onChanged,
      style: context.type.sans(18, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
          child: AppIcon(
            AppIcons.search,
            size: 22,
            color: colors.inkMuted,
            strokeWidth: 2,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: border(colors.line),
        enabledBorder: border(colors.line),
        focusedBorder: border(colors.accentText),
      ),
    );
  }
}

class _ControlledTextField extends StatefulWidget {
  const _ControlledTextField({
    required this.value,
    required this.onChanged,
    required this.style,
    required this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextStyle style;
  final InputDecoration decoration;

  @override
  State<_ControlledTextField> createState() => _ControlledTextFieldState();
}

class _ControlledTextFieldState extends State<_ControlledTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_ControlledTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: widget.style,
      decoration: widget.decoration,
    );
  }
}
