#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <cstring>
#include <optional>
#include <shellapi.h>
#include <shlobj_core.h>
#include <string>
#include <variant>

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

bool ReadStringValue(const flutter::EncodableValue* value, std::string* output) {
  if (!value || !output) {
    return false;
  }
  if (const auto* string_value = std::get_if<std::string>(value)) {
    *output = *string_value;
    return true;
  }
  return false;
}

std::wstring Utf8ToWideString(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }

  std::wstring wide(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), wide.data(), size);
  return wide;
}

HGLOBAL CreateDropEffectData() {
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, sizeof(DWORD));
  if (!memory) {
    return nullptr;
  }

  void* locked = GlobalLock(memory);
  if (!locked) {
    GlobalFree(memory);
    return nullptr;
  }

  *static_cast<DWORD*>(locked) = DROPEFFECT_COPY;
  GlobalUnlock(memory);
  return memory;
}

bool CopyImageFileToClipboard(HWND hwnd, const std::wstring& path) {
  if (path.empty()) {
    return false;
  }

  const size_t path_bytes = (path.size() + 2) * sizeof(wchar_t);
  const size_t allocation_size = sizeof(DROPFILES) + path_bytes;
  HGLOBAL clipboard_data = GlobalAlloc(GMEM_MOVEABLE, allocation_size);
  if (!clipboard_data) {
    return false;
  }

  void* locked_data = GlobalLock(clipboard_data);
  if (!locked_data) {
    GlobalFree(clipboard_data);
    return false;
  }

  std::memset(locked_data, 0, allocation_size);
  auto* drop_files = static_cast<DROPFILES*>(locked_data);
  drop_files->pFiles = sizeof(DROPFILES);
  drop_files->fWide = TRUE;

  auto* file_list = reinterpret_cast<wchar_t*>(
      static_cast<char*>(locked_data) + sizeof(DROPFILES));
  std::memcpy(file_list, path.c_str(), (path.size() + 1) * sizeof(wchar_t));
  file_list[path.size() + 1] = L'\0';
  GlobalUnlock(clipboard_data);

  HGLOBAL drop_effect = CreateDropEffectData();

  if (!OpenClipboard(hwnd)) {
    GlobalFree(clipboard_data);
    if (drop_effect) {
      GlobalFree(drop_effect);
    }
    return false;
  }

  EmptyClipboard();
  if (!SetClipboardData(CF_HDROP, clipboard_data)) {
    CloseClipboard();
    GlobalFree(clipboard_data);
    if (drop_effect) {
      GlobalFree(drop_effect);
    }
    return false;
  }

  if (drop_effect) {
    const UINT drop_effect_format =
        RegisterClipboardFormat(CFSTR_PREFERREDDROPEFFECT);
    if (!SetClipboardData(drop_effect_format, drop_effect)) {
      GlobalFree(drop_effect);
    }
  }

  CloseClipboard();
  return true;
}

void HandleImageClipboardMethod(
    HWND hwnd,
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "copyImageFile") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    std::string path;
    if (!arguments ||
        !ReadStringValue(FindMapValue(*arguments, "path"), &path)) {
      result->Error("bad_args", "Invalid image file path.");
      return;
    }

    if (!CopyImageFileToClipboard(hwnd, Utf8ToWideString(path))) {
      result->Error("copy_failed", "Failed to copy image file to clipboard.");
      return;
    }

    result->Success();
    return;
  }

  result->NotImplemented();
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
