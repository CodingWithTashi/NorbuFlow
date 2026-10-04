import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../layout/responsive.dart';
import '../models/formatted_text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'app_text_field.dart';
import 'buttons.dart';

/// A box for a letter's wording: bold, italic, underline and a list, and
/// nothing else. Controlled, as [AppTextField] is, by [value].
class FormattedTextField extends StatefulWidget {
  const FormattedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.builder,
    this.label,
    this.hint,
    this.errorText,
    this.onPaste,
    this.emptyActions = const [],
    this.minLines = 10,
    this.fontSize = 16,
  });

  final FormattedText value;
  final ValueChanged<FormattedText> onChanged;

  /// Places the field. On a phone, while the box is in use, [accessory] is
  /// the toolbar with Done, to go where the screen's own button is.
  final Widget Function(BuildContext context, Widget field, Widget? accessory)
  builder;
  final String? label;
  final String? hint;
  final String? errorText;

  /// Fills the box with what was copied. Offered while it is blank.
  final Future<void> Function()? onPaste;

  /// Other ways to fill the box, shown with Paste while it is blank.
  final List<Widget> emptyActions;
  final int minLines;
  final double fontSize;

  @override
  State<FormattedTextField> createState() => _FormattedTextFieldState();
}

class _FormattedTextFieldState extends State<FormattedTextField> {
  late final _MarkedTextController _controller = _MarkedTextController(
    widget.value,
  );
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // The toolbar goes above the keyboard while the box is in use.
    _focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(FormattedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.formatted) {
      final end = widget.value.text.length;
      _controller.show(widget.value, start: end, end: end);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _focusChanged() => setState(() {});

  void _typed(String _) {
    final rewrite = _controller.rewrite;
    if (rewrite == null) {
      widget.onChanged(_controller.formatted);
      return;
    }
    // An undo has to land as it was given, so what the rules change
    // follows at once as an edit of the field's own.
    scheduleMicrotask(() {
      if (!mounted || _controller.rewrite != rewrite) return;
      _controller.show(rewrite.value, start: rewrite.start, end: rewrite.end);
      widget.onChanged(rewrite.value);
    });
  }

  void _toggleMark(TextMark mark) {
    final formatted = _controller.formatted;
    final (start, end) = _controller.span;
    // A caret inside a word stands for the word.
    final target = start < end ? (start, end) : formatted.wordAt(start);
    if (target == null) {
      final marks = _controller.typing ?? formatted.marksAt(start, end);
      _controller.typeWith(
        marks.contains(mark) ? marks.difference({mark}) : {...marks, mark},
      );
    } else {
      final next = formatted.toggled(mark, target.$1, target.$2);
      _controller.show(next, start: start, end: end);
      widget.onChanged(next);
    }
    _focusNode.requestFocus();
  }

  void _toggleList() {
    final (start, end) = _controller.span;
    final change = _controller.formatted.bulletsToggled(start, end);
    _controller.show(change.value, start: change.start, end: change.end);
    widget.onChanged(change.value);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final compact = context.isCompact;
    final errorBorder = widget.errorText == null
        ? null
        : OutlineInputBorder(
            borderRadius: AppTheme.fieldRadius,
            borderSide: BorderSide(color: colors.error, width: 1.5),
          );
    final toolbar = _Toolbar(
      controller: _controller,
      onMark: _toggleMark,
      onList: _toggleList,
    );

    // Paper in every theme. The app's caret and underlines are pale in dark
    // mode and would not show on it: the box has the accent and its own ink.
    final box = TextSelectionTheme(
      data: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.25),
        selectionHandleColor: colors.accent,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _typed,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        minLines: widget.minLines,
        maxLines: null,
        style: type
            .sans(widget.fontSize, height: 1.6, color: AppPalette.paperInk)
            .copyWith(decorationColor: AppPalette.paperInk),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: type.sans(
            widget.fontSize,
            height: 1.6,
            color: AppPalette.muted,
          ),
          fillColor: AppPalette.paper,
          enabledBorder: errorBorder,
          focusedBorder: errorBorder,
        ),
      ),
    );

    final fillers = [
      if (widget.onPaste != null)
        SecondaryButton(
          label: context.l10n.formatPaste,
          icon: AppIcons.paste,
          onPressed: widget.onPaste,
          minHeight: 60,
          fontSize: 18,
        ),
      ...widget.emptyActions,
    ];

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label case final label?) ...[
          Text(
            label,
            style: type.sans(17, weight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 8),
        ],
        if (!compact) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextFieldTapRegion(child: toolbar),
            ),
          ),
          const SizedBox(height: 8),
        ],
        box,
        if (widget.value.isBlank && fillers.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (compact || fillers.length == 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: fillers,
            )
          else
            EqualRow(children: fillers),
        ],
        if (widget.errorText case final error?) ...[
          const SizedBox(height: 8),
          FieldError(error),
        ],
      ],
    );

    final accessory = compact && _focusNode.hasFocus
        ? TextFieldTapRegion(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Expanded(child: toolbar),
                  _DoneButton(onPressed: _focusNode.unfocus),
                ],
              ),
            ),
          )
        : null;
    return widget.builder(context, field, accessory);
  }
}

/// The field's text with its marks, each stretch drawn its own way.
class _MarkedTextController extends TextEditingController {
  _MarkedTextController(this._formatted) : super(text: _formatted.text);

  FormattedText _formatted;

  /// What is in the field: always the same text as the field's own.
  FormattedText get formatted => _formatted;

  /// The marks the next typed characters get, once set on the toolbar.
  /// Until then they follow the text at the caret.
  Set<TextMark>? typing;

  /// What the rules made of the last edit, when it is not what was typed.
  TextChange? rewrite;

  // An undo hands back a value the field held before: the very same object.
  final _held = Expando<bool>();

  /// The selection, or the end of the text while there is none.
  (int, int) get span {
    final end = text.length;
    if (!selection.isValid) return (end, end);
    return (math.min(selection.start, end), math.min(selection.end, end));
  }

  /// Puts [next] in the field with [start] to [end] selected.
  void show(FormattedText next, {required int start, required int end}) {
    _formatted = next;
    rewrite = null;
    typing = null;
    final shown = TextEditingValue(
      text: next.text,
      selection: TextSelection(baseOffset: start, extentOffset: end),
    );
    if (shown == value) {
      // Only the marks are new: they still have to be drawn.
      notifyListeners();
    } else {
      value = shown;
    }
  }

  /// Sets what is typed next at the caret with [marks].
  void typeWith(Set<TextMark> marks) {
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    typing = marks;
    notifyListeners();
  }

  @override
  set value(TextEditingValue next) {
    if (next.text != _formatted.text) {
      // The keyboard changed the text, or an undo brought older text back.
      // An undo is taken as it is: only the marks are worked out again.
      final undo = _held[next] ?? false;
      final caret = next.selection.extentOffset;
      final change = _formatted.edited(
        text: next.text,
        caret: caret,
        typing: undo ? null : typing,
        rules: !undo,
      );
      rewrite = change.rewritten ? change : null;
      _formatted = change.rewritten
          ? _formatted.edited(text: next.text, caret: caret, rules: false).value
          : change.value;
      typing = null;
    } else if (next.selection != selection) {
      // The caret moved: what was set for the old place no longer holds.
      typing = null;
    }
    _held[next] = true;
    super.value = next;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // One number for each character: its marks, and whether the keyboard
    // is still composing it, which is underlined too.
    final looks = List.filled(text.length, 0);
    for (final range in _formatted.ranges) {
      for (var at = range.start; at < range.end; at++) {
        looks[at] |= 1 << range.mark.index;
      }
    }
    if (withComposing && value.isComposingRangeValid) {
      for (var at = value.composing.start; at < value.composing.end; at++) {
        looks[at] |= _composing;
      }
    }

    final spans = <TextSpan>[];
    for (var at = 0; at < text.length;) {
      final look = looks[at];
      var end = at;
      while (end < text.length && looks[end] == look) {
        end++;
      }
      spans.add(
        TextSpan(
          text: text.substring(at, end),
          style: look == 0 ? null : _drawn(look),
        ),
      );
      at = end;
    }
    return TextSpan(style: style, children: spans);
  }

  static final _composing = 1 << TextMark.values.length;

  static bool _has(int look, TextMark mark) => (look & 1 << mark.index) != 0;

  static TextStyle _drawn(int look) => TextStyle(
    fontWeight: _has(look, TextMark.bold) ? FontWeight.w700 : null,
    fontStyle: _has(look, TextMark.italic) ? FontStyle.italic : null,
    decoration: _has(look, TextMark.underline) || look >= _composing
        ? TextDecoration.underline
        : null,
  );
}

/// Bold, Italic, Underline and List, lit for what the selection has.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onMark,
    required this.onList,
  });

  final _MarkedTextController controller;
  final ValueChanged<TextMark> onMark;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.fieldRadius,
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final formatted = controller.formatted;
          final (start, end) = controller.span;
          final marks = controller.typing ?? formatted.marksAt(start, end);
          return Row(
            children: [
              for (final (mark, icon, label) in [
                (TextMark.bold, AppIcons.bold, l10n.formatBold),
                (TextMark.italic, AppIcons.italic, l10n.formatItalic),
                (TextMark.underline, AppIcons.underline, l10n.formatUnderline),
              ])
                Expanded(
                  child: _ToolButton(
                    icon: icon,
                    label: label,
                    on: marks.contains(mark),
                    onTap: () => onMark(mark),
                  ),
                ),
              Expanded(
                child: _ToolButton(
                  icon: AppIcons.bulletList,
                  label: l10n.formatList,
                  on: formatted.bulletedAt(start, end),
                  onTap: onList,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final AppIconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        // On is a tint and a bar as well as a colour.
        color: on ? colors.card : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // A tap here must leave the box its focus.
          canRequestFocus: false,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: on ? AppPalette.amber : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: _IconOverWord(
              icon: icon,
              label: label,
              color: on ? colors.accentText : colors.inkMuted,
              weight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the keyboard away, which brings the screen's own button back.
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.formatDone;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: context.colors.accent,
        borderRadius: AppTheme.fieldRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          canRequestFocus: false,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: _IconOverWord(
              icon: AppIcons.check,
              label: label,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconOverWord extends StatelessWidget {
  const _IconOverWord({
    required this.icon,
    required this.label,
    required this.color,
    required this.weight,
  });

  final AppIconData icon;
  final String label;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(icon, size: 22, color: color, strokeWidth: 2),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Set close, so that "Underline" has room on a phone in Simple
          // Mode with four more beside it.
          style: context.type.sans(
            13,
            weight: weight,
            color: color,
            height: 1.3,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
