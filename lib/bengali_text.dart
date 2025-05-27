// lib/services/bengali_text_processor.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class BengaliTextProcessor {
  // Bengali Unicode range: 0980-09FF
  static const int _bengaliStart = 0x0980;
  static const int _bengaliEnd = 0x09FF;

  // Map for normalized characters
  Map<String, String> _normalizationMap = {};

  // NLClassifier for text categorization (if needed)
  NLClassifier? _textClassifier;

  bool _isInitialized = false;

  /// Initializes the text processor
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load normalization map from asset
      final String mapJson = await rootBundle.loadString('assets/data/bengali_normalization.json');
      _normalizationMap = Map<String, String>.from(jsonDecode(mapJson));

      // Initialize NLClassifier if needed
      await _initializeClassifier();

      _isInitialized = true;
      print('Bengali text processor initialized successfully');
    } catch (e) {
      print('Error initializing Bengali text processor: $e');
    }
  }

  /// Initializes the text classifier for categorization tasks
  Future<void> _initializeClassifier() async {
    try {
      // Get app directory for model extraction
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/bengali_text_classifier.tflite';

      // Extract model if needed
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        final byteData = await rootBundle.load('assets/models/bengali_text_classifier.tflite');
        await modelFile.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
        );
      }

      // Load the classifier
      _textClassifier = await NLClassifier.createFromFile(modelPath as File);
    } catch (e) {
      print('Text classifier initialization skipped: $e');
      // Continue without classifier
    }
  }

  /// Normalizes Bengali text (handle different Unicode compositions, etc.)
  String normalizeText(String text) {
    if (!_isInitialized) {
      // Initialize synchronously if needed
      _normalizationMap = {}; // Default empty map
    }

    if (_normalizationMap.isEmpty) {
      return text; // If not initialized, return as is
    }

    String normalized = text;

    // Apply normalization mappings
    _normalizationMap.forEach((original, replacement) {
      normalized = normalized.replaceAll(original, replacement);
    });

    return normalized;
  }

  /// Check if a string is primarily Bengali
  bool isPrimarilyBengali(String text) {
    if (text.isEmpty) {
      return false;
    }

    int bengaliChars = 0;

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= _bengaliStart && code <= _bengaliEnd) {
        bengaliChars++;
      }
    }

    // Consider it primarily Bengali if at least 60% of characters are Bengali
    return bengaliChars / text.length >= 0.6;
  }

  /// Extract words from Bengali text
  List<String> extractWords(String text) {
    // Normalize first
    final normalized = normalizeText(text);

    // Remove punctuation and split by whitespace
    final withoutPunctuation = normalized.replaceAll(RegExp(r'[।,.?!;:()[\]{}]'), ' ');
    final words = withoutPunctuation.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    return words;
  }

  /// Calculate the percentage of Bengali text
  double calculateBengaliPercentage(String text) {
    if (text.isEmpty) {
      return 0.0;
    }

    int bengaliChars = 0;
    int totalChars = 0;

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);

      // Skip whitespace and punctuation when counting total
      if (code > 32 && !_isPunctuation(code)) {
        totalChars++;

        if (code >= _bengaliStart && code <= _bengaliEnd) {
          bengaliChars++;
        }
      }
    }

    return totalChars > 0 ? (bengaliChars / totalChars) * 100 : 0.0;
  }

  /// Detect language of a text snippet (Bengali, English, Mixed)
  TextLanguage detectLanguage(String text) {
    final bengaliPercentage = calculateBengaliPercentage(text);

    if (bengaliPercentage >= 80) {
      return TextLanguage.bengali;
    } else if (bengaliPercentage <= 20) {
      return TextLanguage.other;
    } else {
      return TextLanguage.mixed;
    }
  }

  /// Categorize text using NLClassifier (if available)
  Future<Map<String, double>> categorizeText(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_textClassifier == null) {
      return {'unknown': 1.0};
    }

    try {
      // Normalize text before classification
      final normalizedText = normalizeText(text);

      // Classify the text
      final classifications = await _textClassifier!.classify(normalizedText);

      // Convert to map of category -> confidence
      final Map<String, double> result = {};
      for (final classification in classifications) {
        result[classification.label] = classification.score;
      }

      return result;
    } catch (e) {
      print('Error categorizing text: $e');
      return {'error': 0.0};
    }
  }

  /// Check if a character is punctuation
  bool _isPunctuation(int code) {
    return (code >= 33 && code <= 47) ||
        (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) ||
        (code >= 123 && code <= 126) ||
        code == 0x0964 || // Bengali Danda (।)
        code == 0x0965; // Bengali Double Danda (॥)
  }

  /// Find the most frequent words in a text
  Map<String, int> findMostFrequentWords(String text, {int limit = 10}) {
    final words = extractWords(text);
    final Map<String, int> wordCounts = {};

    // Count word frequencies
    for (final word in words) {
      wordCounts[word] = (wordCounts[word] ?? 0) + 1;
    }

    // Sort by frequency
    final sortedEntries = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return top words up to limit
    final Map<String, int> topWords = {};
    for (int i = 0; i < limit && i < sortedEntries.length; i++) {
      topWords[sortedEntries[i].key] = sortedEntries[i].value;
    }

    return topWords;
  }

  /// Extract sentiment from text (positive, negative, neutral)
  Future<TextSentiment> analyzeSentiment(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_textClassifier == null) {
      return TextSentiment.neutral;
    }

    try {
      // Normalize text before analysis
      final normalizedText = normalizeText(text);

      // Use classifier for sentiment analysis
      // This assumes the classifier has been trained for sentiment analysis
      final classifications = await _textClassifier!.classify(normalizedText);

      // Find highest scoring category
      String highestCategory = 'neutral';
      double highestScore = 0;

      for (final classification in classifications) {
        if (classification.score > highestScore) {
          highestScore = classification.score;
          highestCategory = classification.label;
        }
      }

      // Map to sentiment enum
      switch (highestCategory) {
        case 'positive':
          return TextSentiment.positive;
        case 'negative':
          return TextSentiment.negative;
        default:
          return TextSentiment.neutral;
      }
    } catch (e) {
      print('Error analyzing sentiment: $e');
      return TextSentiment.neutral;
    }
  }

  /// Release resources
  void dispose() {
  }
}

/// Language detection enum
enum TextLanguage {
  bengali,
  other,
  mixed,
}

/// Sentiment analysis enum
enum TextSentiment {
  positive,
  negative,
  neutral,
}

// Import necessary packages
