/// Markdown 工具函数
/// 从 Kotlin CleanMarkdownRenderer.kt 完整翻译

/// 块内片段：普通文本 或 链接
sealed class BlockSegment {
  const BlockSegment();
}

class TextSegment extends BlockSegment {
  final String text;
  const TextSegment(this.text);
}

class LinkSegment extends BlockSegment {
  final String text;
  final String url;
  const LinkSegment(this.text, this.url);
}

/// 是否为中文字符
bool isChineseChar(int code) {
  return (code >= 0x4E00 && code <= 0x9FFF) ||
      (code >= 0x3400 && code <= 0x4DBF) ||
      (code >= 0xF900 && code <= 0xFAFF) ||
      code == 0x3007;
}

/// 是否为中文标点
bool isChinesePunct(int code) {
  const puncts = '。，、；：！？…—""''（）《》〈〉【】「」『』';
  for (final c in puncts.runes) {
    if (c == code) return true;
  }
  return false;
}

/// 严格中文纯文本清洗：只保留干净的中文纯文本
String extractChinesePlainText(String raw) {
  var noLinks = raw
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'),
          (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'\[\]\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\[\[\d+\]\]'), ' ')
      .replaceAll(RegExp(r'\[\d+\]'), ' ')
      .replaceAll(RegExp(r'https?://[^\s)\]]+'), ' ')
      .replaceAll(
          RegExp(
              r'\b[a-zA-Z0-9]+\.(?:wikipedia|wikidata|org|com|net|edu|gov|io|github)[a-zA-Z0-9./?=&:%#_\-]*'),
          ' ');

  final cleaned = StringBuffer();
  for (final line in noLinks.split('\n')) {
    final seg = line.trim();
    if (seg.contains(RegExp(r'.*https?://.*')) ||
        seg.contains(RegExp(r'[a-zA-Z0-9._\-/%]+\.(svg|png|jpg|jpeg|gif|webp)',
            caseSensitive: false))) {
      continue;
    }
    var letterCount = 0, englishCount = 0;
    for (final r in seg.runes) {
      if (r >= 65 && r <= 90 || r >= 97 && r <= 122) englishCount++;
      if ((r >= 65 && r <= 90) || (r >= 97 && r <= 122) ||
          (r >= 0x4e00 && r <= 0x9fff)) letterCount++;
    }
    final isEnglishDominant =
        letterCount > 0 && englishCount.toDouble() / letterCount > 0.4;
    if (isEnglishDominant) {
      final sb = StringBuffer();
      for (final r in seg.runes) {
        if ((r >= 65 && r <= 90) || (r >= 97 && r <= 122) ||
            (r >= 48 && r <= 57) || r == 32) {
          sb.writeCharCode(r);
        } else if ('.,;:!?()[]\'"-–—%/'.contains(String.fromCharCode(r))) {
          sb.writeCharCode(r);
        } else {
          sb.write(' ');
        }
      }
      cleaned.write(sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim());
      cleaned.write('\n');
    } else {
      final sb = StringBuffer();
      final wordBuf = StringBuffer();
      void flushWord() {
        if (wordBuf.isNotEmpty) {
          if (sb.isNotEmpty) sb.write(' ');
          sb.write(wordBuf.toString());
          wordBuf.clear();
        }
      }

      for (final r in seg.runes) {
        if (isChineseChar(r)) {
          flushWord();
          sb.writeCharCode(r);
        } else if (isChinesePunct(r)) {
          flushWord();
          sb.writeCharCode(r);
        } else if ((r >= 48 && r <= 57) || (r >= 65 && r <= 90) ||
            (r >= 97 && r <= 122)) {
          wordBuf.writeCharCode(r);
        } else {
          flushWord();
        }
      }
      flushWord();
      cleaned.write(sb.toString());
      cleaned.write('\n');
    }
  }

  return cleaned.toString()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .trim();
}

/// 把单个 markdown block 按链接拆分成片段序列
List<BlockSegment> splitBlockIntoSegments(String block) {
  final segments = <BlockSegment>[];
  final linkRegex = RegExp(r'\[([^\]]*)\]\((https?://[^)]+)\)');
  var lastEnd = 0;
  for (final m in linkRegex.allMatches(block)) {
    if (m.start > lastEnd) {
      segments.add(TextSegment(block.substring(lastEnd, m.start)));
    }
    final text = (m.group(1) ?? '').isNotEmpty ? m.group(1)! : m.group(2)!;
    segments.add(LinkSegment(text, m.group(2)!.trim()));
    lastEnd = m.end;
  }
  if (lastEnd < block.length) {
    segments.add(TextSegment(block.substring(lastEnd)));
  }
  return segments;
}

/// 按逻辑块切分 Markdown（含超长保护）
List<String> parseMarkdownBlocks(String markdown) {
  final blocks = <String>[];
  final current = StringBuffer();
  var inCodeBlock = false;
  const sentenceEnd = '。！？!?....…';
  const noBreakEnd = '，,、；;：:';
  const maxBlockLen = 800;

  void flush() {
    final text = current.toString().trimRight();
    current.clear();
    if (text.trim().isEmpty) return;
    if (text.length > maxBlockLen) {
      blocks.addAll(splitLongBlock(text, maxBlockLen));
    } else {
      blocks.add(text);
    }
  }

  for (final line in markdown.split('\n')) {
    final t = line.trim();
    if (t.startsWith('```')) {
      if (inCodeBlock) {
        current.write('\n$line');
        flush();
        inCodeBlock = false;
      } else {
        flush();
        current.write(line);
        inCodeBlock = true;
      }
      continue;
    }
    if (inCodeBlock) {
      current.write('\n$line');
      continue;
    }
    if (t.isEmpty) {
      flush();
      continue;
    }
    if (current.isNotEmpty) {
      final prev = current.toString().split('\n').last.trim();
      var isNewBlock = false;
      if (t.startsWith('#') || t.startsWith('- ') || t.startsWith('* ') ||
          t.startsWith('>') || t.startsWith('|')) {
        isNewBlock = true;
      } else if (prev.isNotEmpty && prev.length <= 25 &&
          !sentenceEnd.contains(prev[prev.length - 1]) &&
          !noBreakEnd.contains(prev[prev.length - 1]) &&
          t.length > prev.length) {
        isNewBlock = true;
      } else if (prev.isNotEmpty &&
          sentenceEnd.contains(prev[prev.length - 1])) {
        isNewBlock = true;
      } else if (current.length > maxBlockLen && prev.isNotEmpty &&
          sentenceEnd.contains(prev[prev.length - 1])) {
        isNewBlock = true;
      } else if (current.length > maxBlockLen * 2) {
        isNewBlock = true;
      }
      if (isNewBlock) flush();
    }
    if (current.isNotEmpty) current.write('\n');
    current.write(line);
  }
  flush();
  return blocks.where((b) => b.trim().isNotEmpty).toList();
}

/// 把超长块按句子拆成小块
List<String> splitLongBlock(String text, int maxLen) {
  final result = <String>[];
  final current = StringBuffer();
  const sentenceEnd = '。！？!?....…';
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    current.write(ch);
    if (sentenceEnd.contains(ch) && current.length >= maxLen ~/ 2) {
      result.add(current.toString().trim());
      current.clear();
    } else if (current.length >= maxLen && !sentenceEnd.contains(ch)) {
      result.add(current.toString().trim());
      current.clear();
    }
  }
  if (current.toString().trim().isNotEmpty) {
    result.add(current.toString().trim());
  }
  return result.where((b) => b.trim().isNotEmpty).toList();
}

/// 清洗 Markdown 文本 -- 去除网页噪音
String cleanMarkdown(String markdown) {
  final lines = markdown.split('\n');

  // 第1层：杀整行噪音
  final filtered = <String>[];
  for (final rawLine in lines) {
    final t = rawLine.trim();
    if (t.isEmpty) {
      filtered.add(rawLine);
      continue;
    }
    if (t.contains('[编辑]') || t.contains('[edit]')) continue;
    if (t.startsWith('[跳转到内容]') || t.startsWith('[Jump to content]') ||
        t.startsWith('[字符至容]')) continue;
    if (t == '维基百科，自由的百科全书' ||
        t == 'From Wikipedia, the free encyclopedia' ||
        t == '文出維基大典' || t == '出自維基百科') continue;
    if (t.startsWith('此条目') ||
        (t.startsWith('关于') && t.contains('请见'))) continue;
    if (t.contains('//upload.wikimedia.org/')) continue;
    if (t.startsWith('（重定向自') || t.startsWith('(Redirected from')) continue;
    if (t.startsWith('Find sources:') ||
        t.contains('news · newspapers · books')) continue;
    if (t.contains('better source needed') || t.contains('citation needed') ||
        t.contains('[来源请求]')) continue;
    if (t.startsWith('This article relies')) continue;
    if (t.contains('Learn how and when to remove this message')) continue;
    if (t.startsWith('资料来源') || t.startsWith('** 资料来源')) continue;
    if (t.contains('最新推荐文章于') || t.contains('版权声明') ||
        t.contains('本内容遵循CC')) continue;
    if (t.contains('[GEO检测]') || t.contains('收录于') ||
        t.contains('该文章已生成')) continue;
    if (t.contains('请附上原文') || t.contains('转载请附上') ||
        t.contains('本文为博主')) continue;
    if (RegExp(r'\d+\.\d+w 阅读').hasMatch(t) ||
        (t.contains('CC ') && t.contains('BY-SA'))) continue;
    if (t.contains('csdnimg.cn') && t.contains('newHeart')) continue;
    if (t.startsWith('关注者') && RegExp(r'关注者\d+').hasMatch(t)) continue;
    if (t.startsWith('被浏览') && RegExp(r'被浏览\d+').hasMatch(t)) continue;
    if (RegExp(r'^\[\[\d+\]\]$').hasMatch(t)) continue;
    if (t.startsWith('.mw-parser-output') ||
        RegExp(r'^\..*\{.*\}').hasMatch(t)) continue;
    if (RegExp(r'^<[^>]+>$').hasMatch(t)) continue;
    if (RegExp(r'^\|[\s|]*\|$').hasMatch(t)) continue;
    if (t == '•' || t == '·') continue;
    if (t == '入題' || t == '入题' || t == '博覽' || t == '博览' ||
        t == '兼查' || t == '據' || t == '据') continue;
    if (t == '|') continue;
    if (RegExp(r'^\d+\.$').hasMatch(t)) continue;
    filtered.add(rawLine);
  }

  // 第2层：行内清洗
  final mapped = filtered.map((line) {
    var l = line;
    l = l.replaceAllMapped(RegExp(r'(https?)[：:]'), (m) => '${m.group(1)}:');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]*?)\]（([^）]*?)）'),
        (m) => '[${m.group(1)}](${m.group(2)})');
    l = l.replaceAll(RegExp(r'\[([^\]]*?)\]（'), '[');
    l = l.replaceAll('）', ')');
    l = l.replaceAllMapped(
        RegExp(r'\?(\w+)\s+=\s+'), (m) => '?${m.group(1)}=');
    l = l.replaceAllMapped(
        RegExp(r'&(\w+)\s+=\s+'), (m) => '&${m.group(1)}=');
    l = l.replaceAll(RegExp(r'\[\[\d+\]\]\([^)]*\)'), '');
    l = l.replaceAll(RegExp(r'\[↑\]\([^)]*\)'), '');
    l = l.replaceAll(RegExp(r'\[edit\]|\[编辑\]'), '');
    l = l.replaceAll(
        RegExp(r'\[better source needed\]|\[citation needed\]|\[来源请求\]'),
        '');
    l = l.replaceAll(RegExp(r'\[tined\]\([^)]*\)'), '');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]*?)\]\(/[^\)]*?\)'), (m) => m.group(1) ?? '');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]*?)\]\(//[^\)]*?\)'), (m) => m.group(1) ?? '');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]*?)\]\(#[^\)]*?\)'), (m) => m.group(1) ?? '');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]*?)\]\([^)]*action=edit[^)]*\)'),
        (m) => m.group(1) ?? '');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]*?)\]\([^)]*veaction=edit[^)]*\)'),
        (m) => m.group(1) ?? '');
    l = l.replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), '');
    l = l.replaceAll(RegExp(r'<small[^>]*>.*?</small>'), '');
    l = l.replaceAllMapped(
        RegExp(r'<span[^>]*>(.*?)</span>'), (m) => m.group(1) ?? '');
    l = l.replaceAllMapped(
        RegExp(r'<a[^>]*>(.*?)</a>'), (m) => m.group(1) ?? '');
    l = l.replaceAll(RegExp(r'<img[^>]*>'), '');
    l = l.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    l = l.replaceAll(RegExp(r'<ref[^>]*>.*?</ref>'), '');
    l = l.replaceAll(RegExp(r'^[•·]\s*'), '');
    l = l.replaceAll(RegExp(r'自取"[^"]*'), '');
    l = l.replaceAll(RegExp(r'\[一个例子\]\([^)]*\)'), '');
    l = l.replaceAll(RegExp(r'^\d+\.\s*$'), '');
    l = l.trim();
    l = l.replaceAll(RegExp(r'^\[\s*$'), '');
    l = l.replaceAll(RegExp(r'^\]\s*$'), '');
    return l;
  }).toList();

  // 第3层：压缩连续空行
  final result = <String>[];
  for (final line in mapped) {
    if (line.trim().isEmpty && result.isNotEmpty &&
        result.last.trim().isEmpty) {
      continue;
    }
    result.add(line);
  }
  while (result.isNotEmpty && result.first.trim().isEmpty) {
    result.removeAt(0);
  }
  while (result.isNotEmpty && result.last.trim().isEmpty) {
    result.removeLast();
  }

  // 第4层：修复格式问题
  final finalResult = <String>[];
  for (var i = 0; i < result.length; i++) {
    final line = result[i];
    final prev = finalResult.isNotEmpty ? finalResult.last : null;
    if (line.startsWith('|') && prev != null &&
        prev.isNotEmpty && !prev.startsWith('|')) {
      finalResult.add('');
    }
    if (line.startsWith('```') && prev != null &&
        prev.isNotEmpty && !prev.startsWith('```')) {
      finalResult.add('');
    }
    if (line.startsWith('>') && prev != null &&
        prev.isNotEmpty && !prev.startsWith('>')) {
      finalResult.add('');
    }
    finalResult.add(line);
  }
  return finalResult.join('\n');
}
