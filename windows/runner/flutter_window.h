#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      image_clipboard_channel_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_lifecycle_channel_;

  // When true, the next WM_CLOSE is allowed to proceed without asking Dart.
  // Set after Dart confirms the user wants to exit via "performClose".
  bool force_close_ = false;

  // True while an "onCloseRequested" round-trip to Dart is in flight, so we
  // don't spam the framework with duplicate requests on repeated clicks.
  bool close_request_in_flight_ = false;

  // True once the system has initiated a shutdown / logoff
  // (WM_QUERYENDSESSION). During a session end we must never block by showing
  // a confirmation dialog, otherwise the app stalls the shutdown and triggers
  // Windows' "this app is preventing shutdown" UI.
  bool session_ending_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
