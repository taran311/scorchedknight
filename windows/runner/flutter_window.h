#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>

#include "win32_window.h"

// The game's window: hosts the Flutter view, and answers the game on "scorchedknight/window"
// (fullscreen on and off, and quitting to the desktop from the settings).
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

  // The game's line to the window.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> window_channel_;

  // Borderless fullscreen over the whole monitor the window is on, or back to the window it was.
  void SetFullscreen(bool on);
  bool fullscreen_ = false;
  LONG saved_style_ = 0;
  WINDOWPLACEMENT saved_placement_ = {sizeof(WINDOWPLACEMENT)};
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
