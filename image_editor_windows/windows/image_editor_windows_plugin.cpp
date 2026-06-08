#include "image_editor_windows_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <variant>
#include <vector>

namespace {

using Microsoft::WRL::ComPtr;
using EncodableList = flutter::EncodableList;
using EncodableMap = flutter::EncodableMap;
using EncodableValue = flutter::EncodableValue;

constexpr uint8_t kPngSignature[] = {
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
};
constexpr size_t kMaxClipboardPngBytes = 128ull * 1024ull * 1024ull;
constexpr uint64_t kMaxClipboardDecodedBytes = 256ull * 1024ull * 1024ull;

struct BitmapFrame {
  UINT width = 0;
  UINT height = 0;
  std::vector<uint8_t> bgra;
};

class ScopedComInitializer {
 public:
  ScopedComInitializer()
      : result_(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}

  ~ScopedComInitializer() {
    if (SUCCEEDED(result_)) {
      CoUninitialize();
    }
  }

  bool IsAvailable() const {
    return SUCCEEDED(result_) || result_ == RPC_E_CHANGED_MODE;
  }

  HRESULT result() const { return result_; }

 private:
  HRESULT result_ = S_OK;
};

class ClipboardSession {
 public:
  explicit ClipboardSession(HWND owner_window)
      : opened_(OpenClipboard(owner_window)),
        last_error_(opened_ ? ERROR_SUCCESS : GetLastError()) {}

  ~ClipboardSession() {
    if (opened_) {
      CloseClipboard();
    }
  }

  bool opened() const { return opened_; }

  HRESULT error() const { return HRESULT_FROM_WIN32(last_error_); }

 private:
  bool opened_ = false;
  DWORD last_error_ = ERROR_SUCCESS;
};

bool HasPngSignature(const std::vector<uint8_t>& bytes) {
  return bytes.size() >= sizeof(kPngSignature) &&
         std::memcmp(bytes.data(), kPngSignature, sizeof(kPngSignature)) == 0;
}

HRESULT LastErrorToHResult() {
  const DWORD error = GetLastError();
  return error == ERROR_SUCCESS ? E_FAIL : HRESULT_FROM_WIN32(error);
}

HWND ResolveClipboardOwner(HWND owner_window) {
  if (owner_window != nullptr && IsWindow(owner_window)) {
    return owner_window;
  }
  HWND active_window = GetActiveWindow();
  if (active_window != nullptr && IsWindow(active_window)) {
    return active_window;
  }
  return nullptr;
}

std::string HResultToString(HRESULT hr) {
  char buffer[32] = {};
  std::snprintf(
      buffer,
      sizeof(buffer),
      "0x%08lX",
      static_cast<unsigned long>(hr));
  return std::string(buffer);
}

EncodableValue MakeSuccess(const std::string& message = "",
                           const std::string& details = "") {
  EncodableMap response;
  response[EncodableValue("success")] = EncodableValue(true);
  if (!message.empty()) {
    response[EncodableValue("message")] = EncodableValue(message);
  }
  if (!details.empty()) {
    response[EncodableValue("details")] = EncodableValue(details);
  }
  return EncodableValue(response);
}

EncodableValue MakeFailure(const std::string& code,
                           const std::string& message,
                           const std::string& recovery_suggestion,
                           const std::string& details = "") {
  EncodableMap response;
  response[EncodableValue("success")] = EncodableValue(false);
  response[EncodableValue("code")] = EncodableValue(code);
  response[EncodableValue("message")] = EncodableValue(message);
  response[EncodableValue("recoverySuggestion")] =
      EncodableValue(recovery_suggestion);
  if (!details.empty()) {
    response[EncodableValue("details")] = EncodableValue(details);
  }
  return EncodableValue(response);
}

EncodableValue QueryCapabilities() {
  EncodableMap response;
  response[EncodableValue("platform")] = EncodableValue("windows");
  response[EncodableValue("canCopyPngToClipboard")] = EncodableValue(true);
  response[EncodableValue("nativeContractVersion")] = EncodableValue(1);
  response[EncodableValue("maxClipboardPngBytes")] =
      EncodableValue(static_cast<int64_t>(kMaxClipboardPngBytes));
  response[EncodableValue("maxClipboardDecodedBytes")] =
      EncodableValue(static_cast<int64_t>(kMaxClipboardDecodedBytes));
  response[EncodableValue("supportedClipboardFormats")] =
      EncodableValue(EncodableList{EncodableValue("png")});
  return EncodableValue(response);
}

const EncodableValue* FindMapValue(const EncodableMap& map,
                                   const std::string& key) {
  const auto iterator = map.find(EncodableValue(key));
  if (iterator == map.end()) {
    return nullptr;
  }
  return &iterator->second;
}

HRESULT DecodePngToBgra(const std::vector<uint8_t>& png_bytes,
                        BitmapFrame* frame) {
  if (frame == nullptr || png_bytes.empty() ||
      png_bytes.size() > std::numeric_limits<DWORD>::max()) {
    return E_INVALIDARG;
  }
  if (!HasPngSignature(png_bytes)) {
    return E_INVALIDARG;
  }

  ScopedComInitializer com_initializer;
  if (!com_initializer.IsAvailable()) {
    return com_initializer.result();
  }

  ComPtr<IWICImagingFactory> factory;
  HRESULT hr = CoCreateInstance(
      CLSID_WICImagingFactory,
      nullptr,
      CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IWICStream> stream;
  hr = factory->CreateStream(&stream);
  if (FAILED(hr)) {
    return hr;
  }
  hr = stream->InitializeFromMemory(
      const_cast<BYTE*>(png_bytes.data()),
      static_cast<DWORD>(png_bytes.size()));
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IWICBitmapDecoder> decoder;
  hr = factory->CreateDecoderFromStream(
      stream.Get(),
      nullptr,
      WICDecodeMetadataCacheOnLoad,
      &decoder);
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IWICBitmapFrameDecode> source_frame;
  hr = decoder->GetFrame(0, &source_frame);
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IWICFormatConverter> converter;
  hr = factory->CreateFormatConverter(&converter);
  if (FAILED(hr)) {
    return hr;
  }
  hr = converter->Initialize(
      source_frame.Get(),
      GUID_WICPixelFormat32bppBGRA,
      WICBitmapDitherTypeNone,
      nullptr,
      0.0,
      WICBitmapPaletteTypeCustom);
  if (FAILED(hr)) {
    return hr;
  }

  UINT width = 0;
  UINT height = 0;
  hr = converter->GetSize(&width, &height);
  if (FAILED(hr) || width == 0 || height == 0) {
    return FAILED(hr) ? hr : E_INVALIDARG;
  }
  if (width > static_cast<UINT>(std::numeric_limits<LONG>::max()) ||
      height > static_cast<UINT>(std::numeric_limits<LONG>::max())) {
    return HRESULT_FROM_WIN32(ERROR_ARITHMETIC_OVERFLOW);
  }

  const uint64_t stride = static_cast<uint64_t>(width) * 4;
  const uint64_t image_size = stride * static_cast<uint64_t>(height);
  if (stride > std::numeric_limits<UINT>::max() ||
      image_size > std::numeric_limits<UINT>::max() ||
      image_size > kMaxClipboardDecodedBytes) {
    return E_OUTOFMEMORY;
  }

  std::vector<uint8_t> pixels(static_cast<size_t>(image_size));
  hr = converter->CopyPixels(
      nullptr,
      static_cast<UINT>(stride),
      static_cast<UINT>(image_size),
      pixels.data());
  if (FAILED(hr)) {
    return hr;
  }

  frame->width = width;
  frame->height = height;
  frame->bgra = std::move(pixels);
  return S_OK;
}

HRESULT CreateClipboardDib(const BitmapFrame& frame, HGLOBAL* output) {
  if (output != nullptr) {
    *output = nullptr;
  }
  if (output == nullptr || frame.width == 0 || frame.height == 0 ||
      frame.bgra.empty()) {
    return E_INVALIDARG;
  }

  const size_t header_size = sizeof(BITMAPINFOHEADER);
  const size_t stride = static_cast<size_t>(frame.width) * 4;
  const size_t image_size = stride * static_cast<size_t>(frame.height);
  if (frame.bgra.size() < image_size ||
      image_size > std::numeric_limits<DWORD>::max()) {
    return E_INVALIDARG;
  }
  if (image_size > kMaxClipboardDecodedBytes ||
      image_size > std::numeric_limits<size_t>::max() - header_size) {
    return E_OUTOFMEMORY;
  }

  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, header_size + image_size);
  if (memory == nullptr) {
    return E_OUTOFMEMORY;
  }

  auto* data = static_cast<uint8_t*>(GlobalLock(memory));
  if (data == nullptr) {
    GlobalFree(memory);
    return HRESULT_FROM_WIN32(GetLastError());
  }

  auto* header = reinterpret_cast<BITMAPINFOHEADER*>(data);
  std::memset(header, 0, header_size);
  header->biSize = static_cast<DWORD>(header_size);
  header->biWidth = static_cast<LONG>(frame.width);
  header->biHeight = static_cast<LONG>(frame.height);
  header->biPlanes = 1;
  header->biBitCount = 32;
  header->biCompression = BI_RGB;
  header->biSizeImage = static_cast<DWORD>(image_size);

  uint8_t* pixels = data + header_size;
  for (UINT y = 0; y < frame.height; ++y) {
    const uint8_t* source_row =
        frame.bgra.data() + static_cast<size_t>(y) * stride;
    uint8_t* destination_row =
        pixels + static_cast<size_t>(frame.height - y - 1) * stride;
    std::memcpy(destination_row, source_row, stride);
  }

  GlobalUnlock(memory);
  *output = memory;
  return S_OK;
}

HRESULT CreateClipboardPng(const std::vector<uint8_t>& png_bytes,
                           HGLOBAL* output) {
  if (output != nullptr) {
    *output = nullptr;
  }
  if (output == nullptr || png_bytes.empty()) {
    return E_INVALIDARG;
  }
  if (png_bytes.size() > kMaxClipboardPngBytes) {
    return E_OUTOFMEMORY;
  }

  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, png_bytes.size());
  if (memory == nullptr) {
    return E_OUTOFMEMORY;
  }

  auto* data = static_cast<uint8_t*>(GlobalLock(memory));
  if (data == nullptr) {
    GlobalFree(memory);
    return LastErrorToHResult();
  }
  std::memcpy(data, png_bytes.data(), png_bytes.size());
  GlobalUnlock(memory);

  *output = memory;
  return S_OK;
}

EncodableValue CopyPngToClipboard(const std::vector<uint8_t>& png_bytes,
                                  HWND owner_window) {
  if (png_bytes.empty()) {
    return MakeFailure(
        "invalidInput",
        "PNG bytes are required for clipboard copy.",
        "Create a valid PNG image and try again.");
  }
  if (!HasPngSignature(png_bytes)) {
    return MakeFailure(
        "invalidInput",
        "A PNG image is required for clipboard copy.",
        "Create a valid PNG image and try again.");
  }
  if (png_bytes.size() > kMaxClipboardPngBytes) {
    return MakeFailure(
        "tooLarge",
        "The PNG image is too large for clipboard copy.",
        "Export or save the image manually and try again.");
  }

  BitmapFrame frame;
  HRESULT hr = DecodePngToBgra(png_bytes, &frame);
  if (FAILED(hr)) {
    return MakeFailure(
        "nativeFailure",
        "The PNG image could not be decoded for clipboard copy.",
        "Create a valid PNG image and try again.",
        HResultToString(hr));
  }

  HGLOBAL dib = nullptr;
  hr = CreateClipboardDib(frame, &dib);
  if (FAILED(hr) || dib == nullptr) {
    return MakeFailure(
        "nativeFailure",
        "The image could not be prepared for the Windows clipboard.",
        "Save the image manually and try again.",
        HResultToString(hr));
  }

  HGLOBAL png = nullptr;
  hr = CreateClipboardPng(png_bytes, &png);
  if (FAILED(hr) || png == nullptr) {
    GlobalFree(dib);
    return MakeFailure(
        "nativeFailure",
        "The PNG image could not be prepared for the Windows clipboard.",
        "Save the image manually and try again.",
        HResultToString(hr));
  }

  HWND clipboard_owner = ResolveClipboardOwner(owner_window);
  if (clipboard_owner == nullptr) {
    GlobalFree(dib);
    GlobalFree(png);
    return MakeFailure(
        "nativeUnavailable",
        "A Windows clipboard owner window is not available.",
        "Save the image manually and try again.");
  }

  ClipboardSession clipboard(clipboard_owner);
  if (!clipboard.opened()) {
    GlobalFree(dib);
    GlobalFree(png);
    return MakeFailure(
        "nativeFailure",
        "The Windows clipboard could not be opened.",
        "Close other clipboard tools and try again.",
        HResultToString(clipboard.error()));
  }

  if (!EmptyClipboard()) {
    const HRESULT empty_hr = LastErrorToHResult();
    GlobalFree(dib);
    GlobalFree(png);
    return MakeFailure(
        "nativeFailure",
        "The Windows clipboard could not be cleared.",
        "Close other clipboard tools and try again.",
        HResultToString(empty_hr));
  }

  HRESULT png_hr = S_OK;
  HRESULT dib_hr = S_OK;
  bool png_written = false;
  bool dib_written = false;

  const UINT png_format = RegisterClipboardFormatW(L"PNG");
  if (png_format == 0) {
    png_hr = LastErrorToHResult();
  } else if (SetClipboardData(png_format, png) != nullptr) {
    png = nullptr;
    png_written = true;
  } else {
    png_hr = LastErrorToHResult();
  }

  if (SetClipboardData(CF_DIB, dib) != nullptr) {
    dib = nullptr;
    dib_written = true;
  } else {
    dib_hr = LastErrorToHResult();
  }

  if (dib != nullptr) {
    GlobalFree(dib);
  }
  if (png != nullptr) {
    GlobalFree(png);
  }

  if (png_written && dib_written) {
    return MakeSuccess();
  }
  if (png_written || dib_written) {
    const HRESULT fallback_hr = png_written ? dib_hr : png_hr;
    return MakeSuccess(
        "The image was copied with a fallback clipboard format.",
        HResultToString(fallback_hr));
  }
  return MakeFailure(
      "nativeFailure",
      "The image could not be written to the Windows clipboard.",
      "Save the image manually and try again.",
      HResultToString(FAILED(png_hr) ? png_hr : dib_hr));
}

EncodableValue HandleCopyRequest(const EncodableValue* arguments,
                                 HWND owner_window) {
  const auto* map = arguments == nullptr
                        ? nullptr
                        : std::get_if<EncodableMap>(arguments);
  if (map == nullptr) {
    return MakeFailure(
        "invalidInput",
        "PNG bytes are required for clipboard copy.",
        "Create a valid PNG image and try again.");
  }

  const auto* bytes_value = FindMapValue(*map, "pngBytes");
  const auto* bytes = bytes_value == nullptr
                          ? nullptr
                          : std::get_if<std::vector<uint8_t>>(bytes_value);
  if (bytes == nullptr) {
    return MakeFailure(
        "invalidInput",
        "PNG bytes are required for clipboard copy.",
        "Create a valid PNG image and try again.");
  }

  return CopyPngToClipboard(*bytes, owner_window);
}

}  // namespace

ImageEditorWindowsPlugin::ImageEditorWindowsPlugin(HWND clipboard_owner_window)
    : clipboard_owner_window_(clipboard_owner_window) {}

ImageEditorWindowsPlugin::~ImageEditorWindowsPlugin() = default;

void ImageEditorWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  HWND clipboard_owner_window = nullptr;
  if (auto* view = registrar->GetView()) {
    clipboard_owner_window = view->GetNativeWindow();
  }

  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(),
          "image_editor/native",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin =
      std::make_unique<ImageEditorWindowsPlugin>(clipboard_owner_window);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](
          const auto& call,
          auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

void ImageEditorWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "editor.queryCapabilities") {
    result->Success(QueryCapabilities());
    return;
  }
  if (method == "editor.copyPngToClipboard") {
    result->Success(
        HandleCopyRequest(method_call.arguments(), clipboard_owner_window_));
    return;
  }
  result->NotImplemented();
}
