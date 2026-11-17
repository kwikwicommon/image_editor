enum AnnotateTool {
  select,
  arrow,
  rectangle,
  ellipse,
  line,
  text,
  pencil,
  highlighter,
  blur,
  spotlight,
  counter,
  eraser,
  crop,
  sticker,
  fill,
  colorPicker,
  solidRedaction,
}

class ImageEditorTools {
  static const ImageEditorTools standard = ImageEditorTools({
    AnnotateTool.select,
    AnnotateTool.arrow,
    AnnotateTool.rectangle,
    AnnotateTool.ellipse,
    AnnotateTool.line,
    AnnotateTool.text,
    AnnotateTool.pencil,
    AnnotateTool.highlighter,
    AnnotateTool.blur,
    AnnotateTool.spotlight,
    AnnotateTool.counter,
    AnnotateTool.eraser,
    AnnotateTool.crop,
    AnnotateTool.sticker,
    AnnotateTool.fill,
    AnnotateTool.colorPicker,
    AnnotateTool.solidRedaction,
  });

  static const ImageEditorTools goodImageV1 = ImageEditorTools({
    AnnotateTool.select,
    AnnotateTool.arrow,
    AnnotateTool.rectangle,
    AnnotateTool.ellipse,
    AnnotateTool.line,
    AnnotateTool.text,
    AnnotateTool.pencil,
    AnnotateTool.highlighter,
    AnnotateTool.blur,
    AnnotateTool.counter,
    AnnotateTool.eraser,
    AnnotateTool.crop,
    AnnotateTool.colorPicker,
    AnnotateTool.solidRedaction,
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
