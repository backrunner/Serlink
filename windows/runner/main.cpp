#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kWindowTitle[] = L"Serlink";

#ifndef _DEBUG
// One Serlink process owns the local profile. A second launch brings the
// running window forward instead of failing on the profile lock.
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\com.alkinum.serlink.single-instance";

bool ActivateRunningInstance() {
  HWND existing = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle);
  if (existing == nullptr) {
    return false;
  }
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  } else {
    ::ShowWindow(existing, SW_SHOW);
  }
  ::SetForegroundWindow(existing);
  return true;
}
#endif

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#ifndef _DEBUG
  HANDLE single_instance_mutex =
      ::CreateMutex(nullptr, FALSE, kSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // The first instance may still be starting before its window exists.
    for (int attempt = 0; attempt < 20; ++attempt) {
      if (ActivateRunningInstance()) {
        ::CloseHandle(single_instance_mutex);
        return EXIT_SUCCESS;
      }
      ::Sleep(100);
    }
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(1280, 800);
  if (!window.CreateCentered(kWindowTitle, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
#ifndef _DEBUG
  if (single_instance_mutex != nullptr) {
    ::CloseHandle(single_instance_mutex);
  }
#endif
  return EXIT_SUCCESS;
}
