// lib/services/audio_service.dart
import 'dart:async';
import 'package:flutter/material.dart';

class AudioService {
  final MLService mlService;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  Timer? _processingTimer;
  final StreamController<KeywordData> _keywordStreamController = StreamController<KeywordData>.broadcast();

  Stream<KeywordData> get keywordStream => _keywordStreamController.stream;

  AudioService({required this.mlService});

  Future<void> initialize() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    await _recorder.openRecorder();
  }

  Future<void> startListening() async {
    if (_isRecording) return;

    await _recorder.startRecorder(
      toFile: 'temp_audio',
      codec: Codec.pcm16,
      sampleRate: 16000,
    );

    _isRecording = true;

    // Process audio every 5 seconds
    _processingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      // Temporarily pause recording
      final path = await _recorder.stopRecorder();

      // Process the audio file
      await _processAudioSegment(path!);

      // Resume recording
      await _recorder.startRecorder(
        toFile: 'temp_audio',
        codec: Codec.pcm16,
        sampleRate: 16000,
      );
    });
  }

  Future<void> stopListening() async {
    if (!_isRecording) return;

    _processingTimer?.cancel();
    await _recorder.stopRecorder();
    _isRecording = false;
  }

  Future<void> _processAudioSegment(String audioPath) async {
    try {
      // Use ML service to transcribe Bengali speech
      final transcription = await mlService.transcribeAudio(audioPath);

      // Extract keywords and their context
      final keywordData = await mlService.extractKeywords(transcription);

      // Push the keyword data to the stream
      _keywordStreamController.add(keywordData);

    } catch (e) {
      print('Error processing audio: $e');
    }
  }

  void dispose() {
    _processingTimer?.cancel();
    _recorder.closeRecorder();
    _keywordStreamController.close();
  }
}