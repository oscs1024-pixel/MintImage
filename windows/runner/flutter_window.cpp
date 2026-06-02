#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cwchar>
#include <cwctype>
#include <cstring>
#include <gdiplus.h>
#include <iterator>
#include <memory>
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

std::string WideStringToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }

  const int size = WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }

  std::string utf8(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), utf8.data(), size,
                      nullptr, nullptr);
  return utf8;
}

bool IsSupportedImagePath(const std::wstring& path) {
  const size_t dot_index = path.find_last_of(L'.');
  if (dot_index == std::wstring::npos) {
    return false;
  }

  std::wstring extension = path.substr(dot_index);
  std::transform(extension.begin(), extension.end(), extension.begin(),
                 [](wchar_t character) {
                   return static_cast<wchar_t>(std::towlower(character));
                 });
  return extension == L".png" || extension == L".jpg" ||
         extension == L".jpeg" || extension == L".webp";
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

std::optional<std::wstring> ReadDroppedImagePathFromClipboard() {
  auto* drop = static_cast<HDROP>(GetClipboardData(CF_HDROP));
  if (!drop) {
    return std::nullopt;
  }

  const UINT file_count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT index = 0; index < file_count; ++index) {
    const UINT path_length = DragQueryFileW(drop, index, nullptr, 0);
    if (path_length == 0) {
      continue;
    }

    std::wstring path(path_length + 1, L'\0');
    DragQueryFileW(drop, index, path.data(), path_length + 1);
    path.resize(path_length);
    if (IsSupportedImagePath(path)) {
      return path;
    }
  }

  return std::nullopt;
}

std::optional<std::wstring> CreateTemporaryPngPath() {
  wchar_t temp_directory[MAX_PATH + 1] = {};
  const DWORD directory_length =
      GetTempPathW(static_cast<DWORD>(std::size(temp_directory)),
                   temp_directory);
  if (directory_length == 0 || directory_length > MAX_PATH) {
    return std::nullopt;
  }

  wchar_t temp_file[MAX_PATH + 1] = {};
  if (GetTempFileNameW(temp_directory, L"mic", 0, temp_file) == 0) {
    return std::nullopt;
  }
  DeleteFileW(temp_file);

  std::wstring path(temp_file);
  const size_t dot_index = path.find_last_of(L'.');
  if (dot_index == std::wstring::npos) {
    path += L".png";
  } else {
    path = path.substr(0, dot_index) + L".png";
  }
  return path;
}

bool GetPngEncoderClsid(CLSID* clsid) {
  if (!clsid) {
    return false;
  }

  UINT encoder_count = 0;
  UINT encoder_bytes = 0;
  if (Gdiplus::GetImageEncodersSize(&encoder_count, &encoder_bytes) !=
          Gdiplus::Ok ||
      encoder_bytes == 0) {
    return false;
  }

  auto memory = std::make_unique<BYTE[]>(encoder_bytes);
  auto* encoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(memory.get());
  if (Gdiplus::GetImageEncoders(encoder_count, encoder_bytes, encoders) !=
      Gdiplus::Ok) {
    return false;
  }

  for (UINT index = 0; index < encoder_count; ++index) {
    if (std::wcscmp(encoders[index].MimeType, L"image/png") == 0) {
      *clsid = encoders[index].Clsid;
      return true;
    }
  }

  return false;
}

bool SaveBitmapToPngFile(HBITMAP bitmap, const std::wstring& path) {
  if (!bitmap || path.empty()) {
    return false;
  }

  Gdiplus::GdiplusStartupInput startup_input;
  ULONG_PTR gdiplus_token = 0;
  if (Gdiplus::GdiplusStartup(&gdiplus_token, &startup_input, nullptr) !=
      Gdiplus::Ok) {
    return false;
  }

  CLSID png_encoder = {};
  const bool has_encoder = GetPngEncoderClsid(&png_encoder);
  bool success = false;
  if (has_encoder) {
    Gdiplus::Bitmap image(bitmap, nullptr);
    success = image.Save(path.c_str(), &png_encoder, nullptr) == Gdiplus::Ok;
  }

  Gdiplus::GdiplusShutdown(gdiplus_token);
  return success;
}

size_t DibColorTableSize(const BITMAPINFOHEADER& header) {
  if (header.biClrUsed > 0) {
    return static_cast<size_t>(header.biClrUsed) * sizeof(RGBQUAD);
  }

  if (header.biBitCount <= 8) {
    return static_cast<size_t>(1ull << header.biBitCount) * sizeof(RGBQUAD);
  }

  if (header.biCompression == BI_BITFIELDS &&
      header.biSize == static_cast<DWORD>(sizeof(BITMAPINFOHEADER))) {
    return 3 * sizeof(DWORD);
  }

  return 0;
}

HBITMAP CreateBitmapFromDibClipboardData(HGLOBAL dib_data) {
  if (!dib_data) {
    return nullptr;
  }

  auto* bitmap_info = static_cast<BITMAPINFO*>(GlobalLock(dib_data));
  if (!bitmap_info) {
    return nullptr;
  }

  const BITMAPINFOHEADER& header = bitmap_info->bmiHeader;
  if (header.biSize < static_cast<DWORD>(sizeof(BITMAPINFOHEADER))) {
    GlobalUnlock(dib_data);
    return nullptr;
  }

  const size_t bits_offset =
      static_cast<size_t>(header.biSize) + DibColorTableSize(header);
  const auto* bits = reinterpret_cast<const BYTE*>(bitmap_info) + bits_offset;
  HDC screen_dc = GetDC(nullptr);
  HBITMAP bitmap = CreateDIBitmap(screen_dc, &header, CBM_INIT, bits,
                                  bitmap_info, DIB_RGB_COLORS);
  ReleaseDC(nullptr, screen_dc);
  GlobalUnlock(dib_data);
  return bitmap;
}

std::optional<std::wstring> SaveClipboardBitmapToTemporaryPng() {
  HBITMAP clipboard_bitmap = nullptr;
  bool should_delete_bitmap = false;

  if (IsClipboardFormatAvailable(CF_BITMAP)) {
    clipboard_bitmap = static_cast<HBITMAP>(GetClipboardData(CF_BITMAP));
  }

  if (!clipboard_bitmap && IsClipboardFormatAvailable(CF_DIB)) {
    clipboard_bitmap = CreateBitmapFromDibClipboardData(
        static_cast<HGLOBAL>(GetClipboardData(CF_DIB)));
    should_delete_bitmap = clipboard_bitmap != nullptr;
  }

  if (!clipboard_bitmap) {
    return std::nullopt;
  }

  const auto path = CreateTemporaryPngPath();
  if (!path.has_value()) {
    if (should_delete_bitmap) {
      DeleteObject(clipboard_bitmap);
    }
    return std::nullopt;
  }

  const bool saved = SaveBitmapToPngFile(clipboard_bitmap, path.value());
  if (should_delete_bitmap) {
    DeleteObject(clipboard_bitmap);
  }

  if (!saved) {
    DeleteFileW(path.value().c_str());
    return std::nullopt;
  }
  return path;
}

std::optional<std::wstring> ReadImageFileFromClipboard(HWND hwnd) {
  if (!OpenClipboard(hwnd)) {
    return std::nullopt;
  }

  auto path = ReadDroppedImagePathFromClipboard();
  if (!path.has_value()) {
    path = SaveClipboardBitmapToTemporaryPng();
  }

  CloseClipboard();
  return path;
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

  if (method_call.method_name() == "readImageFile") {
    const auto path = ReadImageFileFromClipboard(hwnd);
    if (!path.has_value()) {
      result->Success();
      return;
    }

    result->Success(flutter::EncodableMap{
        {flutter::EncodableValue("path"),
         flutter::EncodableValue(WideStringToUtf8(path.value()))},
    });
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
