// A one-field dialog (rename, new folder, new group, type a path) that owns
// its controller, so the field survives the dialog's exit animation.

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/app_dialog.dart';
import '../theme/theme.dart';

/// Asks for one line of text; resolves to it trimmed, or null when
/// cancelled. [validate] returns why the text can't be used (shown under
/// the field), or null. [disposeAfterExit] keeps the controller until the
/// dialog's route has left the overlay (iOS, where its field outlives the
/// pop during the exit animation).
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? caption,
  String? confirm,
  int? maxLength,
  bool mono = false,
  bool disposeAfterExit = false,
  TextInputType? keyboardType,
  String? Function(String text)? validate,
}) {
  final l10n = context.l10n;
  return showAppDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(
      title: title,
      initial: initial,
      hint: hint,
      caption: caption,
      confirm: confirm ?? l10n.commonSave,
      maxLength: maxLength,
      mono: mono,
      disposeAfterExit: disposeAfterExit,
      keyboardType: keyboardType,
      validate: validate,
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initial,
    required this.confirm,
    required this.mono,
    required this.disposeAfterExit,
    this.hint,
    this.caption,
    this.maxLength,
    this.keyboardType,
    this.validate,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? caption;
  final String confirm;
  final int? maxLength;
  final bool mono;
  final bool disposeAfterExit;
  final TextInputType? keyboardType;
  final String? Function(String text)? validate;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _problem;

  @override
  void initState() {
    super.initState();
    if (!widget.disposeAfterExit) return;
    // The result arrives before the closing dialog leaves the overlay; until
    // then its field still reads the controller.
    var left = false;
    void disposeWhenLeft() {
      if (left) return;
      left = true;
      _controller.dispose();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ModalRoute.of(context)?.completed.then<void>((_) => disposeWhenLeft());
    });
  }

  @override
  void dispose() {
    // With [disposeAfterExit] the route completion owns the disposal above.
    if (!widget.disposeAfterExit) _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final problem = widget.validate?.call(text);
    if (problem != null) return setState(() => _problem = problem);
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final field = TextField(
      controller: _controller,
      autofocus: true,
      autocorrect: !widget.mono,
      enableSuggestions: !widget.mono,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      style: widget.mono ? AppType.mono(size: 14) : null,
      decoration: InputDecoration(hintText: widget.hint, counterText: '', errorText: _problem),
      onChanged: (_) {
        if (_problem != null) setState(() => _problem = null);
      },
      onSubmitted: (_) => _submit(),
    );
    return AlertDialog(
      title: Text(widget.title),
      content: widget.caption == null
          ? field
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.caption!,
                  style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary),
                ),
                const SizedBox(height: 8),
                field,
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}
