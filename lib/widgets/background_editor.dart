import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../src/background/background_controller.dart';
import '../src/background/background_state.dart';
import '../src/core/image_editor_localizations.dart';

class BackgroundEditor extends StatelessWidget {
  final BackgroundController controller;
  final ImageEditorLocalizations localizations;

  const BackgroundEditor({
    super.key,
    required this.controller,
    this.localizations = const DefaultImageEditorLocalizations(),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 280,
        child: Obx(() {
          final state = controller.state.value;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                localizations.text('background.title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<BackgroundType>(
                  segments: [
                    ButtonSegment(
                      value: BackgroundType.none,
                      icon: const Icon(Icons.block_rounded),
                      label: Text(localizations.text('background.none')),
                    ),
                    ButtonSegment(
                      value: BackgroundType.gradient,
                      icon: const Icon(Icons.gradient_rounded),
                      label: Text(localizations.text('background.gradient')),
                    ),
                    ButtonSegment(
                      value: BackgroundType.solid,
                      icon: const Icon(Icons.format_color_fill_rounded),
                      label: Text(localizations.text('background.solid')),
                    ),
                    ButtonSegment(
                      value: BackgroundType.image,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(localizations.text('background.image')),
                    ),
                    ButtonSegment(
                      value: BackgroundType.pattern,
                      icon: const Icon(Icons.grid_on_rounded),
                      label: Text(localizations.text('background.pattern')),
                    ),
                  ],
                  selected: {state.type},
                  onSelectionChanged: (selection) {
                    controller.setType(selection.first);
                  },
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 16),
              if (state.type == BackgroundType.gradient)
                _GradientPicker(controller: controller, state: state),
              if (state.type == BackgroundType.solid)
                _ColorPicker(
                  colors: const [
                    Color(0xFFFFFFFF),
                    Color(0xFFF3F4F6),
                    Color(0xFF111827),
                    Color(0xFF2563EB),
                    Color(0xFF16A34A),
                  ],
                  selected: state.solidColor,
                  onSelected: controller.setSolidColor,
                ),
              if (state.type == BackgroundType.image)
                _ImageBackgroundInfo(
                  hasImage: state.customImageBytes != null,
                  localizations: localizations,
                  onClear: controller.clearCustomImage,
                ),
              if (state.type == BackgroundType.pattern)
                _PatternPicker(
                  controller: controller,
                  state: state,
                  localizations: localizations,
                ),
              _SliderRow(
                label: localizations.text('background.padding'),
                value: state.padding,
                min: BackgroundState.minPadding,
                max: 160,
                onChanged: controller.setPadding,
              ),
              _SliderRow(
                label: localizations.text('background.radius'),
                value: state.cornerRadius,
                min: BackgroundState.minCornerRadius,
                max: 80,
                onChanged: controller.setCornerRadius,
              ),
              _SliderRow(
                label: localizations.text('background.shadow'),
                value: state.shadowBlur,
                min: BackgroundState.minShadowBlur,
                max: 80,
                onChanged: controller.setShadowBlur,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localizations.text('background.titleBar')),
                value: state.showTitleBar,
                onChanged: controller.setShowTitleBar,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _GradientPicker extends StatelessWidget {
  final BackgroundController controller;
  final BackgroundState state;

  const _GradientPicker({required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in GradientPreset.values)
          _GradientSwatch(
            colors: preset.colors,
            selected: state.gradientPreset == preset,
            onTap: () => controller.setGradientPreset(preset),
          ),
      ],
    );
  }
}

class _PatternPicker extends StatelessWidget {
  final BackgroundController controller;
  final BackgroundState state;
  final ImageEditorLocalizations localizations;

  const _PatternPicker({
    required this.controller,
    required this.state,
    required this.localizations,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final preset in PatternPreset.values)
          IconButton(
            tooltip: localizations.text(preset.labelKey),
            isSelected: state.patternPreset == preset,
            icon: Icon(preset.icon),
            onPressed: () => controller.setPatternPreset(preset),
          ),
      ],
    );
  }
}

class _ImageBackgroundInfo extends StatelessWidget {
  final bool hasImage;
  final ImageEditorLocalizations localizations;
  final VoidCallback onClear;

  const _ImageBackgroundInfo({
    required this.hasImage,
    required this.localizations,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          hasImage ? Icons.image_outlined : Icons.image_not_supported_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            localizations.text(
              hasImage
                  ? 'background.imageSelected'
                  : 'background.imageMissing',
            ),
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: localizations.text('common.remove'),
          icon: const Icon(Icons.close_rounded),
          onPressed: hasImage ? onClear : null,
        ),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final color in colors)
          IconButton(
            tooltip: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
            icon: Icon(selected == color ? Icons.check_circle : Icons.circle),
            color: color,
            onPressed: () => onSelected(color),
          ),
      ],
    );
  }
}

class _GradientSwatch extends StatelessWidget {
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  const _GradientSwatch({
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          gradient: LinearGradient(colors: colors),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max).toDouble(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
