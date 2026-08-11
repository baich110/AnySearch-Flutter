import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SearchViewModel extends ChangeNotifier {
  final ApiService _api;
  UiState _state = UiStateIdle();
  UiState get state => _state;

  String _searchText = '';
  String get searchText => _searchText;

  List<String> _history = [];
  List<String> get history => _history;

  List<VerticalDomain> _verticals = [];
  List<VerticalDomain> get verticals => _verticals;

  String? _selectedVertical;
  String? get selectedVertical => _selectedVertical;

  String? _focusedResultUrl;
  String? get focusedResultUrl => _focusedResultUrl;

  UiStateResults? _lastResults;

  UpdateInfo? _updateInfo;
  UpdateInfo? get updateInfo => _updateInfo;

  bool _checkingUpdate = false;
  bool get checkingUpdate => _checkingUpdate;

  String? _announcement;
  String? get announcement => _announcement;

  bool _announcementLoading = false;
  bool get announcementLoading => _announcementLoading;

  SearchViewModel(this._api);

  void updateSearchText(String text) { _searchText = text; notifyListeners(); }
  void clearSearchText() { _searchText = ''; notifyListeners(); }
  void selectVertical(String? key) { _selectedVertical = key; notifyListeners(); }
  void clearFocusedResultUrl() { _focusedResultUrl = null; notifyListeners(); }

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
      _lastResults = UiStateResults(results);
      _state = _lastResults!;
    } catch (e) {
      _state = UiStateError(e.toString());
    }
    notifyListeners();
  }

  void loadVerticals() async {
    try {
      _verticals = await _api.getSubDomains(
        ['security','academic','code','finance','legal','health','business',
         'social_media','travel','film','gaming','energy','environment',
         'agriculture','ip','resource']);
    } catch (_) {
      _verticals = ['security','academic','code','finance','legal','health',
        'business','social_media','travel','film','gaming','energy',
        'environment','agriculture','ip','resource']
        .map((k) => VerticalDomain(key: k, name: VerticalDomain.chineseName(k)))
        .toList();
    }
    notifyListeners();
  }

  void extractContent(String url) async {
    if (_state is UiStateResults) _lastResults = _state as UiStateResults;
    _focusedResultUrl = url;
    _state = UiStateExtracting(url);
    notifyListeners();
    try {
      final content = await _api.extract(url);
      _state = UiStateReading(content, url);
      if (_isMostlyEnglish(content.markdown)) translateContent();
    } catch (e) {
      _state = UiStateError(e.toString());
    }
    notifyListeners();
  }

  void translateContent() async {
    final current = _state as UiStateReading;
    if (current.isTranslating) return;
    _state = UiStateReading(current.content, current.fromUrl, isTranslating: true);
    notifyListeners();
    try {
      final translated = await _api.translate(current.content.markdown);
      _state = UiStateReading(
        ExtractedContent(title: current.content.title, source: current.content.source,
          markdown: translated, success: true),
        current.fromUrl, isTranslating: false);
    } catch (_) {
      _state = current;
    }
    notifyListeners();
  }

  bool _isMostlyEnglish(String text) {
    final en = text.split('').where((c) =>
      (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) ||
      (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122)).length;
    final zh = text.split('').where((c) =>
      c.codeUnitAt(0) >= 0x4e00 && c.codeUnitAt(0) <= 0x9fff).length;
    return en > zh * 3 && en > 50;
  }

  void backToResults() { _state = _lastResults ?? UiStateIdle(); notifyListeners(); }
  void reset() { _state = UiStateIdle(); notifyListeners(); }
  void showAbout() { _state = UiStateAbout(); notifyListeners(); }
  void backToHome() { _state = UiStateIdle(); notifyListeners(); }

  void checkUpdate() async {
    if (_checkingUpdate) return;
    _checkingUpdate = true; notifyListeners();
    try {
      _updateInfo = await _api.checkUpdate();
    } catch (_) {}
    _checkingUpdate = false; notifyListeners();
  }

  void loadAnnouncement() async {
    if (_announcementLoading) return;
    _announcementLoading = true; notifyListeners();
    try { _announcement = await _api.getAnnouncement(); }
    catch (_) {}
    _announcementLoading = false; notifyListeners();
  }

  void clearUpdateInfo() { _updateInfo = null; notifyListeners(); }
  void clearAnnouncement() { _announcement = null; notifyListeners(); }
}