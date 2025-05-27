// lib/services/audio_feature_extractor.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart';

class AudioFeatureExtractor {
  // Constants for feature extraction
  static const int SAMPLE_RATE = 16000;
  static const int FEATURE_SIZE = 13; // MFCC coefficients

  // TensorFlow Lite helper objects
  TensorAudioFormat? _audioFormat;
  MfccCalculator? _mfccCalculator;

  // Initialize the feature extractor
  Future<void> initialize() async {
    try {
      // Create audio format for 16kHz mono audio
      _audioFormat = TensorAudioFormat.create(1, SAMPLE_RATE);

      // Create MFCC options
      final mfccOptions = MfccOptions.create(
        sampleRate: SAMPLE_RATE,
        coefficientCount: FEATURE_SIZE,
      );

      // Create MFCC calculator
      _mfccCalculator = MfccCalculator.create(mfccOptions);
    } catch (e) {
      print('Error initializing AudioFeatureExtractor: $e');
      throw Exception('Failed to initialize AudioFeatureExtractor: $e');
    }
  }

  // Extract MFCC features from audio data
  Future<List<double>> extractMFCC(Uint8List audioData) async {
    try {
      if (_audioFormat == null || _mfccCalculator == null) {
        await initialize();
      }

      // Convert audio bytes to samples
      final samples = _convertToSamples(audioData);

      // Calculate duration in seconds
      final durationInSeconds = samples.length / SAMPLE_RATE;

      // Create TensorAudio object
      final tensorAudio = TensorAudio.create(
        _audioFormat!,
        durationInSeconds.ceil(),
      );

      // Load samples into TensorAudio
      tensorAudio.loadDoubleList(samples);

      // Process audio to get MFCC features
      final tensorBuffer = _mfccCalculator!.process(tensorAudio);

      // Get features as a list
      return tensorBuffer.getDoubleList();
    } catch (e) {
      print('Error extracting MFCC features: $e');

      // Return empty features array in case of error
      return List<double>.filled(FEATURE_SIZE, 0.0);
    }
  }

  // Convert raw audio bytes to PCM samples
  List<double> _convertToSamples(Uint8List audioData) {
    // Convert from bytes to 16-bit PCM samples
    final samples = <double>[];

    // Process 16-bit PCM data (2 bytes per sample)
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Combine two bytes into a 16-bit sample
      final int sampleValue = (audioData[i] & 0xFF) | ((audioData[i + 1] & 0xFF) << 8);

      // Convert to signed value
      final int signedValue = sampleValue > 32767 ? sampleValue - 65536 : sampleValue;

      // Normalize to range [-1.0, 1.0]
      final double normalizedValue = signedValue / 32768.0;

      samples.add(normalizedValue);
    }

    return samples;
  }

  // Apply pre-emphasis filter to audio samples
  List<double> _applyPreEmphasis(List<double> samples, double alpha) {
    if (samples.isEmpty) return [];

    final result = <double>[];
    result.add(samples[0]);

    for (int i = 1; i < samples.length; i++) {
      result.add(samples[i] - alpha * samples[i - 1]);
    }

    return result;
  }

  // Extract spectrogram features
  Future<List<List<double>>> extractSpectrogram(Uint8List audioData, {int fftSize = 512}) async {
    try {
      if (_audioFormat == null) {
        await initialize();
      }

      // Convert audio bytes to samples
      final samples = _convertToSamples(audioData);

      // Calculate duration in seconds
      final durationInSeconds = samples.length / SAMPLE_RATE;

      // Create TensorAudio object
      final tensorAudio = TensorAudio.create(
        _audioFormat!,
        durationInSeconds.ceil(),
      );

      // Load samples into TensorAudio
      tensorAudio.loadDoubleList(samples);

      // Create spectrogram options
      final spectrogramOptions = SpectrogramOptions.create(
        fftSize: fftSize,
        overlapFactor: 0.5, // 50% overlap between frames
      );

      // Create spectrogram calculator
      final spectrogramCalculator = SpectrogramCalculator.create(spectrogramOptions);

      // Process audio to get spectrogram
      final tensorBuffer = spectrogramCalculator.process(tensorAudio);

      // Extract the data to a 2D array
      final floatList = tensorBuffer.getFloatList();
      final List<List<double>> spectrogram = [];

      // Determine the dimensions
      final frameCount = tensorBuffer.getShape()[0];
      final freqBins = tensorBuffer.getShape()[1];

      for (int i = 0; i < frameCount; i++) {
        final frame = <double>[];
        for (int j = 0; j < freqBins; j++) {
          frame.add(floatList[i * freqBins + j]);
        }
        spectrogram.add(frame);
      }

      return spectrogram;
    } catch (e) {
      print('Error extracting spectrogram: $e');

      // Return empty spectrogram in case of error
      return [[]];
    }
  }

  // Calculate energy of audio signal
  double calculateEnergy(List<double> samples) {
    double energy = 0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    return energy / samples.length;
  }

  // Calculate zero crossing rate
  double calculateZeroCrossingRate(List<double> samples) {
    if (samples.length <= 1) return 0;

    int zeroCrossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i - 1] >= 0 && samples[i] < 0) ||
          (samples[i - 1] < 0 && samples[i] >= 0)) {
        zeroCrossings++;
      }
    }

    return zeroCrossings / (samples.length - 1);
  }

  // Check if audio segment contains speech
  bool containsSpeech(List<double> samples, {double energyThreshold = 0.01, double zcrThreshold = 0.1}) {
    final energy = calculateEnergy(samples);
    final zcr = calculateZeroCrossingRate(samples);

    // Simple rule-based speech detection
    return energy > energyThreshold && zcr < zcrThreshold;
  }

  void dispose() {
    // Cleanup resources if needed
  }
}