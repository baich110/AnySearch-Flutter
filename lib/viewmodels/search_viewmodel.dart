import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SearchViewModel extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  UiState _state = UiStateIdle();
  UiState get state => _state;

  String _searchText = '';
  String get searchText => _searchText;

  List<String> _history = [];
  List<String> get history => _history;

  // 完整历史记录（含搜索结果）
  List<StoredHistoryItem> _fullHistory = [];
  List<StoredHistoryItem> get fullHistory => _fullHistory;

  List<VerticalDomain> _verticals = [];
  List<VerticalDomain> get verticals => _verticals;

  String? _selectedVertical;
  String? get selectedVertical => _selectedVertical;

  String? _focusedResultUrl;
  String? get focusedResultUrl => _focusedResultUrl;

  UiStateResults? _lastResults;
  bool _fromHistory = false;

  UpdateInfo? _updateInfo;
  UpdateInfo? get updateInfo => _updateInfo;

  bool _checkingUpdate = false;
  bool get checkingUpdate => _checkingUpdate;

  String? _announcement;
  String? get announcement => _announcement;

  bool _announcementLoading = false;
  bool get announcementLoading => _announcementLoading;

  // 隐私协议
  bool _privacyAgreed = false;
  bool get privacyAgreed => _privacyAgreed;

  // 渲染设置：是否带链接
  bool _renderLinks = true;
  bool get renderLinks => _renderLinks;

  // 阅读页临时渲染模式：null=跟随全局，true/false=临时覆盖
  bool? _tempRenderLinks;
  bool? get tempRenderLinks => _tempRenderLinks;

  bool _initialized = false;
  bool get initialized => _initialized;

  SearchViewModel(this._api) : _storage = StorageService();

  /// 启动初始化：读取隐私协议、历史、设置、加载垂直领域
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _privacyAgreed = await _storage.hasAgreedPrivacy();
    _renderLinks = await _storage.loadRenderLinks();
    _fullHistory = await _storage.loadHistory();
    _history = _fullHistory.map((e) => e.query).toSet().toList().take(20).toList();
    notifyListeners();
    loadVerticals();
  }

  // ==================== 输入 ====================

  void updateSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  void clearSearchText() {
    _searchText = '';
    notifyListeners();
  }

  void selectVertical(String? key) {
    _selectedVertical = key;
    notifyListeners();
  }

  void clearFocusedResultUrl() {
    _focusedResultUrl = null;
    notifyListeners();
  }

  // ==================== 隐私协议 ====================

  void agreeToPrivacy() async {
    _privacyAgreed = true;
    await _storage.setPrivacyAgreed();
    notifyListeners();
  }

  // ==================== 设置 ====================

  void setRenderLinksPreference(bool value) async {
    _renderLinks = value;
    await _storage.setRenderLinks(value);
    notifyListeners();
  }

  /// 阅读页临时切换渲染模式
  void setTempRenderLinks(bool? mode) {
    _tempRenderLinks = mode;
    notifyListeners();
  }

  /// 当前阅读页实际使用的渲染模式
  bool effectiveRenderLinks() => _tempRenderLinks ?? _renderLinks;

  // ==================== 搜索 ====================

  void search() async {
    final text = _searchText.trim();
    if (text.isEmpty) return;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final vertical = _selectedVertical;
    _state = UiStateLoading();
    notifyListeners();
    try {
      Map<String, List<SearchResult>> results;
      if (lines.length == 1) {
        final list = vertical != null
            ? await _api.search(lines[0], domain: vertical)
            : await _api.search(lines[0]);
        results = {lines[0]: list};
      } else {
        results = await _api.batchSearch(lines);
      }

      _history = [text, ..._history].toSet().toList().take(20).toList();

      // 保存完整历史
      final allResults = results.values.expand((l) => l).toList();
      await _storage.addHistory(query: text, results: allResults, vertical: vertical);
      _fullHistory = await _storage.loadHistory();

      _lastResults = UiStateResults(results);
      _fromHistory = false;
      _state = _lastResults!;
    } catch (e) {
      _state = UiStateError(e.toString());
    }
    notifyListeners();
  }

  // ==================== 历史记录 ====================

  void showHistory() {
    _state = UiStateHistory();
    notifyListeners();
  }

  void loadFromHistory(StoredHistoryItem item) {
    _fromHistory = true;
    final grouped = <String, List<SearchResult>>{item.query: item.results};
    final rs = UiStateResults(grouped);
    _lastResults = rs;
    _state = rs;
    notifyListeners();
  }

  void backFromHistoryResults() {
    if (_fromHistory) {
      _fromHistory = false;
      _state = UiStateHistory();
    } else {
      reset();
    }
    notifyListeners();
  }

  void reSearchFromHistory(String query) {
    _searchText = query;
    search();
  }

  void deleteHistoryItem(String id) async {
    await _storage.deleteHistory(id);
    _fullHistory = await _storage.loadHistory();
    notifyListeners();
  }

  void clearAllHistory() async {
    await _storage.clearHistory();
    _fullHistory = [];
    _history = [];
    notifyListeners();
  }

  // ==================== 垂直领域 ====================

  void loadVerticals() async {
    try {
      _verticals = await _api.getSubDomains([
        'security', 'academic', 'code', 'finance', 'legal', 'health',
        'business', 'social_media', 'travel', 'film', 'gaming',
        'energy', 'environment', 'agriculture', 'ip', 'resource',
      ]);
    } catch (_) {
      if (_verticals.isEmpty) {
        _verticals = [
          'security', 'academic', 'code', 'finance', 'legal', 'health',
          'business', 'social_media', 'travel', 'film', 'gaming',
          'energy', 'environment', 'agriculture', 'ip', 'resource',
        ]
            .map((k) => VerticalDomain(key: k, name: VerticalDomain.chineseName(k)))
            .toList();
      }
    }
    notifyListeners();
  }

  // ==================== 提取正文 ====================

  void extractContent(String url) {
    if (_state is UiStateResults) _lastResults = _state as UiStateResults;
    _focusedResultUrl = url;
    _state = UiStateExtracting(url);
    notifyListeners();
    _extractAndMaybeTranslate(url);
  }

  Future<void> _extractAndMaybeTranslate(String url) async {
    try {
      final content = await _api.extract(url);
      _state = UiStateReading(content, url);
      notifyListeners();
      if (_isMostlyEnglish(content.markdown)) {
        translateContent();
      }
    } catch (e) {
      _state = UiStateError(e.toString());
      notifyListeners();
    }
  }

  void extractAndTranslate(String url) async {
    if (_state is UiStateResults) _lastResults = _state as UiStateResults;
    _focusedResultUrl = url;
    _state = UiStateExtracting(url);
    notifyListeners();
    try {
      final content = await _api.extract(url);
      _state = UiStateReading(content, url, isTranslating: true);
      notifyListeners();
      final translated = await _api.translate(content.markdown);
      _state = UiStateReading(
        ExtractedContent(
            title: content.title, source: content.source,
            markdown: translated, success: true),
        url,
        isTranslating: false,
      );
      notifyListeners();
    } catch (e) {
      _state = UiStateError(e.toString());
      notifyListeners();
    }
  }

  // ==================== 翻译 ====================

  void translateContent() async {
    final current = _state is UiStateReading ? _state as UiStateReading : null;
    if (current == null || current.isTranslating) return;
    _state = UiStateReading(current.content, current.fromUrl, isTranslating: true);
    notifyListeners();
    try {
      final translated = await _api.translate(current.content.markdown);
      _state = UiStateReading(
        ExtractedContent(
            title: current.content.title, source: current.content.source,
            markdown: translated, success: true),
        current.fromUrl,
        isTranslating: false,
      );
    } catch (_) {
      _state = current;
    }
    notifyListeners();
  }

  // ==================== AI 智能排版 ====================

  void aiFormatContent() async {
    final current = _state is UiStateReading ? _state as UiStateReading : null;
    if (current == null || current.isTranslating) return;
    _state = UiStateReading(current.content, current.fromUrl, isTranslating: true);
    notifyListeners();
    try {
      final html = await _api.aiFormatContent(
        current.content.title.isEmpty ? current.fromUrl : current.content.title,
        current.content.markdown,
      );
      _state = UiStateReading(
        current.content, current.fromUrl,
        isTranslating: false, aiHtml: html);
    } catch (e) {
      _state = UiStateReading(
        current.content, current.fromUrl, isTranslating: false);
    }
    notifyListeners();
  }

  bool _isMostlyEnglish(String text) {
    var en = 0, zh = 0;
    for (final c in text.codeUnits) {
      if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) en++;
      if (c >= 0x4e00 && c <= 0x9fff) zh++;
    }
    return en > zh * 3 && en > 50;
  }

  // ==================== 内置浏览器 ====================

  void openInBrowser(String url) {
    if (_state is UiStateResults) _lastResults = _state as UiStateResults;
    _focusedResultUrl = url;
    _state = UiStateBrowsing(url);
    notifyListeners();
  }

  void backFromBrowser() {
    _state = _lastResults ?? UiStateIdle();
    notifyListeners();
  }

  // ==================== 状态导航 ====================

  void backToResults() {
    _state = _lastResults ?? UiStateIdle();
    notifyListeners();
  }

  void reset() {
    _state = UiStateIdle();
    _tempRenderLinks = null;
    notifyListeners();
  }

  void showAbout() {
    _state = UiStateAbout();
    notifyListeners();
  }

  void backToHome() {
    _state = UiStateIdle();
    notifyListeners();
  }

  // ==================== 更新 & 公告 ====================

  void checkUpdate() async {
    if (_checkingUpdate) return;
    _checkingUpdate = true;
    notifyListeners();
    try {
      _updateInfo = await _api.checkUpdate(currentVersionCode: 6);
    } catch (_) {}
    _checkingUpdate = false;
    notifyListeners();
  }

  void loadAnnouncement() async {
    if (_announcementLoading) return;
    _announcementLoading = true;
    notifyListeners();
    try {
      _announcement = await _api.getAnnouncement();
    } catch (_) {}
    _announcementLoading = false;
    notifyListeners();
  }

  void clearUpdateInfo() {
    _updateInfo = null;
    notifyListeners();
  }

  void clearAnnouncement() {
    _announcement = null;
    notifyListeners();
  }
}
