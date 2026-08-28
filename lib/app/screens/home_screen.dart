import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../models/models.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenDrawer;
  const HomeScreen({super.key, required this.onOpenDrawer});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    _controller.text = vm.searchText;
    _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: vm.searchText.length));

    final lineCount =
        vm.searchText.split('\n').where((l) => l.trim().isNotEmpty).length;
    final supportText = lineCount > 1
        ? '并行搜索 · $lineCount 个关键词'
        : vm.selectedVertical != null
            ? '垂直搜索 · ${VerticalDomain.chineseName(vm.selectedVertical!)}'
            : '单行通用 · 多行并行';

    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
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
                                  onPressed: () {
                                    _controller.clear();
                                    vm.clearSearchText();
                                  },
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
                  tooltip: vm.selectedVertical != null
                      ? '已选择${VerticalDomain.chineseName(vm.selectedVertical!)}垂直搜索，点击切换'
                      : '选择垂直搜索领域',
                  onPressed: () => _showVerticalSheet(context, vm),
                ),
              ],
            ),
            // 已选垂直领域标签
            if (vm.selectedVertical != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('垂直搜索: ${VerticalDomain.chineseName(vm.selectedVertical!)}'),
                  onDeleted: () => vm.selectVertical(null),
                  deleteIcon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
            // 顶部菜单按钮
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.menu, size: 18),
                label: const Text('菜单'),
                onPressed: widget.onOpenDrawer,
              ),
            ),
            const Spacer(),
            if (vm.history.isNotEmpty) ...[
              Text('最近搜索',
                style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: vm.history.take(10).map((item) => ActionChip(
                  label: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () {
                    _controller.text = item;
                    vm.updateSearchText(item);
                  },
                )).toList(),
              ),
            ],
            const Spacer(),
            Text('无障碍友好的多源聚合搜索',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outlineVariant)),
          ],
        ),
      ),
    );
  }

  void _showVerticalSheet(BuildContext context, SearchViewModel vm) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('选择垂直领域',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
              ),
              // 取消垂直搜索
              if (vm.selectedVertical != null)
                ListTile(
                  title: Text('取消垂直搜索',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary)),
                  onTap: () {
                    vm.selectVertical(null);
                    Navigator.pop(sheetContext);
                  },
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: vm.verticals.map((domain) {
                    final isSelected = vm.selectedVertical == domain.key;
                    return ListTile(
                      title: Text(domain.name,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        )),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        vm.selectVertical(domain.key);
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}