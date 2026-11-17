import 'package:flutter/material.dart';

import '../src/canvas/annotation_controller.dart';
import '../src/core/image_editor_localizations.dart';
import '../src/tools/tool_types.dart';

class AnnotationToolbar extends StatelessWidget {
  final AnnotationController controller;
  final ImageEditorTools tools;
  final ImageEditorLocalizations localizations;

  const AnnotationToolbar({
    super.key,
    required this.controller,
    this.tools = const ImageEditorTools({}),
    this.localizations = const DefaultImageEditorLocalizations(),
  });

  @override
  Widget build(BuildContext context) {
    final enabledTools = tools.enabled.isEmpty
        ? ImageEditorTools.all().enabled
        : tools.enabled;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 72,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final tool in enabledTools)
                  _ToolButton(
                    icon: _toolIcon(tool),
                    label: localizations.text(_toolLabelKey(tool)),
                    selected: controller.currentTool.value == tool,
                    onPressed: () => controller.setTool(tool),
                  ),
                const Divider(height: 16),
                _ToolButton(
                  icon: Icons.undo_rounded,
                  label: localizations.text('toolbar.undo'),
                  onPressed: controller.undo,
                ),
                _ToolButton(
                  icon: Icons.redo_rounded,
                  label: localizations.text('toolbar.redo'),
                  onPressed: controller.redo,
                ),
                const Divider(height: 16),
                _ColorSwatch(
                  color: const Color(0xFFE11D48),
                  selected:
                      controller.currentColor.value == const Color(0xFFE11D48),
                  onSelected: controller.setColor,
                ),
                _ColorSwatch(
                  color: const Color(0xFF2563EB),
                  selected:
                      controller.currentColor.value == const Color(0xFF2563EB),
                  onSelected: controller.setColor,
                ),
                _ColorSwatch(
                  color: const Color(0xFF16A34A),
                  selected:
                      controller.currentColor.value == const Color(0xFF16A34A),
                  onSelected: controller.setColor,
                ),
                _ColorSwatch(
                  color: const Color(0xFFF59E0B),
                  selected:
                      controller.currentColor.value == const Color(0xFFF59E0B),
                  onSelected: controller.setColor,
                ),
                const SizedBox(height: 8),
                RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    min: 1,
                    max: 16,
                    value: controller.currentStrokeWidth.value
                        .clamp(1, 16)
                        .toDouble(),
                    onChanged: controller.setStrokeWidth,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _toolIcon(AnnotateTool tool) {
    switch (tool) {
      case AnnotateTool.select:
        return Icons.near_me_outlined;
      case AnnotateTool.arrow:
        return Icons.arrow_forward_rounded;
      case AnnotateTool.rectangle:
        return Icons.crop_square_rounded;
      case AnnotateTool.ellipse:
        return Icons.radio_button_unchecked_rounded;
      case AnnotateTool.line:
        return Icons.horizontal_rule_rounded;
      case AnnotateTool.text:
        return Icons.title_rounded;
      case AnnotateTool.pencil:
        return Icons.edit_rounded;
      case AnnotateTool.highlighter:
        return Icons.border_color_rounded;
      case AnnotateTool.blur:
        return Icons.blur_on_rounded;
      case AnnotateTool.spotlight:
        return Icons.highlight_alt_rounded;
      case AnnotateTool.counter:
        return Icons.looks_one_rounded;
      case AnnotateTool.eraser:
        return Icons.auto_fix_off_rounded;
      case AnnotateTool.crop:
        return Icons.crop_rounded;
      case AnnotateTool.sticker:
        return Icons.emoji_symbols_rounded;
      case AnnotateTool.fill:
        return Icons.format_color_fill_rounded;
      case AnnotateTool.colorPicker:
        return Icons.colorize_rounded;
      case AnnotateTool.solidRedaction:
        return Icons.rectangle_rounded;
    }
  }

  String _toolLabelKey(AnnotateTool tool) {
    switch (tool) {
      case AnnotateTool.select:
        return 'toolbar.select';
      case AnnotateTool.arrow:
        return 'toolbar.arrow';
      case AnnotateTool.rectangle:
        return 'toolbar.rectangle';
      case AnnotateTool.ellipse:
        return 'toolbar.ellipse';
      case AnnotateTool.line:
        return 'toolbar.line';
      case AnnotateTool.text:
        return 'toolbar.text';
      case AnnotateTool.pencil:
        return 'toolbar.pencil';
      case AnnotateTool.highlighter:
        return 'toolbar.highlighter';
      case AnnotateTool.blur:
      case AnnotateTool.spotlight:
        return 'toolbar.blur';
      case AnnotateTool.counter:
        return 'toolbar.counter';
      case AnnotateTool.eraser:
        return 'toolbar.eraser';
      case AnnotateTool.crop:
        return 'toolbar.crop';
      case AnnotateTool.sticker:
        return 'sticker.title';
      case AnnotateTool.fill:
        return 'toolbar.fill';
      case AnnotateTool.colorPicker:
        return 'toolbar.colorPicker';
      case AnnotateTool.solidRedaction:
        return 'toolbar.solidRedaction';
    }
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IconButton(
        tooltip: label,
        icon: Icon(icon),
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        style: IconButton.styleFrom(
          backgroundColor: selected ? colorScheme.primary : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final ValueChanged<Color> onSelected;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IconButton(
        tooltip: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        icon: Icon(selected ? Icons.check_circle : Icons.circle),
        color: color,
        onPressed: () => onSelected(color),
      ),
    );
  }
}
