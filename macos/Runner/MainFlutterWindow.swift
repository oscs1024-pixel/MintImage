import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerImageClipboardChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
  }

  private func registerImageClipboardChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "mint_image/image_clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      guard call.method == "copyImage" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let width = arguments["width"] as? Int,
        let height = arguments["height"] as? Int,
        let rgba = arguments["rgba"] as? FlutterStandardTypedData
      else {
        result(FlutterError(
          code: "bad_args",
          message: "Invalid image clipboard arguments.",
          details: nil))
        return
      }

      guard copyImageToPasteboard(width: width, height: height, rgba: rgba.data) else {
        result(FlutterError(
          code: "copy_failed",
          message: "Failed to copy image to clipboard.",
          details: nil))
        return
      }

      result(nil)
    }
  }

  private func copyImageToPasteboard(width: Int, height: Int, rgba: Data) -> Bool {
    guard width > 0, height > 0, rgba.count == width * height * 4 else {
      return false
    }

    guard let provider = CGDataProvider(data: rgba as CFData) else {
      return false
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
    guard let cgImage = CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent)
    else {
      return false
    }

    let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    return pasteboard.writeObjects([image])
  }
}
