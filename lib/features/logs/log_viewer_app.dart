import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import 'request_log_page.dart';

class LogViewerApp extends StatelessWidget {
  const LogViewerApp({super.key});

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
