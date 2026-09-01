import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../models/models.dart';
import '../utils/markdown_utils.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final state = vm.state as UiStateReading;
    final effectiveRenderLinks = vm.effectiveRenderLinks();

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
          title: Semantics(
            header: true,
            child: const Text('提取阅读',
              style: TextStyle(fontWeight: FontWeight.bold))),
          actions: [
            // AI 智能排版
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI 智能排版',
              onPressed: vm.aiFormatContent,
            ),
            // 切换渲染模式（临时）
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: effectiveRenderLinks ? '切换到纯文本渲染' : '切换到带链接渲染',
              onPressed: () => vm.setTempRenderLinks(!effectiveRenderLinks),
            ),
            // 翻译
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
          renderLinks: effectiveRenderLinks,
          onLinkTap: (url) => vm.extractContent(url),
          onBrowse: (url) => vm.openInBrowser(url),
        ),
      ),
    );
  }
}

class _MarkdownBody extends StatelessWidget {
  final String markdown;
  final bool renderLinks;
  final void Function(String) onLinkTap;
  final void Function(String) onBrowse;

  const _MarkdownBody({
    required this.markdown,
    required this.renderLinks,
    required this.onLinkTap,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(markdown);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        if (renderLinks) {
          return _LinkRenderingBlock(
            block: block,
            onLinkTap: onLinkTap,
            onBrowse: onBrowse,
          );
        } else {
          // 纯文本渲染：严格中文清洗
          final plainText = extractChinesePlainText(block);
          if (plainText.trim().isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              label: plainText,
              child: Text(plainText,
                style: const TextStyle(fontSize: 15, height: 1.5)),
            ),
          );
        }
      },
    );
  }
}

/// 带链接渲染：每个链接是独立可聚焦节点
class _LinkRenderingBlock extends StatelessWidget {
  final String block;
  final void Function(String) onLinkTap;
  final void Function(String) onBrowse;

  const _LinkRenderingBlock({
    required this.block,
    required this.onLinkTap,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final segments = splitBlockIntoSegments(block);
    final hasLink = block.contains('](') && block.contains('http');

    if (!hasLink) {
      final plainText = block
          .replaceAll(RegExp(r'[#*>`_\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Semantics(
          label: plainText,
          child: Text(plainText,
            style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: segments.map((seg) {
          if (seg is TextSegment) {
            if (seg.text.trim().isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(seg.text,
                style: const TextStyle(fontSize: 15, height: 1.5)),
            );
          } else if (seg is LinkSegment) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Semantics(
                link: true,
                label: seg.text,
                // 自定义操作：读屏可"上滑/更多操作"选择"浏览器打开"（对齐安卓版）
                customSemanticsActions: {
                  const CustomSemanticsAction(label: '浏览器打开'):
                      () => onBrowse(seg.url),
                },
                child: InkWell(
                  onTap: () => onLinkTap(seg.url),
                  child: Text(seg.text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    )),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }
}