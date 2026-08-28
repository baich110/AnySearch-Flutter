#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>
#include <string>
#include <vector>

std::string CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
    return "";
  }
  return "Failed to attach console";
}

// Forwards the given command line arguments to the existing instance, if any.
void DispatchToProtocolCenter(HWND window) {
  // The FindWindow check in main.cpp determined an existing instance is
  // running. Forward focus to it by bringing its window to the foreground.
  if (::IsWindow(window)) {
    ::ShowWindow(window, SW_RESTORE);
    ::SetForegroundWindow(window);
  }
}

std::string WideToUtf8(const wchar_t* source) {
  if (source == nullptr || *source == L'\0') {
    return "";
  }
  int size = ::WideCharToMultiByte(CP_UTF8, 0, source, -1, nullptr, 0, nullptr,
                                   nullptr);
  if (size <= 0) {
    return "";
  }
  std::string result(size - 1, 0);
  ::WideCharToMultiByte(CP_UTF8, 0, source, -1, &result[0], size, nullptr,
                        nullptr);
  return result;
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }
  std::vector<std::string> result;
  for (int i = 1; i < argc; i++) {
    result.push_back(WideToUtf8(argv[i]));
  }
  ::LocalFree(argv);
  return result;
}