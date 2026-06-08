enum AnnotateTool {
  select,
  arrow,
  rectangle,
  ellipse,
  text,
  pencil,
  highlighter,
  blur,
  spotlight,
  counter,
  eraser,
  crop,
  sticker,
}

class ImageEditorTools {
  static const ImageEditorTools standard = ImageEditorTools({
    AnnotateTool.select,
    AnnotateTool.arrow,
    AnnotateTool.rectangle,
    AnnotateTool.ellipse,
    AnnotateTool.text,
    AnnotateTool.pencil,
    AnnotateTool.highlighter,
    AnnotateTool.blur,
    AnnotateTool.spotlight,
    AnnotateTool.counter,
    AnnotateTool.eraser,
    AnnotateTool.crop,
    AnnotateTool.sticker,
  });

  final Set<AnnotateTool> enabled;

  const ImageEditorTools(this.enabled);

  factory ImageEditorTools.all() => standard;

  bool contains(AnnotateTool tool) {
    return _effectiveEnabled.contains(tool);
  }

  Set<AnnotateTool> get _effectiveEnabled {
    return enabled.isEmpty ? standard.enabled : enabled;
  }
}
