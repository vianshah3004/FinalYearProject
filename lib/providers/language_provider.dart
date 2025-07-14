import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ml_translation_service.dart';


class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = MLTranslationService.defaultLanguage;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadingLanguage = '';

  String get currentLanguage => _currentLanguage;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadingLanguage => _downloadingLanguage;

  LanguageProvider() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language_code');

    if (savedLanguage != null) {
      _currentLanguage = savedLanguage;

      // Initialize the translation service
      final translationService = MLTranslationService();
      await translationService.initialize();

      // Check if the language model is downloaded
      if (_currentLanguage != MLTranslationService.defaultLanguage) {
        final isDownloaded = await translationService.isLanguageDownloaded(_currentLanguage);

        if (!isDownloaded) {
          // Download the language model if not already downloaded
          _downloadLanguageModel(_currentLanguage);
        }
      }
    }

    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      final translationService = MLTranslationService();

      // Check if the language model is downloaded
      if (languageCode != MLTranslationService.defaultLanguage) {
        final isDownloaded = await translationService.isLanguageDownloaded(languageCode);

        if (!isDownloaded) {
          // Download the language model if not already downloaded
          await _downloadLanguageModel(languageCode);
        }
      }

      _currentLanguage = languageCode;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);

      notifyListeners();
    }
  }

  Future<void> _downloadLanguageModel(String languageCode) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadingLanguage = languageCode;
    notifyListeners();

    final translationService = MLTranslationService();

    try {
      final success = await translationService.downloadLanguageModel(
        languageCode,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      if (!success) {
        print('Failed to download language model for $languageCode');
      }
    } catch (e) {
      print('Error downloading language model: $e');
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> deleteLanguageModel(String languageCode) async {
    if (languageCode == MLTranslationService.defaultLanguage) return;

    final translationService = MLTranslationService();
    await translationService.deleteLanguageModel(languageCode);

    notifyListeners();
  }
}

