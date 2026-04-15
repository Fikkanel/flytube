import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import '../services/api_service.dart';

class SearchProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<VideoModel> _results = [];
  List<VideoModel> get results => _results;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _lastQuery = '';
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
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastQuery', query);

      _results = await _apiService.searchVideos(query);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
