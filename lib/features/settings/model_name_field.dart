import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/theme.dart';

class ModelNameField extends StatefulWidget {
  const ModelNameField({
    super.key,
    required this.controller,
    required this.modelOptions,
    required this.fetching,
    required this.onFetchModels,
    this.validator,
  });

  final TextEditingController controller;
  final List<String> modelOptions;
  final bool fetching;
  final VoidCallback onFetchModels;
  final FormFieldValidator<String>? validator;

  @override
  State<ModelNameField> createState() => _ModelNameFieldState();
}

class _ModelNameFieldState extends State<ModelNameField> {
  final GlobalKey _fieldKey = GlobalKey();
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: '模型名',
        suffixIcon: SizedBox(
          width: 88,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: widget.fetching ? '正在获取模型列表' : '获取模型列表',
                visualDensity: VisualDensity.compact,
                onPressed: widget.fetching ? null : widget.onFetchModels,
                icon: widget.fetching
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined),
              ),
              IconButton(
                tooltip: '展开模型列表',
                visualDensity: VisualDensity.compact,
                onPressed: widget.modelOptions.isEmpty ? null : _showModelMenu,
                icon: const Icon(Icons.arrow_drop_down_rounded),
              ),
            ],
          ),
        ),
      ),
      validator: widget.validator,
      onTap: () {
        if (widget.modelOptions.isNotEmpty) {
          _showModelMenu();
        }
      },
    );
  }

  Future<void> _showModelMenu() async {
    if (_menuOpen || widget.modelOptions.isEmpty) {
      return;
    }

    final fieldContext = _fieldKey.currentContext;
    final overlay = Overlay.of(context).context.findRenderObject();
    final renderObject = fieldContext?.findRenderObject();
    if (fieldContext == null ||
        overlay is! RenderBox ||
        renderObject is! RenderBox) {
      return;
    }

    final fieldOffset = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final fieldSize = renderObject.size;
    final fieldRect = Rect.fromLTWH(
      fieldOffset.dx,
      fieldOffset.dy,
      fieldSize.width,
      fieldSize.height,
    );
    final overlayRect = Offset.zero & overlay.size;
    final menuWidth = math.max(220.0, fieldSize.width - 48);

    setState(() {
      _menuOpen = true;
    });
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(fieldRect, overlayRect),
      items: [
        for (final model in widget.modelOptions)
          PopupMenuItem<String>(
            value: model,
            child: SizedBox(
              width: menuWidth,
              child: Text(
                model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppThemeTokens.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _menuOpen = false;
    });

    if (selected == null) {
      return;
    }
    widget.controller
      ..text = selected
      ..selection = TextSelection.collapsed(offset: selected.length);
  }
}
