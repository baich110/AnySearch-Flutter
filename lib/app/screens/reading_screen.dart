import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../models/models.dart';

import '../utils/markdown_utils.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final state = vm.state as UiStateReading;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) vm.backToResults(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: vm.backToResults,
          ),
          title: Semantics(header: true,
            child: const Text('提取阅读',
              style: TextStyle(fontWeight: FontWeight.bold))),
          actions: [
            if (state.isTranslating)
              const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)))
            else
              TextButton(onPressed: vm.translateContent,
                child: const Text('翻译')),
          ],
        ),
        body: _MarkdownBody(
          markdown: cleanMarkdown(state.content.markdown),
          onLinkTap: (url) {
            if (url != null) launchUrl(Uri.parse(url));
          },
        ),
      ),
    );
  }
}

class _MarkdownBody extends StatelessWidget {
  final String markdown;
  final void Function(String?) onLinkTap;

  const _MarkdownBody({required this.markdown, required this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(markdown);
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        return IndexedSemantics(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: MarkdownBody(
              data: blocks[index],
              onTapLink: (_, url, __) => onLinkTap(url),
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                h2: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                h3: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                p: const TextStyle(fontSize: 15, height: 1.5),
                code: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}