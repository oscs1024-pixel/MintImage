import 'package:flutter/services.dart';

/// Method channel shared with the Windows / macOS runners to intercept window
/// close requests.
///
/// Flutter 的 `AppLifecycleListener.onExitRequested` 在桌面端依赖引擎的
/// `WindowsLifecycleManager` 启发式判断（要求当前窗口是进程内唯一的顶层窗口），
/// 一旦插件或系统创建了任何隐藏顶层窗口就会失效，导致点击关闭按钮直接退出。
/// 因此这里改为由 native runner 主动拦截关闭事件，再回调 Dart 决定是否退出。
const windowLifecycleChannel = MethodChannel('mint_image/window_lifecycle');
