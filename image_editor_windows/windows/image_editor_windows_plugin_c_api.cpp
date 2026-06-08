#include "include/image_editor_windows/image_editor_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "image_editor_windows_plugin.h"

void ImageEditorWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  if (registrar == nullptr) {
    return;
  }
  auto plugin_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  if (plugin_registrar == nullptr) {
    return;
  }
  ImageEditorWindowsPlugin::RegisterWithRegistrar(plugin_registrar);
}
