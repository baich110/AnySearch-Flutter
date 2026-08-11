import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'app/app.dart';
import 'app/window_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 强制启用语义树 -- 桌面端 NVDA / 移动端 TalkBack 必须
  SemanticsBinding.instance.ensureSemantics();

  // 桌面端窗口初始化
  initWindowManager();

  runApp(const AnySearchApp());
}
