import Cocoa
import FlutterMacOS

private let pngSignature: [UInt8] = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]
private let pngHeaderByteCount = 33
private let ihdrChunkLength: UInt32 = 13
private let maxClipboardPngBytes = 128 * 1024 * 1024
private let maxClipboardDecodedBytes: UInt64 = 256 * 1024 * 1024
private let clipboardBytesPerPixel: UInt64 = 4

public class ImageEditorMacosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "image_editor/native",
      binaryMessenger: registrar.messenger
    )
    let instance = ImageEditorMacosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "editor.queryCapabilities":
      result(queryCapabilities())
    case "editor.copyPngToClipboard":
      result(copyPngToClipboard(arguments: call.arguments))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func queryCapabilities() -> [String: Any] {
    [
      "platform": "macos",
      "canCopyPngToClipboard": true,
      "nativeContractVersion": 1,
      "maxClipboardPngBytes": maxClipboardPngBytes,
      "maxClipboardDecodedBytes": Int(maxClipboardDecodedBytes),
      "supportedClipboardFormats": ["png"],
    ]
  }

  private func copyPngToClipboard(arguments: Any?) -> [String: Any] {
    guard
      let args = arguments as? [String: Any],
      let typedData = args["pngBytes"] as? FlutterStandardTypedData
    else {
      return failure(
        code: "invalidInput",
        message: "PNG bytes are required for clipboard copy.",
        recoverySuggestion: "Create a valid PNG image and try again."
      )
    }

    let pngData = typedData.data
    guard pngData.count <= maxClipboardPngBytes else {
      return failure(
        code: "tooLarge",
        message: "The PNG image is too large for clipboard copy.",
        recoverySuggestion: "Export or save the image manually and try again."
      )
    }

    guard hasPngSignature(pngData) else {
      return failure(
        code: "invalidInput",
        message: "A PNG image is required for clipboard copy.",
        recoverySuggestion: "Create a valid PNG image and try again."
      )
    }

    guard let pngHeader = readPngHeader(pngData) else {
      return failure(
        code: "invalidInput",
        message: "The PNG header is invalid for clipboard copy.",
        recoverySuggestion: "Create a valid PNG image and try again."
      )
    }

    let width = UInt64(pngHeader.width)
    let height = UInt64(pngHeader.height)
    let maxClipboardPixels = maxClipboardDecodedBytes / clipboardBytesPerPixel
    guard width <= maxClipboardPixels / height else {
      return failure(
        code: "tooLarge",
        message: "The PNG dimensions are too large for clipboard copy.",
        recoverySuggestion: "Export or save the image manually and try again.",
        details: [
          "width": Int(pngHeader.width),
          "height": Int(pngHeader.height),
          "maxDecodedBytes": Int(maxClipboardDecodedBytes),
        ]
      )
    }

    guard NSBitmapImageRep(data: pngData) != nil else {
      return failure(
        code: "invalidInput",
        message: "The PNG bytes could not be decoded for clipboard copy.",
        recoverySuggestion: "Create a valid PNG image and try again."
      )
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.declareTypes([.png], owner: nil)
    if pasteboard.setData(pngData, forType: .png) {
      return success()
    }
    return failure(
      code: "nativeFailure",
      message: "The image could not be written to the macOS clipboard.",
      recoverySuggestion: "Save the image manually and try again."
    )
  }

  private func success() -> [String: Any] {
    ["success": true]
  }

  private func failure(
    code: String,
    message: String,
    recoverySuggestion: String,
    details: Any? = nil
  ) -> [String: Any] {
    var response: [String: Any] = [
      "success": false,
      "code": code,
      "message": message,
      "recoverySuggestion": recoverySuggestion,
    ]
    if let details = details {
      response["details"] = details
    }
    return response
  }
}

private func hasPngSignature(_ data: Data) -> Bool {
  guard data.count >= pngSignature.count else {
    return false
  }
  return data.prefix(pngSignature.count).elementsEqual(pngSignature)
}

private struct PngHeader {
  let width: UInt32
  let height: UInt32
}

private func readPngHeader(_ data: Data) -> PngHeader? {
  guard data.count >= pngHeaderByteCount else {
    return nil
  }

  return data.withUnsafeBytes { rawBuffer in
    guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
      return nil
    }

    guard readBigEndianUInt32(bytes.advanced(by: 8)) == ihdrChunkLength else {
      return nil
    }
    guard
      bytes[12] == 0x49,
      bytes[13] == 0x48,
      bytes[14] == 0x44,
      bytes[15] == 0x52
    else {
      return nil
    }

    let width = readBigEndianUInt32(bytes.advanced(by: 16))
    let height = readBigEndianUInt32(bytes.advanced(by: 20))
    guard width > 0, height > 0 else {
      return nil
    }
    return PngHeader(width: width, height: height)
  }
}

private func readBigEndianUInt32(_ bytes: UnsafePointer<UInt8>) -> UInt32 {
  UInt32(bytes[0]) << 24 |
    UInt32(bytes[1]) << 16 |
    UInt32(bytes[2]) << 8 |
    UInt32(bytes[3])
}
