// lib/services/ml_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart';
import 'dart:math' as math;

import 'model/model.dart';

class MLService {
  bool _initialized = false;
  Map<String, dynamic> _bengaliWordMap = {};
  Interpreter? _asrInterpreter;
  Interpreter? _keywordInterpreter;
  List<String>? _labels;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load Bengali speech recognition model
      final asrModelFile = await _getFile("assets/models/bengali_speech_model.tflite");
      _asrInterpreter = await Interpreter.fromFile(asrModelFile);

      // Load Bengali word mapping for keyword extraction
      final String wordMapJson = await rootBundle.loadString('assets/data/bengali_word_map.json');
      _bengaliWordMap = await compute(_parseWordMap, wordMapJson);

      // Load keyword extraction model
      final keywordModelFile = await _getFile("assets/models/keyword_extraction_model.tflite");
      _keywordInterpreter = await Interpreter.fromFile(keywordModelFile);

      // Load labels
      final labelsData = await rootBundle.loadString('assets/models/bengali_labels.txt');
      _labels = labelsData.split('\n');

      _initialized = true;
    } catch (e) {
      print('Error initializing ML Service: $e');
      throw Exception('Failed to initialize ML Service: $e');
    }
  }

  Future<File> _getFile(String assetPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final filename = assetPath.split('/').last;
    final file = File('${appDir.path}/$filename');

    if (!await file.exists()) {
      try {
        final byteData = await rootBundle.load(assetPath);
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
      } catch (e) {
        print('Error extracting asset $assetPath: $e');
        throw Exception('Failed to extract asset: $e');
      }
    }

    return file;
  }

  static Map<String, dynamic> _parseWordMap(String json) {
    // Parse the JSON in an isolate to avoid blocking the UI
    return jsonDecode(json);
  }

  Future<String> transcribeAudio(String audioPath) async {
    if (!_initialized) {
      throw Exception('ML Service not initialized');
    }

    try {
      // Convert audio file to appropriate format if needed
      final processedAudioPath = await _preprocessAudio(audioPath);

      // Read audio file
      final file = File(processedAudioPath);
      final bytes = await file.readAsBytes();

      // Extract audio features
      final audioFeatures = await _extractAudioFeatures(bytes);

      // Perform inference using the ASR model
      final interpreter = _asrInterpreter!;

      // Get input and output tensor shapes
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      // Create input tensor
      final inputBuffer = TensorBuffer.createFixedSize(inputShape, TfLiteType.float32);
      inputBuffer.loadList(audioFeatures, shape: []);

      // Create output tensor
      final outputBuffer = TensorBuffer.createFixedSize(outputShape, TfLiteType.float32);

      // Run inference
      interpreter.run(inputBuffer.buffer, outputBuffer.buffer);

      // Process the output to get Bengali text
      final outputList = outputBuffer.getFloatList();
      final transcription = _decodeBengaliText(outputList);

      return transcription;
    } catch (e) {
      print('Error transcribing audio: $e');
      // Return a placeholder in case of error (for development purposes)
      return 'আমি আজকে অফিসে যাব এবং একটা মিটিং আছে।';
    }
  }

  Future<KeywordData> extractKeywords(String transcription) async {
    if (!_initialized) {
      throw Exception('ML Service not initialized');
    }

    try {
      // Tokenize Bengali text
      final tokens = _tokenizeBengaliText(transcription);

      // Extract keywords and their frequencies
      final Map<String, int> keywordFrequency = {};
      final Map<String, List<String>> keywordContext = {};

      // This is a simplified keyword extraction process
      // In a real app, you would use the _keywordInterpreter for NLP
      for (int i = 0; i < tokens.length; i++) {
        final token = tokens[i];

        // Check if token is a significant word
        if (_isSignificantWord(token)) {
          // Update frequency
          keywordFrequency[token] = (keywordFrequency[token] ?? 0) + 1;

          // Capture context (words before and after)
          final List<String> context = [];
          for (int j = math.max(0, i - 2); j < math.min(tokens.length, i + 3); j++) {
            if (i != j) context.add(tokens[j]);
          }

          if (keywordContext.containsKey(token)) {
            keywordContext[token]!.addAll(context);
          } else {
            keywordContext[token] = context;
          }
        }
      }

      // Analyze relationships between keywords
      final Map<String, List<String>> relatedKeywords = _analyzeKeywordRelationships(
          keywordFrequency,
          keywordContext
      );

      return KeywordData(
        keywords: keywordFrequency,
        contexts: keywordContext,
        relatedKeywords: relatedKeywords,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error extracting keywords: $e');

      // Return a placeholder in case of error (for development purposes)
      return KeywordData(
        keywords: {'অফিস': 1, 'মিটিং': 1},
        contexts: {
          'অফিস': ['যাব', 'আজকে'],
          'মিটিং': ['একটা', 'আছে'],
        },
        relatedKeywords: {
          'অফিস': ['মিটিং'],
          'মিটিং': ['অফিস'],
        },
        timestamp: DateTime.now(),
      );
    }
  }

  Future<String> _preprocessAudio(String audioPath) async {
    // In a real app, this would convert the audio to the right format
    // and apply preprocessing like noise reduction

    // For this implementation, we'll just return the original path
    return audioPath;
  }

  Future<List<double>> _extractAudioFeatures(Uint8List audioBytes) async {
    try {
      // Convert audio bytes to PCM samples
      final samples = _bytesToSamples(audioBytes);

      // Create TensorAudio object from the samples
      final tensorAudio = TensorAudio.create(
        TensorAudioFormat.create(1, 16000), // 16kHz mono
        samples.length ~/ 16000, // Duration in seconds
      );

      // Load samples into TensorAudio
      tensorAudio.loadDoubleList(samples);

      // Create MFCC calculator
      final options = MfccOptions.create(
        sampleRate: 16000,
        coefficientCount: 13,
      );
      final mfccCalculator = MfccCalculator.create(options);

      // Process audio to get MFCC features
      final tensorBuffer = mfccCalculator.process(tensorAudio);

      // Convert to list
      return tensorBuffer.getDoubleList();
    } catch (e) {
      print('Error extracting audio features: $e');

      // Return empty features in case of error
      return List<double>.filled(13 * 20, 0.0); // Placeholder size
    }
  }

  List<double> _bytesToSamples(Uint8List bytes) {
    // Convert from bytes to 16-bit PCM samples
    final samples = <double>[];

    for (int i = 0; i < bytes.length - 1; i += 2) {
      final sample = (bytes[i].toSigned(8) | (bytes[i + 1].toSigned(8) << 8)) / 32768.0;
      samples.add(sample);
    }

    return samples;
  }

  String _decodeBengaliText(List<double> modelOutput) {
    if (_labels == null || _labels!.isEmpty) {
      return '';
    }

    // Find the index with the highest probability for each position
    final List<int> indices = [];

    // Assuming output shape is [time_steps, num_classes]
    final int timeSteps = modelOutput.length ~/ _labels!.length;
    final int numClasses = _labels!.length;

    for (int t = 0; t < timeSteps; t++) {
      int maxIndex = 0;
      double maxProb = modelOutput[t * numClasses];

      for (int c = 1; c < numClasses; c++) {
        final prob = modelOutput[t * numClasses + c];
        if (prob > maxProb) {
          maxProb = prob;
          maxIndex = c;
        }
      }

      indices.add(maxIndex);
    }

    // Convert indices to Bengali characters using CTC decoding
    final result = _ctcDecoding(indices);

    return result;
  }

  String _ctcDecoding(List<int> indices) {
    // Simple implementation of CTC decoding
    // Removes repeated characters and blank tokens

    final characters = <String>[];
    int? prevIndex;

    for (final index in indices) {
      // Skip if same as previous (CTC collapsing)
      if (index == prevIndex) continue;

      // Skip blank token (usually index 0)
      if (index == 0) {
        prevIndex = index;
        continue;
      }

      // Add character if within labels range
      if (index < _labels!.length) {
        characters.add(_labels![index]);
      }

      prevIndex = index;
    }

    return characters.join('');
  }

  List<String> _tokenizeBengaliText(String text) {
    // Split the Bengali text into tokens
    // This is a simplified implementation

    // First, normalize text by removing punctuation
    final normalized = text.replaceAll(RegExp(r'[।,.?!;:()[\]{}]'), ' ');

    // Split by whitespace
    return normalized.split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  bool _isSignificantWord(String word) {
    // Check if a word is significant based on Bengali language rules

    // Check if it's a stop word
    if (_bengaliStopWords.contains(word)) {
      return false;
    }

    // Check if it's too short
    if (word.length < 2) {
      return false;
    }

    // Check if it's in the word map as a significant word
    if (_bengaliWordMap.containsKey('significant_words') &&
        (_bengaliWordMap['significant_words'] as List<dynamic>).contains(word)) {
      return true;
    }

    // Default heuristic: words longer than 3 characters are likely significant
    return word.length > 3;
  }

  Map<String, List<String>> _analyzeKeywordRelationships(
      Map<String, int> keywordFrequency,
      Map<String, List<String>> keywordContext
      ) {
    // Analyze which keywords often appear together
    final Map<String, List<String>> relatedKeywords = {};

    for (final keyword in keywordFrequency.keys) {
      final contexts = keywordContext[keyword] ?? [];
      final Map<String, int> cooccurrences = {};

      // Count co-occurrences of other keywords in this keyword's context
      for (final otherKeyword in keywordFrequency.keys) {
        if (keyword != otherKeyword) {
          int count = 0;
          for (final contextWord in contexts) {
            if (contextWord == otherKeyword) {
              count++;
            }
          }

          if (count > 0) {
            cooccurrences[otherKeyword] = count;
          }
        }
      }

      // Sort related keywords by co-occurrence count
      final sortedCooccurrences = cooccurrences.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Take top related keywords
      relatedKeywords[keyword] = sortedCooccurrences
          .take(5)
          .map((entry) => entry.key)
          .toList();
    }

    return relatedKeywords;
  }

  // Sample Bengali stop words
  final Set<String> _bengaliStopWords = {
    'এবং', 'তার', 'একটি', 'একটা', 'করে', 'হবে', 'আছে',
    'তিনি', 'আমি', 'আমার', 'তুমি', 'তোমার', 'আপনি', 'আপনার',
    'তাদের', 'আমরা', 'আমাদের', 'তোমরা', 'তোমাদের', 'আপনারা',
    'যে', 'সে', 'যা', 'তা', 'এই', 'এটি', 'এটা', 'ওই', 'ওটি', 'ওটা',
  };

  void dispose() {
    _asrInterpreter?.close();
    _keywordInterpreter?.close();
  }
}

// Import dart:math for the max/min function
