// lib/services/bengali_asr_interpreter.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart';
import 'audio_feature.dart';

class BengaliASRInterpreter {
  late Interpreter _interpreter;
  late List<String> _labels;
  late AudioFeatureExtractor _featureExtractor;

  bool _isInitialized = false;

  /// Initializes the ASR interpreter with the model and labels
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load model
      final modelFile = await _getModel();
      _interpreter = await Interpreter.fromFile(modelFile);

      // Load labels
      final labelsData = await rootBundle.loadString('assets/models/bengali_labels.txt');
      _labels = labelsData.split('\n');

      // Initialize feature extractor
      _featureExtractor = AudioFeatureExtractor();
      await _featureExtractor.initialize();

      _isInitialized = true;
      print('Bengali ASR interpreter initialized successfully');
    } catch (e) {
      print('Failed to initialize Bengali ASR interpreter: $e');
      throw Exception('Failed to initialize Bengali ASR interpreter: $e');
    }
  }

  /// Gets the model file, extracting it from assets if necessary
  Future<File> _getModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/bengali_asr_model.tflite';
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        print('Extracting Bengali ASR model from assets');
        final byteData = await rootBundle.load('assets/models/bengali_speech_model.tflite');
        final buffer = byteData.buffer;
        await modelFile.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
        );
        print('Model extracted to: $modelPath');
      }

      return modelFile;
    } catch (e) {
      print('Error getting model file: $e');
      throw Exception('Failed to extract model: $e');
    }
  }

  /// Transcribes audio from a file
  Future<String> transcribeFile(String audioFilePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Read the audio file
      final file = File(audioFilePath);
      final bytes = await file.readAsBytes();

      // Extract features
      final features = await _featureExtractor.extractMFCC(bytes);

      // Run inference
      return await processAudio(features);
    } catch (e) {
      print('Error transcribing audio file: $e');
      return '';
    }
  }

  /// Processes audio features and returns transcription
  Future<String> processAudio(List<double> audioFeatures) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Get input and output tensor shapes
      final inputShape = _interpreter.getInputTensor(0).shape;
      final inputType = _interpreter.getInputTensor(0).type;

      // Reshape audio features if needed
      List<double> reshapedFeatures = audioFeatures;

      // If feature dimensions don't match model input, reshape them
      if (audioFeatures.length != inputShape.reduce((a, b) => a * b)) {
        // In a real implementation, this would require proper reshaping
        // based on the model's expected input format
        print('Warning: Feature dimensions mismatch. Reshaping needed.');
        reshapedFeatures = audioFeatures.sublist(0, min(audioFeatures.length, inputShape.reduce((a, b) => a * b)));
      }

      // Create input tensor buffer
      final inputBuffer = TensorBuffer.createFixedSize(inputShape, inputType);
      inputBuffer.loadList(reshapedFeatures, shape: []);

      // Prepare output tensor
      final outputShape = _interpreter.getOutputTensor(0).shape;
      final outputType = _interpreter.getOutputTensor(0).type;
      final outputBuffer = TensorBuffer.createFixedSize(outputShape, outputType);

      // Run inference
      _interpreter.run(inputBuffer.buffer, outputBuffer.buffer);

      // Process output to get Bengali text
      final outputList = outputType == TfLiteType.uint8
          ? outputBuffer.getUint8List()
          : outputBuffer.getFloatList().map((e) => e.round()).toList();

      final bengaliText = _decodeOutput(outputList);

      return bengaliText;
    } catch (e) {
      print('Error processing audio: $e');
      return '';
    }
  }

  /// Decodes model output to Bengali text
  String _decodeOutput(List<dynamic> output) {
    try {
      // Convert output indices to Bengali characters
      final characters = <String>[];
      int? prevIndex;

      // Apply CTC decoding (remove duplicates and blanks)
      // Assuming 0 is the blank token
      for (final index in output) {
        // Skip if it's the same as previous or blank token
        if (index == prevIndex || index == 0) {
          prevIndex = index;
          continue;
        }

        // Add the character if index is valid
        if (index < _labels.length) {
          characters.add(_labels[index]);
        }

        prevIndex = index;
      }

      // Join characters and clean up result
      final text = characters.join('')
          .replaceAll('<pad>', '')
          .replaceAll('<unk>', '');

      return text.trim();
    } catch (e) {
      print('Error decoding output: $e');
      return '';
    }
  }

  /// Processes audio in chunks for streaming recognition
  Future<String> processAudioChunk(Uint8List audioChunk) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Extract features from audio chunk
      final features = await _featureExtractor.extractMFCC(audioChunk);

      // Process the features
      return await processAudio(features);
    } catch (e) {
      print('Error processing audio chunk: $e');
      return '';
    }
  }

  /// Gets the input tensor shape for the model
  List<int> getInputShape() {
    if (!_isInitialized) {
      throw Exception('Interpreter not initialized');
    }

    return _interpreter.getInputTensor(0).shape;
  }

  /// Gets the output tensor shape for the model
  List<int> getOutputShape() {
    if (!_isInitialized) {
      throw Exception('Interpreter not initialized');
    }

    return _interpreter.getOutputTensor(0).shape;
  }

  /// Releases resources
  void close() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
    }
  }
}

