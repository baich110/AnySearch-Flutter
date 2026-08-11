/// Markdown 工具函数
/// 从 Kotlin CleanMarkdownRenderer.kt 翻译

/// 按逻辑块切分 Markdown
List<String> parseMarkdownBlocks(String markdown) {
  final blocks = <String>[];
  final current = StringBuffer();
  var inCodeBlock = false;

  for (final line in markdown.split('\n')) {
    if (line.trim().startsWith('```')) {
      if (inCodeBlock) {
        current.write('\n$line');
        blocks.add(current.toString().trimRight());
        current.clear();
        inCodeBlock = false;
      } else {
        if (current.isNotEmpty) {
          blocks.add(current.toString().trimRight());
          current.clear();
        }
        current.write(line);
        inCodeBlock = true;
      }
      continue;
    }
    if (inCodeBlock) { current.write('\n$line'); continue; }
    if (line.trim().isEmpty) {
      if (current.isNotEmpty) {
        blocks.add(current.toString().trimRight());
        current.clear();
      }
    } else {
      if (current.isNotEmpty) current.write('\n');
      current.write(line);
    }
  }
  if (current.isNotEmpty) blocks.add(current.toString().trimRight());
  return blocks.where((b) => b.trim().isNotEmpty).toList();
}

/// 清洗 Markdown 文本 -- 去除网页噪音
String cleanMarkdown(String markdown) {
  var lines = markdown.split('\n');

  // 第1层：杀噪音行
  lines = lines.where((line) {
    final t = line.trim();
    if (t.isEmpty) return true;
    if (t.contains('[编辑]')) return false;
    if (t.startsWith('[跳转到内容]')) return false;
    if (t == '维基百科，自由的百科全书') return false;
    if (t.startsWith('此条目')) return false;
    if (t.startsWith('关于') && t.contains('请见')) return false;
    if (t.contains('upload.wikimedia.org')) return false;
    if (t.startsWith('（重定向自')) return false;
    if (t.contains('最新推荐文章于')) return false;
    if (t.contains('版权声明')) return false;
    if (t.contains('本内容遵循CC')) return false;
    if (t.contains('请附上原文')) return false;
    if (t.contains('转载请附上')) return false;
    if (t.contains('本文为博主')) return false;
    if (t.contains('csdnimg.cn')) return false;
    if (t.contains('关注者') && RegExp(r'关注者\d+').hasMatch(t)) return false;
    if (t.contains('被浏览') && RegExp(r'被浏览\d+').hasMatch(t)) return false;
    if (RegExp(r'^\[\[\d+\]\]$').hasMatch(t)) return false;
    if (t.startsWith('.mw-parser-output')) return false;
    if (RegExp(r'^\..*\{.*\}').hasMatch(t)) return false;
    if (RegExp(r'^<[^>]+>$').hasMatch(t) &&
        !t.startsWith('<img') && !t.startsWith('<br')) return false;
    return true;
  }).toList();

  // 第2层：行内清洗
  lines = lines.map((line) {
    return line
      .replaceAll(RegExp(r'\[([^\]]*?)\]\([^\)]*?\)'), r'$1')
      .replaceAll(RegExp(r'\[\[\d+\]\]'), '')
      .replaceAll('[编辑]', '')
      .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), '')
      .replaceAll(RegExp(r'<small[^>]*>.*?</small>'), '')
      .replaceAll(RegExp(r'<span[^>]*>(.*?)</span>'), r'$1')
      .replaceAll(RegExp(r'<a[^>]*>(.*?)</a>'), r'$1')
      .trim();
  }).toList();

  // 第3层：压缩连续空行
  final result = <String>[];
  for (final line in lines) {
    if (line.trim().isEmpty &&
        result.isNotEmpty && result.last.trim().isEmpty) {
      continue;
    }
    result.add(line);
  }

  // 去首尾空行
  while (result.isNotEmpty && result.first.trim().isEmpty) {
    result.removeAt(0);
  }
  while (result.isNotEmpty && result.last.trim().isEmpty) {
    result.removeLast();
  }

  return result.join('\n');
}