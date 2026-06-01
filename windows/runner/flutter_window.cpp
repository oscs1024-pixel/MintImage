#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <cstring>
#include <optional>
#include <string>
#include <variant>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

const flutter::EncodableValue* FindMapValue(
    const flutter::EncodableMap& map,
    const char* key) {
  auto it = map.find(flutter::EncodableValue(std::string(key)));
  if (it == map.end()) {
    return nullptr;
  }
  return &it->second;
}

bool ReadIntValue(const flutter::EncodableValue* value, int* output) {
  if (!value) {
    return false;
  }
  if (const auto* int32_value = std::get_if<int32_t>(value)) {
    *output = *int32_value;
    return true;
  }
  if (const auto* int64_value = std::get_if<int64_t>(value)) {
    *output = static_cast<int>(*int64_value);
    return true;
  }
  return false;
}

bool CopyRgbaImageToClipboard(HWND hwnd,
                              int width,
                              int height,
                              const std::vector<uint8_t>& rgba) {
  if (width <= 0 || height <= 0) {
    return false;
  }

  const size_t stride = static_cast<size_t>(width) * 4;
  const size_t image_size = stride * static_cast<size_t>(height);
  if (rgba.size() != image_size) {
    return false;
  }

  const size_t allocation_size = sizeof(BITMAPINFOHEADER) + image_size;
  HGLOBAL clipboard_data = GlobalAlloc(GMEM_MOVEABLE, allocation_size);
  if (!clipboard_data) {
    return false;
  }

  void* locked_data = GlobalLock(clipboard_data);
  if (!locked_data) {
    GlobalFree(clipboard_data);
    return false;
  }

  auto* header = reinterpret_cast<BITMAPINFOHEADER*>(locked_data);
  std::memset(header, 0, sizeof(BITMAPINFOHEADER));
  header->biSize = sizeof(BITMAPINFOHEADER);
  header->biWidth = width;
  header->biHeight = -height;
  header->biPlanes = 1;
  header->biBitCount = 32;
  header->biCompression = BI_RGB;
  header->biSizeImage = static_cast<DWORD>(image_size);

  auto* pixels = reinterpret_cast<uint8_t*>(header + 1);
  for (size_t index = 0; index < image_size; index += 4) {
    pixels[index] = rgba[index + 2];
    pixels[index + 1] = rgba[index + 1];
    pixels[index + 2] = rgba[index];
    pixels[index + 3] = rgba[index + 3];
  }
  GlobalUnlock(clipboard_data);

  if (!OpenClipboard(hwnd)) {
    GlobalFree(clipboard_data);
    return false;
  }

  EmptyClipboard();
  if (!SetClipboardData(CF_DIB, clipboard_data)) {
    CloseClipboard();
    GlobalFree(clipboard_data);
    return false;
  }

  CloseClipboard();
  return true;
}

void HandleImageClipboardMethod(
    HWND hwnd,
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("copyImage") != 0) {
    result->NotImplemented();
    return;
  }

  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!arguments) {
    result->Error("bad_args", "Invalid image clipboard arguments.");
    return;
  }

  int width = 0;
  int height = 0;
  if (!ReadIntValue(FindMapValue(*arguments, "width"), &width) ||
      !ReadIntValue(FindMapValue(*arguments, "height"), &height)) {
    result->Error("bad_args", "Invalid image dimensions.");
    return;
  }

  const auto* rgba_value = FindMapValue(*arguments, "rgba");
  const auto* rgba = rgba_value == nullptr
                         ? nullptr
                         : std::get_if<std::vector<uint8_t>>(rgba_value);
  if (!rgba) {
    result->Error("bad_args", "Invalid image bytes.");
    return;
  }

  if (!CopyRgbaImageToClipboard(hwnd, width, height, *rgba)) {
    result->Error("copy_failed", "Failed to copy image to clipboard.");
    return;
  }

  result->Success();
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  image_clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "mint_image/image_clipboard",
          &flutter::StandardMethodCodec::GetInstance());
  image_clipboard_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleImageClipboardMethod(GetHandle(), call, std::move(result));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  image_clipboard_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
