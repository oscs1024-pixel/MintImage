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

      if call.method == "readImageFile" {
        if let path = self.readImageFileFromPasteboard() {
          result(["path": path])
        } else {
          result(nil)
        }
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

  private func readImageFileFromPasteboard() -> String? {
    let pasteboard = NSPasteboard.general
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]) as? [NSURL] {
      for url in urls {
        guard let path = url.path else {
          continue
        }
        if isSupportedImagePath(path: path) {
          return path
        }
      }
    }

    if let image = NSImage(pasteboard: pasteboard) {
      return writeImageToTemporaryPng(image: image)
    }

    return nil
  }

  private func isSupportedImagePath(path: String) -> Bool {
    let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
    return fileExtension == "png"
      || fileExtension == "jpg"
      || fileExtension == "jpeg"
      || fileExtension == "webp"
  }

  private func writeImageToTemporaryPng(image: NSImage) -> String? {
    guard
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
    else {
      return nil
    }

    let filename = "mint_image_clipboard_\(UUID().uuidString).png"
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    do {
      try pngData.write(to: url, options: .atomic)
      return url.path
    } catch {
      return nil
    }
  }
}
