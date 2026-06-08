import 'package:image_editor_platform_interface/image_editor_platform_interface.dart';

class ImageEditorWindows extends MethodChannelImageEditor {
  ImageEditorWindows();

  static void registerWith() {
    ImageEditorPlatform.instance = ImageEditorWindows();
  }
}
