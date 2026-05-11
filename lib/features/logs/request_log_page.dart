import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/request_log_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/empty_state.dart';

class RequestLogPage extends ConsumerStatefulWidget {
  const RequestLogPage({super.key, this.pollFileChanges = false});

  final bool pollFileChanges;

  @override
  ConsumerState<RequestLogPage> createState() => _RequestLogPageState();
}

class _RequestLogPageState extends ConsumerState<RequestLogPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.pollFileChanges) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(ref.read(requestLogServiceProvider).reload());
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logService = ref.watch(requestLogServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('请求日志'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => logService.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppThemeTokens.canvas, AppThemeTokens.canvasTint],
          ),
        ),
        child: AnimatedBuilder(
          animation: logService,
          builder: (context, _) {
            final entries = logService.entries.reversed.toList(growable: false);
            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 32),
                children: const [
                  SizedBox(height: 48),
                  EmptyState(
                    title: '暂无请求日志',
                    description: '发起一次生成或改图请求后，这里会显示详细的请求与响应记录。',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: entries.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _LogOverviewCard(
                    count: entries.length,
                    filePath: logService.filePath,
                  );
                }

                final entry = entries[index - 1];
                return _LogEntryCard(entry: entry);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LogOverviewCard extends StatelessWidget {
  const _LogOverviewCard({required this.count, required this.filePath});

  final int count;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: 24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppThemeTokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '最近 $count 条请求日志',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            filePath,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppThemeTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({required this.entry});

  final RequestLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: 22),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              _LogLevelChip(level: entry.level),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatTimestamp(entry.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeTokens.textSecondary,
              ),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                entry.details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: AppThemeTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '${timestamp.year}-$month-$day $hour:$minute:$second';
  }
}

class _LogLevelChip extends StatelessWidget {
  const _LogLevelChip({required this.level});

  final RequestLogLevel level;

  @override
  Widget build(BuildContext context) {
    late final Color backgroundColor;
    late final Color foregroundColor;
    late final String label;

    switch (level) {
      case RequestLogLevel.info:
        backgroundColor = AppThemeTokens.surfaceSoft;
        foregroundColor = AppThemeTokens.primaryStrong;
        label = '信息';
      case RequestLogLevel.request:
        backgroundColor = const Color(0xFFE8F3FF);
        foregroundColor = const Color(0xFF1667C5);
        label = '请求';
      case RequestLogLevel.response:
        backgroundColor = const Color(0xFFE4F6EE);
        foregroundColor = const Color(0xFF177245);
        label = '响应';
      case RequestLogLevel.error:
        backgroundColor = AppThemeTokens.dangerSurface;
        foregroundColor = AppThemeTokens.dangerText;
        label = '错误';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
