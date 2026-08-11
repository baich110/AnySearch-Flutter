import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';

import '../../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  bool _showVerticalSheet = false;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    _controller.text = vm.searchText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: vm.searchText.length));

    final lineCount = vm.searchText.split('\n')
      .where((l) => l.trim().isNotEmpty).length;
    final supportText = lineCount > 1
      ? '并行搜索 · $lineCount 个关键词'
      : vm.selectedVertical != null
        ? '垂直搜索 · ${VerticalDomain.chineseName(vm.selectedVertical!)}'
        : '单行通用 · 多行并行';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('搜索', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.info),
              tooltip: '关于',
              onPressed: vm.showAbout,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text('AnySearch',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: '搜索关键词',
                        hintText: '输入关键词搜索...',
                        helperText: supportText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                        suffixIcon: vm.searchText.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: '清除',
                                  onPressed: () { _controller.clear(); vm.clearSearchText(); },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.search),
                                  tooltip: '执行搜索',
                                  onPressed: vm.search,
                                ),
                              ],
                            )
                          : null,
                      ),
                      onSubmitted: (_) => vm.search(),
                      onChanged: vm.updateSearchText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.expand_more),
                    tooltip: '垂直领域',
                    onPressed: () => setState(() => _showVerticalSheet = true),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (vm.history.isNotEmpty) ...[
                Text('最近搜索',
                  style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: vm.history.take(10).map((item) =>
                    ActionChip(
                      label: Text(item, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        _controller.text = item;
                        vm.updateSearchText(item);
                      },
                    )).toList(),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}