import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../models/models.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final state = vm.state as UiStateResults;
    final totalCount = state.grouped.values.fold<int>(0, (s, l) => s + l.length);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) vm.backFromHistoryResults(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回搜索',
            onPressed: vm.backFromHistoryResults,
          ),
          title: Semantics(header: true, child: Text(
            '搜索结果 · $totalCount 条',
            style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
        body: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: state.grouped.values.fold<int>(0, (s, l) => s + l.length),
          itemBuilder: (context, index) {
            final flat = state.grouped.values.expand((l) => l).toList();
            final result = flat[index];
            return _ResultCard(
              result: result,
              index: index,
              onRead: () { vm.extractContent(result.url); },
              onBrowse: () { vm.openInBrowser(result.url); },
              onReadTranslate: () { vm.extractAndTranslate(result.url); },
            );
          },
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final int index;
  final VoidCallback onRead;
  final VoidCallback onBrowse;
  final VoidCallback onReadTranslate;

  const _ResultCard({required this.result, required this.index,
    required this.onRead, required this.onBrowse,
    required this.onReadTranslate});

  @override
  Widget build(BuildContext context) {
    final desc = StringBuffer(result.title);
    if (result.snippet.trim().isNotEmpty) desc.write('，摘要：${result.snippet}');
    if (result.source.isNotEmpty) desc.write('，来源：${result.source}');
    desc.write('，点按或回车提取正文阅读');

    return IndexedSemantics(
      index: index,
      child: Semantics(
        label: desc.toString(),
        button: true,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: onRead,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(result.snippet,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (result.source.isNotEmpty)
                            Text(result.source,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary)),
                          if (result.date.isNotEmpty)
                            Text(result.date,
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      Row(
                        children: [
                          Text('提取正文 ›',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.translate, size: 18),
                            tooltip: '提取并翻译',
                            onPressed: onReadTranslate,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            tooltip: '浏览器打开',
                            onPressed: onBrowse,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}