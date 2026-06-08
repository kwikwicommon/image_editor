#ifndef FLUTTER_PLUGIN_IMAGE_EDITOR_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_IMAGE_EDITOR_WINDOWS_PLUGIN_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/method_result.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

class ImageEditorWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  explicit ImageEditorWindowsPlugin(HWND clipboard_owner_window);

  ~ImageEditorWindowsPlugin() override;

  ImageEditorWindowsPlugin(const ImageEditorWindowsPlugin&) = delete;
  ImageEditorWindowsPlugin& operator=(const ImageEditorWindowsPlugin&) =
      delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND clipboard_owner_window_ = nullptr;
};

#endif  // FLUTTER_PLUGIN_IMAGE_EDITOR_WINDOWS_PLUGIN_H_
