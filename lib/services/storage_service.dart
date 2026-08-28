// AnySearch 本地存储服务
// 从 Kotlin 的 DataStore (SearchHistoryStore/SettingsStore/PrivacyPreferences) 翻译
// 用 shared_preferences 实现持久化

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 搜索历史记录（含完整搜索结果）
class StoredHistoryItem {
  final String id;
  final String query;
  final List<SearchResult> results;
  final String? vertical;
  final int timestamp;

  const StoredHistoryItem({
    required this.id,
    required this.query,
    required this.results,
    this.vertical,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'query': query,
    'results': results
        .map((r) => {
              'title': r.title,
              'url': r.url,
              'snippet': r.snippet,
              'source': r.source,
              'date': r.date,
            })
        .toList(),
    'vertical': vertical,
    'timestamp': timestamp,
  };

  factory StoredHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawResults = (json['results'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return StoredHistoryItem(
      id: json['id'] as String,
      query: json['query'] as String,
      results: rawResults
          .map((r) => SearchResult(
                title: r['title'] ?? '',
                url: r['url'] ?? '',
                snippet: r['snippet'] ?? '',
                source: r['source'] ?? '',
                date: r['date'] ?? '',
              ))
          .toList(),
      vertical: json['vertical'] as String?,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

class StorageService {
  static const String _historyKeysKey = 'history_keys';
  static const String _historyPrefix = 'history_';
  static const int _maxEntries = 100;

  // 设置
  static const String _renderLinksKey = 'render_links';

  // 隐私协议
  static const String _privacyAgreedKey = 'has_agreed_to_privacy';

  // ==================== 搜索历史 ====================

  /// 读取所有历史记录（按时间倒序）
  Future<List<StoredHistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString(_historyKeysKey) ?? '[]';
    List<String> keys = [];
    try {
      keys = (jsonDecode(keysJson) as List).cast<String>();
    } catch (_) {}
    final items = <StoredHistoryItem>[];
    for (final key in keys) {
      final entryJson = prefs.getString('$_historyPrefix$key');
      if (entryJson == null) continue;
      try {
        items.add(StoredHistoryItem.fromJson(
            Map<String, dynamic>.from(jsonDecode(entryJson) as Map)));
      } catch (_) {}
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  /// 添加一条搜索记录
  Future<void> addHistory({
    required String query,
    required List<SearchResult> results,
    String? vertical,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString(_historyKeysKey) ?? '[]';
    List<String> keys = [];
    try {
      keys = (jsonDecode(keysJson) as List).cast<String>();
    } catch (_) {}

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = StoredHistoryItem(
      id: id,
      query: query,
      results: results,
      vertical: vertical,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
        '$_historyPrefix$id', jsonEncode(entry.toJson()));

    // 加到头部
    keys.insert(0, id);

    // 限制 100 条
    while (keys.length > _maxEntries) {
      final oldKey = keys.removeLast();
      await prefs.remove('$_historyPrefix$oldKey');
    }
    await prefs.setString(_historyKeysKey, jsonEncode(keys));
  }

  /// 删除单条记录
  Future<void> deleteHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString(_historyKeysKey) ?? '[]';
    List<String> keys = [];
    try {
      keys = (jsonDecode(keysJson) as List).cast<String>();
    } catch (_) {}
    keys.remove(id);
    await prefs.remove('$_historyPrefix$id');
    await prefs.setString(_historyKeysKey, jsonEncode(keys));
  }

  /// 清空所有记录
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString(_historyKeysKey) ?? '[]';
    List<String> keys = [];
    try {
      keys = (jsonDecode(keysJson) as List).cast<String>();
    } catch (_) {}
    for (final key in keys) {
      await prefs.remove('$_historyPrefix$key');
    }
    await prefs.remove(_historyKeysKey);
  }

  // ==================== 设置 ====================

  /// 阅读页渲染是否带链接（默认 true）
  Future<bool> loadRenderLinks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_renderLinksKey) ?? true;
  }

  Future<void> setRenderLinks(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_renderLinksKey, value);
  }

  // ==================== 隐私协议 ====================

  /// 是否已同意隐私协议
  Future<bool> hasAgreedPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyAgreedKey) ?? false;
  }

  Future<void> setPrivacyAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAgreedKey, true);
  }
}
