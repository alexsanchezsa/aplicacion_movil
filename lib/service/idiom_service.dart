import 'dart:convert';
import 'package:flutter/services.dart';

class LangService {
  static Map<String, dynamic> _texts = {};
  static Map<String, dynamic> _categories = {};

  static Future<void> load(String langCode) async {
    try {
      String path = 'assets/languages/${langCode}_traduction.json';
      print('Intentando cargar: $path');
      final jsonString = await rootBundle.loadString(path);
      final newTexts = json.decode(jsonString) as Map<String, dynamic>;

      _texts = newTexts; // Replace instead of merge to avoid mixing languages
      print('Textos cargados correctamente. Total: ${_texts.length} claves');
    } catch (e) {
      print('Error al cargar idioma: $e');
      // If load fails, try to keep previous or load default?
      // specific logic not requested, but keeping _texts as is might be safer if it fails,
      // though typically we want to update the UI.
    }
  }

  // Cargar categorías
  static Future<void> loadCategories(String langCode) async {
    try {
      String path = 'assets/languages/${langCode}_traduction.json';
      print('Intentando cargar categorías: $path');
      final jsonString = await rootBundle.loadString(path);
      _categories = json.decode(jsonString) as Map<String, dynamic>;
      print('Categorías cargadas: ${_categories.length} claves');
    } catch (e) {
      print('Error al cargar categorías: $e');
    }
  }

  static String text(String key) {
    final value = _texts[key];
    if (value == null) {
      print('⚠️ Clave no encontrada: $key');
      return key; // Return key instead of '--' for better fallback
    }
    return value.toString();
  }

  static String category(String key) {
    final value = _categories[key];
    if (value == null) {
      print('⚠️ Categoría no encontrada: $key');
      return key;
    }
    return value.toString();
  }

  static List<String> supportedLanguages() {
    // Return hardcoded list of supported languages codes
    return ['es', 'en', 'ca', 'gl', 'pt', 'fr', 'eu'];
  }
}
