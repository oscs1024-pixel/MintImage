import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme.dart';
import '../../shared/window_lifecycle_channel.dart';
import 'request_log_page.dart';

class LogViewerApp extends StatefulWidget {
  const LogViewerApp({super.key});

  @override
  State<LogViewerApp> createState() => _LogViewerAppState();
}

class _LogViewerAppState extends State<LogViewerApp> {
  bool get _supportsWindowLifecycle =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  void initState() {
    super.initState();
    if (_supportsWindowLifecycle) {
      // native runner 在收到关闭请求时会调用 window_lifecycle channel 等待
      // Dart 决定是否关闭。日志窗口没有任何需要拦截的任务，直接放行，
      // 否则点击右上角关闭按钮会被 native 拦截后无人响应导致无法关闭。
      windowLifecycleChannel.setMethodCallHandler(_handleNativeCall);
    }
  }

  @override
  void dispose() {
    if (_supportsWindowLifecycle) {
      windowLifecycleChannel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  Future<bool> _handleNativeCall(MethodCall call) async {
    // 始终允许立即关闭日志窗口。
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '请求日志',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RequestLogPage(pollFileChanges: true),
    );
  }
}
