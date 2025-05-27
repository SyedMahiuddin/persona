// lib/services/insights_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:persona/serviec_storage.dart';
import 'model/model.dart';

class InsightsService {
  final StorageService _storageService;
  final StreamController<List<Insight>> _insightsStreamController =
  StreamController<List<Insight>>.broadcast();

  List<Insight> _currentInsights = [];
  Timer? _analysisTimer;

  Stream<List<Insight>> get insightsStream => _insightsStreamController.stream;
  List<Insight> get currentInsights => List.unmodifiable(_currentInsights);

  InsightsService({required StorageService storageService})
      : _storageService = storageService;

  Future<void> initialize() async {
    // Load initial insights
    await generateInsights();

    // Set up timer to regularly update insights
    _analysisTimer = Timer.periodic(Duration(hours: 1), (timer) async {
      await generateInsights();
    });
  }

  Future<void> generateInsights() async {
    try {
      final List<Insight> newInsights = [];

      // Load necessary data
      final keywordHistory = await _storageService.loadKeywordHistory();
      final activityHistory = await _storageService.loadActivityHistory();
      final userProfile = await _storageService.loadUserProfile() ;

      // Only generate insights if we have enough data
      if (keywordHistory.isEmpty || activityHistory.isEmpty) {
        return;
      }

      // 1. Activity pattern insights
      newInsights.addAll(await _generateActivityInsights(
          activityHistory,
          userProfile!
      ));

      // 2. Keyword and topic insights
      newInsights.addAll(await _generateKeywordInsights(
          keywordHistory,
          userProfile
      ));

      // 3. Schedule and routine insights
      newInsights.addAll(await _generateRoutineInsights(
          activityHistory,
          keywordHistory,
          userProfile
      ));

      // 4. Break and rest suggestion insights
      newInsights.addAll(await _generateBreakSuggestions(
          activityHistory,
          userProfile
      ));

      // Update insights list and notify listeners
      _currentInsights = newInsights;
      _insightsStreamController.add(_currentInsights);

    } catch (e) {
      print('Error generating insights: $e');
    }
  }

  Future<List<Insight>> _generateActivityInsights(
      List<ActivityData> activityHistory,
      UserProfile userProfile
      ) async {
    final List<Insight> insights = [];

    // Check if we have enough activity data
    if (activityHistory.length < 24) { // Need at least 2 hours of data
      return insights;
    }

    // Get recent activity data
    final recentActivity = activityHistory
        .sublist(activityHistory.length - 12); // Last hour

    // Calculate current activity level
    final avgMovementCount = recentActivity.fold<double>(
        0, (sum, data) => sum + data.movementCount
    ) / recentActivity.length;

    ActivityLevel currentLevel;
    if (avgMovementCount < 10) {
      currentLevel = ActivityLevel.low;
    } else if (avgMovementCount < 50) {
      currentLevel = ActivityLevel.medium;
    } else {
      currentLevel = ActivityLevel.high;
    }

    // Compare with predicted activity level from user profile
    final predictedLevel = userProfile.getPredictedActivityLevel();

    if (currentLevel != predictedLevel) {
      // Current activity doesn't match usual pattern
      insights.add(Insight(
        type: InsightType.activity,
        title: 'Unusual Activity Level',
        description: 'Your current activity level is ${_activityLevelToString(currentLevel)}, ' +
            'which is different from your usual ${_activityLevelToString(predictedLevel)} ' +
            'activity at this time.',
        timestamp: DateTime.now(),
        priority: InsightPriority.medium,
      ));
    }

    // Check for sustained high activity
    final allHigh = recentActivity.every((data) => data.movementCount > 50);
    if (allHigh) {
      insights.add(Insight(
        type: InsightType.activity,
        title: 'Sustained High Activity',
        description: 'You\'ve been highly active for the past hour. ' +
            'Consider taking a short break soon.',
        timestamp: DateTime.now(),
        priority: InsightPriority.high,
      ));
    }

    // Check for sustained low activity
    final allLow = recentActivity.every((data) => data.movementCount < 10);
    if (allLow) {
      insights.add(Insight(
        type: InsightType.activity,
        title: 'Low Activity Period',
        description: 'You\'ve been relatively inactive for the past hour. ' +
            'Consider some light movement or stretching.',
        timestamp: DateTime.now(),
        priority: InsightPriority.medium,
      ));
    }

    return insights;
  }

  Future<List<Insight>> _generateKeywordInsights(
      List<KeywordData> keywordHistory,
      UserProfile userProfile
      ) async {
    final List<Insight> insights = [];

    // Check if we have enough keyword data
    if (keywordHistory.length < 5) {
      return insights;
    }

    // Get recent keyword data
    final recentKeywords = keywordHistory
        .sublist(keywordHistory.length - 5);

    // Collect all keywords and their frequencies
    final Map<String, int> allKeywords = {};

    for (final data in recentKeywords) {
      data.keywords.forEach((keyword, count) {
        allKeywords[keyword] = (allKeywords[keyword] ?? 0) + count;
      });
    }

    // Find top keywords
    final List<MapEntry<String, int>> sortedKeywords = allKeywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedKeywords.length >= 3) {
      final topKeywords = sortedKeywords.sublist(0, 3);

      insights.add(Insight(
        type: InsightType.keywords,
        title: 'Recent Topics',
        description: 'You\'ve been frequently discussing: ' +
            '${topKeywords.map((e) => e.key).join(", ")}.',
        timestamp: DateTime.now(),
        priority: InsightPriority.low,
      ));
    }

    // Check for action-related keywords
    final actionKeywords = {
      'buy': 'কেনা', // "kena" (buy)
      'sell': 'বিক্রয়', // "bikroy" (sell)
      'get': 'নেওয়া', // "neowa" (get/take)
      'book': 'বই', // "boi" (book)
      'appointment': 'অ্যাপয়েন্টমেন্ট', // "appointment"
      'meeting': 'সভা', // "shobha" (meeting)
      'call': 'কল', // "call"
      'deadline': 'সময়সীমা', // "shomoyshima" (deadline)
    };

    // Check for action relationships
    for (final data in recentKeywords) {
      actionKeywords.forEach((action, bengaliWord) {
        if (data.keywords.containsKey(bengaliWord)) {
          // Find related keywords for this action
          final relatedWords = data.relatedKeywords[bengaliWord] ?? [];

          if (relatedWords.isNotEmpty) {
            insights.add(Insight(
              type: InsightType.actionItem,
              title: 'Potential Action Item',
              description: 'You mentioned "${bengaliWord}" in relation to ' +
                  '"${relatedWords.join(", ")}". Do you need to ' +
                  '${action} something?',
              timestamp: DateTime.now(),
              priority: InsightPriority.high,
            ));
          }
        }
      });
    }

    return insights;
  }

  Future<List<Insight>> _generateRoutineInsights(
      List<ActivityData> activityHistory,
      List<KeywordData> keywordHistory,
      UserProfile userProfile
      ) async {
    final List<Insight> insights = [];

    // Get current time
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;

    // Check for upcoming meal times
    final MealType? upcomingMeal = _checkForUpcomingMeal(
        now, userProfile);

    if (upcomingMeal != null) {
      final mealTimes = userProfile.getMealTimes(upcomingMeal);

      if (mealTimes != null && mealTimes.isNotEmpty) {
        final mealTime = mealTimes.first;
        final mealName = _mealTypeToString(upcomingMeal);

        // Calculate time until meal
        final int mealMinutes = mealTime.hour * 60 + mealTime.minute;
        final int currentMinutes = currentHour * 60 + currentMinute;
        final int minutesUntilMeal = mealMinutes - currentMinutes;

        if (minutesUntilMeal > 0 && minutesUntilMeal <= 30) {
          insights.add(Insight(
            type: InsightType.routine,
            title: '$mealName Coming Up',
            description: 'Based on your usual routine, you typically have ' +
                '$mealName in about ${minutesUntilMeal} minutes.',
            timestamp: DateTime.now(),
            priority: InsightPriority.medium,
          ));
        }
      }
    }

    // Check for unusual routine deviations
    final weekday = now.weekday;

    if (userProfile.weeklyPatterns.containsKey('activity')) {
      final pattern = userProfile.weeklyPatterns['activity']!;

      if (pattern.hourlyPatterns.containsKey(weekday) &&
          pattern.hourlyPatterns[weekday]!.containsKey(currentHour)) {

        final expectedActivity = pattern.hourlyPatterns[weekday]![currentHour]!;

        // Get recent activity
        if (activityHistory.isNotEmpty) {
          final recentActivity = activityHistory.last;
          final normalizedActivity = recentActivity.movementCount / 100.0;

          // If big difference between expected and actual
          if ((normalizedActivity - expectedActivity).abs() > 0.5) {
            insights.add(Insight(
              type: InsightType.routine,
              title: 'Routine Change Detected',
              description: 'Your current activity level is different from ' +
                  'your usual pattern for this time on ${_weekdayToString(weekday)}.',
              timestamp: DateTime.now(),
              priority: InsightPriority.low,
            ));
          }
        }
      }
    }

    return insights;
  }

  Future<List<Insight>> _generateBreakSuggestions(
      List<ActivityData> activityHistory,
      UserProfile userProfile
      ) async {
    final List<Insight> insights = [];

    // Check if we have enough activity data
    if (activityHistory.length < 36) { // Need at least 3 hours of data
      return insights;
    }

    // Check for sustained high activity
    final recentActivity = activityHistory
        .sublist(activityHistory.length - 36); // Last 3 hours

    // Count consecutive high activity periods (5-minute intervals)
    int consecutiveHighActivity = 0;
    for (final data in recentActivity) {
      if (data.movementCount > 50) {
        consecutiveHighActivity++;
      } else {
        // Reset counter on low activity period
        consecutiveHighActivity = 0;
      }
    }

    // If more than 1 hour of high activity
    if (consecutiveHighActivity >= 12) {
      insights.add(Insight(
        type: InsightType.breakSuggestion,
        title: 'Time for a Break',
        description: 'You\'ve been highly active for over an hour. ' +
            'Consider taking a short break to rest.',
        timestamp: DateTime.now(),
        priority: InsightPriority.high,
      ));
    }

    // Check for very low movement for extended period
    int consecutiveLowActivity = 0;
    for (final data in recentActivity) {
      if (data.movementCount < 5) {
        consecutiveLowActivity++;
      } else {
        // Reset counter on any significant activity
        consecutiveLowActivity = 0;
      }
    }

    // If more than 1 hour of very low activity
    if (consecutiveLowActivity >= 12) {
      insights.add(Insight(
        type: InsightType.breakSuggestion,
        title: 'Time to Move',
        description: 'You\'ve been sitting still for over an hour. ' +
            'Consider taking a short walk or doing some stretches.',
        timestamp: DateTime.now(),
        priority: InsightPriority.medium,
      ));
    }

    return insights;
  }

  // Helper method to check for upcoming meals
  MealType? _checkForUpcomingMeal(DateTime now, UserProfile userProfile) {
    final currentHour = now.hour;

    // Check for breakfast
    final breakfastTimes = userProfile.getMealTimes(MealType.breakfast);
    if (breakfastTimes != null &&
        breakfastTimes.isNotEmpty &&
        _isUpcoming(now, breakfastTimes.first)) {
      return MealType.breakfast;
    }

    // Check for lunch
    final lunchTimes = userProfile.getMealTimes(MealType.lunch);
    if (lunchTimes != null &&
        lunchTimes.isNotEmpty &&
        _isUpcoming(now, lunchTimes.first)) {
      return MealType.lunch;
    }

    // Check for dinner
    final dinnerTimes = userProfile.getMealTimes(MealType.dinner);
    if (dinnerTimes != null &&
        dinnerTimes.isNotEmpty &&
        _isUpcoming(now, dinnerTimes.first)) {
      return MealType.dinner;
    }

    return null;
  }

  // Helper method to check if a time is upcoming
  bool _isUpcoming(DateTime now, TimeOfDay mealTime) {
    final currentMinutes = now.hour * 60 + now.minute;
    final mealMinutes = mealTime.hour * 60 + mealTime.minute;

    final minutesUntilMeal = mealMinutes - currentMinutes;

    // Consider it upcoming if it's between 0 and 60 minutes away
    return minutesUntilMeal > 0 && minutesUntilMeal <= 60;
  }

  String _activityLevelToString(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.low:
        return 'low';
      case ActivityLevel.medium:
        return 'moderate';
      case ActivityLevel.high:
        return 'high';
    }
  }

  String _mealTypeToString(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
    }
  }

  String _weekdayToString(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  void dispose() {
    _analysisTimer?.cancel();
    _insightsStreamController.close();
  }
}

// Insight model
class Insight {
  final InsightType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final InsightPriority priority;

  Insight({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.priority,
  });
}

enum InsightType {
  activity,
  keywords,
  routine,
  actionItem,
  breakSuggestion,
}

enum InsightPriority {
  low,
  medium,
  high,
}