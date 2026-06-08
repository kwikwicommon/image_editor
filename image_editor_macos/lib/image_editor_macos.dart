import 'package:image_editor_platform_interface/image_editor_platform_interface.dart';

class ImageEditorMacos extends MethodChannelImageEditor {
  ImageEditorMacos();

  static void registerWith() {
    ImageEditorPlatform.instance = ImageEditorMacos();
  }
}
