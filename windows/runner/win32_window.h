#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

class Win32Window {
 public:
  struct Point { unsigned int x; unsigned int y; };
  struct Size { unsigned int width; unsigned int height; };

  Win32Window();n  virtual ~Win32Window();

  bool Create(const std::wstring& title, const Point& origin, const Size& size);
  bool Show();
  void Destroy();
  void SetChildContent(HWND window);
  void SetQuitOnClose(bool quit_on_close);
  HWND GetHandle();

 protected:
  virtual bool OnCreate();
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam);

  HWND window_handle_ = nullptr;
  bool quit_on_close_ = false;
};

#endif  // RUNNER_WIN32_WINDOW_H_