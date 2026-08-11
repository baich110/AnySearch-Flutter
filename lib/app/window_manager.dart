import 'dart:io';
import 'package:flutter/foundation.dart';

/// 桌面端窗口管理初始化
/// 仅在 Windows / macOS / Linux 桌面端执行
void initWindowManager() {
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    // window_manager 包的初始化在 app.dart 中通过 WindowLifecycleMixin 完成
    // 这里仅做标记
    debugPrint('Desktop platform detected: \${Platform.operatingSystem}');
  }
}
