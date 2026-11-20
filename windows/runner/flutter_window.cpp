#include "flutter_window.h"

#include <commctrl.h>
#include <flutter/standard_method_codec.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr UINT_PTR kFlutterViewSubclassId = 1;

// The Flutter view fills the frameless window, so the frame never sees mouse
// hit tests at its edges. Let resize-border hits fall through to the frame.
LRESULT CALLBACK FlutterViewSubclassProc(HWND hwnd,
                                         UINT message,
                                         WPARAM wparam,
                                         LPARAM lparam,
                                         UINT_PTR subclass_id,
                                         DWORD_PTR) {
  if (message == WM_NCHITTEST) {
    HWND frame = GetAncestor(hwnd, GA_ROOT);
    if (frame != nullptr && frame != hwnd &&
        HitTestWindowResizeBorder(frame, lparam) != HTCLIENT) {
      return HTTRANSPARENT;
    }
  } else if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(hwnd, FlutterViewSubclassProc, subclass_id);
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
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
  RegisterWindowChannel();
  HWND view = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(view);
  SetWindowSubclass(view, FlutterViewSubclassProc, kFlutterViewSubclassId, 0);

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
  window_channel_ = nullptr;

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

void FlutterWindow::RegisterWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "serlink/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND hwnd = GetHandle();
        if (hwnd == nullptr) {
          result->Error("window_unavailable", "The app window is unavailable.");
          return;
        }

        const std::string& method = call.method_name();
        if (method == "activate") {
          if (IsIconic(hwnd)) {
            ShowWindow(hwnd, SW_RESTORE);
          } else {
            ShowWindow(hwnd, SW_SHOW);
          }
          SetForegroundWindow(hwnd);
          SetActiveWindow(hwnd);
          HWND child =
              flutter_controller_->view() == nullptr
                  ? nullptr
                  : flutter_controller_->view()->GetNativeWindow();
          SetFocus(child == nullptr ? hwnd : child);
          result->Success();
          return;
        }
        if (method == "minimize") {
          ShowWindow(hwnd, SW_MINIMIZE);
          result->Success();
          return;
        }
        if (method == "toggleMaximize") {
          ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success(flutter::EncodableValue(IsZoomed(hwnd) != 0));
          return;
        }
        if (method == "isMaximized") {
          result->Success(flutter::EncodableValue(IsZoomed(hwnd) != 0));
          return;
        }
        if (method == "close") {
          PostMessage(hwnd, WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        if (method == "startDrag") {
          ReleaseCapture();
          SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}
