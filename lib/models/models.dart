// AnySearch 数据模型
// 从 Kotlin Models.kt 翻译

/// 搜索结果项
class SearchResult {
  final String title;
  final String url;
  final String snippet;
  final String source;
  final String date;

  const SearchResult({
    required this.title,
    required this.url,
    this.snippet = '',
    this.source = '',
    this.date = '',
  });
}

/// 提取的网页内容
class ExtractedContent {
  final String title;
  final String source;
  final String markdown;
  final bool success;

  const ExtractedContent({
    required this.title,
    required this.source,
    required this.markdown,
    required this.success,
  });
}

/// 垂直领域
class VerticalDomain {
  final String key;
  final String name;
  final String icon;
  final List<SubDomain> subDomains;

  const VerticalDomain({
    required this.key,
    required this.name,
    this.icon = '',
    this.subDomains = const [],
  });

  static String chineseName(String key) {
    const names = {
      'security': '安全', 'academic': '学术', 'code': '代码',
      'finance': '金融', 'legal': '法律', 'health': '健康',
      'business': '商业', 'social_media': '社交媒体', 'travel': '旅行',
      'film': '电影', 'gaming': '游戏', 'energy': '能源',
      'environment': '环境', 'agriculture': '农业', 'ip': '知识产权',
      'resource': '资源',
    };
    return names[key] ?? key[0].toUpperCase() + key.substring(1);
  }
}

class SubDomain {
  final String key;
  final String description;
  final List<ParamInfo> params;
  const SubDomain({required this.key, required this.description, this.params = const []});
}

class ParamInfo {
  final String key;
  final String description;
  final bool required;
  const ParamInfo({required this.key, required this.description, this.required = false});
}

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String updateLog;
  final List<HistoryItem> history;
  const UpdateInfo({required this.versionCode, required this.versionName,
    required this.downloadUrl, required this.updateLog, this.history = const []});
}

class HistoryItem {
  final String versionName;
  final String date;
  final String updateLog;
  const HistoryItem({required this.versionName, required this.date, required this.updateLog});
}

/// UI 状态
sealed class UiState {}
class UiStateIdle extends UiState {}
class UiStateLoading extends UiState {}
class UiStateResults extends UiState {
  final Map<String, List<SearchResult>> grouped;
  UiStateResults(this.grouped);
}
class UiStateExtracting extends UiState {
  final String url;
  UiStateExtracting(this.url);
}
class UiStateReading extends UiState {
  final ExtractedContent content;
  final String fromUrl;
  final bool isTranslating;
  UiStateReading(this.content, this.fromUrl, {this.isTranslating = false});
}
class UiStateError extends UiState {
  final String message;
  UiStateError(this.message);
}
class UiStateAbout extends UiState {}