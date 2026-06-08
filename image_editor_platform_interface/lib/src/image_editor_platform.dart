import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_image_editor.dart';
import 'types.dart';

abstract class ImageEditorPlatform extends PlatformInterface {
  ImageEditorPlatform() : super(token: _token);

  static final Object _token = Object();

  static ImageEditorPlatform _instance = MethodChannelImageEditor();

  static ImageEditorPlatform get instance => _instance;

  static set instance(ImageEditorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<ImageEditorCapabilities> queryCapabilities() {
    throw UnimplementedError('queryCapabilities() has not been implemented.');
  }

  Future<ImageEditorClipboardResult> copyPngToClipboard(Uint8List pngBytes) {
    throw UnimplementedError('copyPngToClipboard() has not been implemented.');
  }
}
