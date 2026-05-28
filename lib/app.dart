import 'package:flutter/material.dart';

import 'features/home/home_page.dart';
import 'shared/theme.dart';

class GptImageApp extends StatelessWidget {
  const GptImageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MintImage',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}
