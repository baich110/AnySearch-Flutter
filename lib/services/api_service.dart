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

  Future<UpdateInfo?> checkUpdate() async {
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
        versionCode: json['latestVersionCode'] ?? 0,
        versionName: json['latestVersionName'] ?? '',
        downloadUrl: json['downloadUrl'] ?? '',
        updateLog: json['updateLog'] ?? '',
        history: history,
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
        .where((s) => s.isNotBlank()).toList();
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
}

extension on String {
  bool get isNotBlank => trim().isNotEmpty;
}