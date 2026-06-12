import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/generation_provider.dart';
import 'features/home/home_page.dart';
import 'shared/theme.dart';

/// Method channel shared with the Windows / macOS runners to intercept window
/// close requests.
///
/// Flutter 的 [AppLifecycleListener.onExitRequested] 在桌面端依赖引擎的
/// `WindowsLifecycleManager` 启发式判断（要求当前窗口是进程内唯一的顶层窗口），
/// 一旦插件或系统创建了任何隐藏顶层窗口就会失效，导致点击关闭按钮直接退出。
/// 因此这里改为由 native runner 主动拦截关闭事件，再回调 Dart 决定是否退出。
@visibleForTesting
const windowLifecycleChannel = MethodChannel('mint_image/window_lifecycle');

class GptImageApp extends ConsumerStatefulWidget {
  const GptImageApp({super.key, @visibleForTesting this.home});

  final Widget? home;

  @override
  ConsumerState<GptImageApp> createState() => _GptImageAppState();
}

class _GptImageAppState extends ConsumerState<GptImageApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppLifecycleListener? _appLifecycleListener;
  Future<bool>? _pendingExitConfirmation;

  bool get _supportsExitConfirmation =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  void initState() {
    super.initState();
    if (_supportsExitConfirmation) {
      // 主路径：native runner 拦截关闭按钮后回调此 channel。
      windowLifecycleChannel.setMethodCallHandler(_handleNativeCall);
    }
    // 兜底：保留 onExitRequested，用于覆盖能正常发出该信号的退出场景
    // （例如系统注销 / 应用主动 exitApplication）。
    _appLifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
    );
  }

  @override
  void dispose() {
    if (_supportsExitConfirmation) {
      windowLifecycleChannel.setMethodCallHandler(null);
    }
    _appLifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'MintImage',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: widget.home ?? const HomePage(),
    );
  }

  /// 由 native runner 在收到窗口关闭请求时调用。
  ///
  /// 返回 `true` 表示允许立即关闭；返回 `false` 表示拦截，由 Dart 自行
  /// 在确认后通过 `performClose` 主动让 native 关闭窗口。
  Future<bool> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onCloseRequested') {
      return true;
    }

    if (!ref.read(generationProvider).isGenerating) {
      return true;
    }

    final confirmed = await _confirmExit();
    if (confirmed) {
      // 用户确认退出：让 native 真正关闭窗口（绕过本次拦截）。
      await windowLifecycleChannel.invokeMethod<void>('performClose');
    }
    return false;
  }

  Future<AppExitResponse> _handleExitRequested() async {
    if (!_supportsExitConfirmation ||
        !ref.read(generationProvider).isGenerating) {
      return AppExitResponse.exit;
    }

    final confirmed = await _confirmExit();
    return confirmed ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  Future<bool> _confirmExit() {
    final pendingConfirmation = _pendingExitConfirmation;
    if (pendingConfirmation != null) {
      return pendingConfirmation;
    }

    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      return Future.value(false);
    }

    final confirmation = showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认退出？'),
          content: const Text('当前仍有图片正在生成，退出会中断这些任务。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续生成'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);

    _pendingExitConfirmation = confirmation;
    confirmation.whenComplete(() {
      _pendingExitConfirmation = null;
    });
    return confirmation;
  }
}
