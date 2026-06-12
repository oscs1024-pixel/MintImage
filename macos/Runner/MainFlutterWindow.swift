import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var windowLifecycleChannel: FlutterMethodChannel?

  // When true, the next close is allowed to proceed without asking Dart.
  // Set after Dart confirms the user wants to exit via "performClose".
  private var forceClose = false

  // True while an "onCloseRequested" round-trip to Dart is in flight, so we
  // don't spam the framework with duplicate requests on repeated clicks.
  private var closeRequestInFlight = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerImageClipboardChannel(flutterViewController: flutterViewController)
    registerWindowLifecycleChannel(flutterViewController: flutterViewController)

    self.delegate = self

    super.awakeFromNib()
  }

  // MARK: - Window lifecycle interception

  private func registerWindowLifecycleChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "mint_image/window_lifecycle",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }

      if call.method == "performClose" {
        // Dart confirmed the exit; close the window directly, bypassing our
        // own interception.
        self.forceClose = true
        self.closeRequestInFlight = false
        result(nil)
        self.close()
        return
      }

      result(FlutterMethodNotImplemented)
    }

    windowLifecycleChannel = channel
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if forceClose {
      return true
    }

    // Ask Dart whether it's safe to close. Dart returns true to allow an
    // immediate close, or false to drive the close itself via "performClose"
    // after the user confirms.
    if let channel = windowLifecycleChannel, !closeRequestInFlight {
      closeRequestInFlight = true
      channel.invokeMethod("onCloseRequested", arguments: nil) { [weak self] response in
        guard let self = self else { return }
        self.closeRequestInFlight = false
        let allow = (response as? Bool) ?? true
        if allow {
          self.forceClose = true
          self.close()
        }
      }
    }

    // Block this close; the real close happens after Dart responds.
    return false
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
