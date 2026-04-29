import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import '../services/api_service.dart';

class SearchProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<VideoModel> _results = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _lastQuery = '';

  List<VideoModel> get results => _results;
  List<String> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get lastQuery => _lastQuery;

  SearchProvider() {
    _loadLastQuery();
  }

  Future<void> _loadLastQuery() async {
    final prefs = await SharedPreferences.getInstance();
    _lastQuery = prefs.getString('lastQuery') ?? '';
    if (_lastQuery.isNotEmpty) {
      search(_lastQuery);
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    _lastQuery = query;
    _suggestions = []; // Clear suggestions when searching
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastQuery', query);

      _results = await _apiService.searchVideos(query);
    } catch (e) {
      _errorMessage = 'Gagal melakukan pencarian. Periksa koneksi internet Anda.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    try {
      final suggestions = await _apiService.getSearchSuggestions(query);
      _suggestions = suggestions.toList();
      notifyListeners();
    } catch (e) {
      _suggestions = [];
      // Don't show error for suggestions, just fail silently
      notifyListeners();
    }
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }
}
