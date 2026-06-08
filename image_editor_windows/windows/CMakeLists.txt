cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "image_editor_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "image_editor_windows_plugin")

list(APPEND PLUGIN_SOURCES
  "image_editor_windows_plugin.cpp"
  "image_editor_windows_plugin_c_api.cpp"
)

add_library(${PLUGIN_NAME} SHARED
  "include/image_editor_windows/image_editor_windows_plugin_c_api.h"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin windowscodecs ole32)

set(image_editor_windows_bundled_libraries
  ""
  PARENT_SCOPE
)
