import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../services/storage_service.dart';
import '../../models/models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final items = vm.fullHistory;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) vm.backToHome(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: vm.backToHome,
          ),
          title: Semantics(
            header: true,
            child: Text('历史记录 · ${items.length} 条',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          actions: [
            if (items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空所有历史',
                onPressed: () => _confirmClearAll(context, vm),
              ),
          ],
        ),
        body: items.isEmpty
            ? const Center(child: Text('暂无历史记录'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _HistoryCard(item: item, vm: vm);
                },
              ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, SearchViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有搜索历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              vm.clearAllHistory();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final StoredHistoryItem item;
  final SearchViewModel vm;
  const _HistoryCard({required this.item, required this.vm});

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
    final timeStr = '${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    final resultCount = item.results.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(item.query,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$timeStr · $resultCount 条结果'
          '${item.vertical != null ? ' · 垂直:${VerticalDomain.chineseName(item.vertical!)}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新搜索',
              onPressed: () => vm.reSearchFromHistory(item.query),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除',
              onPressed: () => vm.deleteHistoryItem(item.id),
            ),
          ],
        ),
        onTap: () => vm.loadFromHistory(item),
      ),
    );
  }
}