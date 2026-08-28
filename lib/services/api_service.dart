import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/models.dart';

/// AnySearch API 客户端
/// 从 Kotlin AnySearchApi.kt 翻译
/// JSON-RPC 2.0 协议
class ApiService {
  final Dio _dio;
  final String _endpoint = 'https://api.anysearch.com/mcp';
  final String _apiKey = '';
  int _rpcId = 1;

  ApiService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<List<SearchResult>> search(String query,
      {int maxResults = 10, String? domain, String? subDomain}) async {
    final args = <String, dynamic>{'query': query, 'max_results': maxResults};
    if (domain != null) args['domain'] = domain;
    if (subDomain != null) args['sub_domain'] = subDomain;
    final content = await _callMcp('search', args);
    return _parseSearchResults(content);
  }

  Future<Map<String, List<SearchResult>>> batchSearch(
      List<String> queries, {int maxResults = 10}) async {
    final queriesArr = queries.map((q) =>
      {'query': q, 'max_results': maxResults}).toList();
    final content = await _callMcp('batch_search', {'queries': queriesArr});
    return _parseBatchResults(content, queries);
  }

  Future<List<VerticalDomain>> getSubDomains(List<String> domains) async {
    final content = await _callMcp('get_sub_domains', {'domains': domains});
    return _parseSubDomains(content);
  }

  Future<ExtractedContent> extract(String url) async {
    final content = await _callMcp('extract', {'url': url});
    return _parseExtractResult(content, url);
  }

  Future<UpdateInfo?> checkUpdate({int currentVersionCode = 0}) async {
    try {
      final resp = await _dio.get(
        'https://files.baichabuyu.asia/public/anysearch/update.json');
      final json = resp.data as Map<String, dynamic>;
      final history = (json['history'] as List? ?? [])
        .map((e) => HistoryItem(
          versionName: e['versionName'] ?? '',
          date: e['date'] ?? '',
          updateLog: e['updateLog'] ?? '',
        )).toList();
      return UpdateInfo(
        versionCode: json['versionCode'] ?? json['latestVersionCode'] ?? 0,
        versionName: json['versionName'] ?? json['latestVersionName'] ?? '',
        downloadUrl: json['downloadUrl'] ?? '',
        updateLog: json['updateLog'] ?? '',
        history: history,
        currentVersionCode: currentVersionCode,
      );
    } catch (_) { return null; }
  }

  Future<String?> getAnnouncement() async {
    try {
      final resp = await _dio.get(
        'https://files.baichabuyu.asia/public/anysearch/announcement.json');
      return resp.data['content'];
    } catch (_) { return null; }
  }

  Future<String> translate(String text,
      {String source = 'en', String target = 'zh'}) async {
    final chunks = _chunkText(text, 5000);
    final results = await Future.wait(
      chunks.map((c) => _translateChunk(c, source, target)));
    return results.join('\n');
  }

  List<String> _chunkText(String text, int maxChars) {
    final paragraphs = text.split('\n');
    final chunks = <String>[];
    final current = StringBuffer();
    for (final para in paragraphs) {
      if (current.length + para.length + 1 > maxChars && current.isNotEmpty) {
        chunks.add(current.toString());
        current.clear();
      }
      if (para.length > maxChars) {
        for (int i = 0; i < para.length; i += maxChars) {
          chunks.add(para.substring(i, (i + maxChars).clamp(0, para.length)));
        }
      } else {
        if (current.isNotEmpty) current.write('\n');
        current.write(para);
      }
    }
    if (current.isNotEmpty) chunks.add(current.toString());
    return chunks;
  }

  Future<String> _translateChunk(String text, String src, String tgt) async {
    try {
      final resp = await _dio.post('https://transmart.qq.com/api/imt',
        data: {
          'header': {'fn': 'auto_translation', 'session': '',
            'client_key': 'browser-chrome-130.0.0-Android-14-${DateTime.now().millisecondsSinceEpoch}',
            'user': ''},
          'type': 'plain', 'model_category': 'normal', 'text_domain': '',
          'source': {'lang': src, 'text_list': [text]},
          'target': {'lang': tgt},
        });
      final translations = resp.data['auto_translation'] as List?;
      if (translations != null && translations.isNotEmpty) {
        return translations.join('');
      }
    } catch (_) {}
    return text;
  }

  Future<String> _callMcp(String toolName, Map<String, dynamic> args) async {
    final body = jsonEncode({
      'jsonrpc': '2.0', 'id': _rpcId++,
      'method': 'tools/call',
      'params': {'name': toolName, 'arguments': args},
    });
    final options = Options(headers: {
      'Content-Type': 'application/json',
      'X-Anysearch-Client': 'anysearch-flutter/2.0.0',
      if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
    });
    final resp = await _dio.post(_endpoint, data: body, options: options);
    return _extractMcpContent(resp.data);
  }

  String _extractMcpContent(dynamic raw) {
    try {
      final Map<String, dynamic> response =
        raw is String ? jsonDecode(raw) : raw;
      final result = response['result'] as Map<String, dynamic>?;
      final contentArr = result?['content'] as List?;
      if (contentArr != null && contentArr.isNotEmpty) {
        return contentArr.map((e) =>
          (e as Map<String, dynamic>)['text'] ?? '').join();
      }
      return raw.toString();
    } catch (_) { return raw.toString(); }
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) { return ''; }
  }

  List<SearchResult> _parseSearchResults(String content) {
    final results = <SearchResult>[];
    final regex = RegExp(r'### \d+\.\s+(.+?)(?:\n|$)((?:.|\n)*?)(?=\n###|\Z)',
      dotAll: true);
    for (final match in regex.allMatches(content)) {
      final title = match.group(1)!.trim();
      final body = match.group(2)!.trim();
      final urlMatch = RegExp(r'\*\*URL\*\*:\s*(\S+)').firstMatch(body) ??
        RegExp(r'(https?://\S+)').firstMatch(body);
      final url = urlMatch?.group(1)?.trim() ?? '';
      final dateMatch = RegExp(r'date:\s*(.+)').firstMatch(body);
      final date = dateMatch?.group(1)?.trim() ?? '';
      final snippet = body.split('\n')
        .where((l) => !l.contains('**URL**') && !l.startsWith('- **URL'))
        .join(' ').trim();
      if (title.isNotEmpty) {
        results.add(SearchResult(title: title, url: url,
          snippet: snippet, source: _extractDomain(url), date: date));
      }
    }
    return results;
  }

  Map<String, List<SearchResult>> _parseBatchResults(
      String content, List<String> queries) {
    final result = <String, List<SearchResult>>{};
    final sections = RegExp(r'\n## Query \d+')
      .allMatches(content).toList();
    if (sections.length >= queries.length) {
      final parts = content.split(RegExp(r'\n## Query \d+'))
        .where((s) => s.trim().isNotEmpty).toList();
      for (int i = 0; i < queries.length && i < parts.length; i++) {
        result[queries[i]] = _parseSearchResults(parts[i]);
      }
    } else {
      final all = _parseSearchResults(content);
      for (int i = 0; i < queries.length; i++) {
        result[queries[i]] = i == 0 ? all : [];
      }
    }
    return result;
  }

  List<VerticalDomain> _parseSubDomains(String content) {
    final domains = <VerticalDomain>[];
    final regex = RegExp(r'(\w+) Domain');
    final seen = <String>{};
    for (final match in regex.allMatches(content)) {
      final key = match.group(1)!.toLowerCase();
      if (seen.add(key)) {
        domains.add(VerticalDomain(key: key,
          name: VerticalDomain.chineseName(key), icon: ''));
      }
    }
    if (domains.isEmpty) {
      for (final k in ['security','academic','code','finance','legal','health',
        'business','social_media','travel','film','gaming','energy',
        'environment','agriculture','ip','resource']) {
        domains.add(VerticalDomain(key: k, name: VerticalDomain.chineseName(k)));
      }
    }
    return domains;
  }

  ExtractedContent _parseExtractResult(String content, String sourceUrl) {
    final titleMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
    final title = titleMatch?.group(1)?.trim() ?? sourceUrl;
    return ExtractedContent(title: title, source: sourceUrl,
      markdown: content, success: content.isNotBlank);
  }

  // ==================== AI 智能排版（商汤 SenseNova） ====================
  static const String _aiEndpoint =
      'https://token.sensenova.cn/v1/chat/completions';
  static const String _aiApiKey = 'sk-GmK471pZW5taBLL4O3XsK8w1Xtx3dINr';
  static const String _aiModel = 'sensenova-6.8-flash-lite';
  static const int _aiMaxTokens = 8192;

  /// 把 MCP 提取的原始内容交给 AI，排版成 RichContent JSON
  Future<String> aiFormatContent(
      String title, String rawMarkdown) async {
    final input = rawMarkdown.length > 15000
        ? rawMarkdown.substring(0, 15000)
        : rawMarkdown;

    const systemPrompt = '''
你是一个内容排版工具，不是作者。你的唯一任务是把用户提供的原文**原样排版**成结构化 JSON。
禁止改写、润色、扩写、总结原文内容，禁止新增任何原文没有的内容。

## 铁律（必须严格遵守）
1. **只排版，不创作**：正文文字必须忠实于原文，一个词都不要改、不要润色、不要扩写
2. **完整保留所有超链接**：原文中每个链接 [文字](url) 都必须用 link 组件原样保留，链接文字和 url 都不能丢、不能改、不能漏
3. 只剔除明显的噪音：URL 残渣、引用标注[1]、markdown 语法残留、乱码
4. 输出必须是严格合法的 JSON，不要任何解释、不要 ```json 代码块标记、不要多余文字
## 输出格式（只输出这个 JSON）
{"type":"rich","title":"文章标题","blocks":[
  {"type":"heading","level":1,"content":"标题"},
  {"type":"text","content":"段落"},
  {"type":"bold","content":"加粗"},
  {"type":"link","text":"链接文字","url":"https://真实url"},
  {"type":"list","items":["项1","项2"]},
  {"type":"quote","content":"引用"},
  {"type":"divider"},
  {"type":"image","url":"https://图片","content":"描述"}
]}
## 可用组件类型（只能这些）
heading(level 1-6) / text / bold / italic / link(text+url) / list(items数组) / quote / code(content+language) / divider / image(url+content)
## 排版原则
1. 用 heading 划分章节、text 放段落、list 放列表、link 放链接、quote 放引用
2. 中文排版（原文英文则保持原文语言，不翻译）
3. 内容多长就多长，忠实呈现，不要截断、不要精简
''';

    var assistantContent =
        await _callAiForFormat(systemPrompt, title, input);
    // 校验格式，不合法则重试一次
    final validation = _validateRichJson(assistantContent);
    if (!validation.$1) {
      assistantContent = await _callAiForFormat(
        systemPrompt, title, input, retryFeedback: validation.$2);
    }
    return _extractRichJson(assistantContent, title);
  }

  Future<String> _callAiForFormat(
      String systemPrompt, String title, String input,
      {String? retryFeedback}) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': '标题：$title\n\n原始内容：\n$input'},
    ];
    if (retryFeedback != null) {
      messages.add(
          {'role': 'assistant', 'content': '（上次输出不符合要求）'});
      messages.add({
        'role': 'user',
        'content': '你上次的输出不合法，工具校验失败：$retryFeedback。'
            '请重新严格按要求输出合法 JSON，只排版、保留全部链接、不要润色。'
      });
    }
    try {
      final resp = await _dio.post(_aiEndpoint,
        data: {
          'model': _aiModel,
          'messages': messages,
          'temperature': 0.3,
          'max_tokens': _aiMaxTokens,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_aiApiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 90),
        ));
      final content = resp.data['choices']?[0]?['message']?['content'];
      return content ?? _buildFallbackRichJson(title, 'AI 排版无返回内容');
    } catch (e) {
      return _buildFallbackRichJson(title, 'AI 排版网络异常');
    }
  }

  /// 校验 RichContent JSON 是否符合 schema
  (bool, String) _validateRichJson(String content) {
    final text = content.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return (false, '输出不是有效的 JSON 对象（缺少花括号）');
    }
    try {
      final root = jsonDecode(text.substring(start, end + 1));
      final blocks = root['blocks'];
      if (blocks == null || blocks is! List || blocks.isEmpty) {
        return (false, '缺少 blocks 数组字段');
      }
      const validTypes = {
        'heading', 'text', 'bold', 'italic', 'link', 'list',
        'quote', 'code', 'divider', 'image',
      };
      for (final b in blocks) {
        final type = b['type'];
        if (type == null || !validTypes.contains(type)) {
          return (false, '不支持的组件类型: $type');
        }
      }
      return (true, '');
    } catch (e) {
      return (false, 'JSON 解析失败');
    }
  }

  /// 从 AI 返回内容中提取 RichContent JSON
  String _extractRichJson(String content, String title) {
    var text = content.trim();
    text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
    text = text.replaceAll(RegExp(r'\s*```$'), '');
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return _buildFallbackRichJson(title, 'AI 返回格式无法解析');
  }

  /// 构建失败/兜底的 RichContent JSON
  String _buildFallbackRichJson(String title, String error) {
    return jsonEncode({
      'type': 'rich',
      'title': title,
      'blocks': [
        {'type': 'heading', 'level': 1, 'content': 'AI 排版未完成'},
        {'type': 'text', 'content': error},
        {'type': 'text', 'content': '请稍后重试，或切换其他渲染模式。'},
      ],
    });
  }
}

extension on String {
  bool get isNotBlank => trim().isNotEmpty;
}