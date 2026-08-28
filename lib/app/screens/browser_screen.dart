import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/search_viewmodel.dart';

/// 浏览器页
/// 统一使用 url_launcher 打开系统/外部浏览器
/// （跨平台：Android/Windows/Web 均支持）
class BrowserScreen extends StatelessWidget {
  final String url;
  const BrowserScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) vm.backFromBrowser(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '退出浏览器',
            onPressed: vm.backFromBrowser,
          ),
          title: Text(url,
            maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.article),
              tooltip: '提取当前网页正文',
              onPressed: () => vm.extractContent(url),
            ),
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: '提取并翻译当前网页',
              onPressed: () => vm.extractAndTranslate(url),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.open_in_new, size: 48),
                const SizedBox(height: 16),
                const Text('正在打开外部浏览器...'),
                const SizedBox(height: 8),
                SelectableText(url,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('在浏览器中打开'),
                  onPressed: () =>
                      launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: vm.backFromBrowser,
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}