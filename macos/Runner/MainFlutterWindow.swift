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
      if call.method == "copyImageFile" {
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(FlutterError(
            code: "bad_args",
            message: "Invalid image clipboard file arguments.",
            details: nil))
          return
        }

        guard self.copyImageFileToPasteboard(path: path) else {
          result(FlutterError(
            code: "copy_failed",
            message: "Failed to copy image file to clipboard.",
            details: nil))
          return
        }

        result(nil)
        return
      }

      result(FlutterMethodNotImplemented)
    }
  }

  private func copyImageFileToPasteboard(path: String) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    var objects: [NSPasteboardWriting] = []
    if let image = NSImage(contentsOfFile: path) {
      objects.append(image)
    }
    objects.append(NSURL(fileURLWithPath: path))

    return pasteboard.writeObjects(objects)
  }
}
