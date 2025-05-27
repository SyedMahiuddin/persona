// lib/models/keyword_data.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
class KeywordData {
  final Map<String, int> keywords;
  final Map<String, List<String>> contexts;
  final Map<String, List<String>> relatedKeywords;
  final DateTime timestamp;

  KeywordData({
    required this.keywords,
    required this.contexts,
    required this.relatedKeywords,
    required this.timestamp,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'keywords': keywords,
      'contexts': contexts.map((key, value) => MapEntry(key, value)),
      'relatedKeywords': relatedKeywords.map((key, value) => MapEntry(key, value)),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create from JSON for retrieval
  factory KeywordData.fromJson(Map<String, dynamic> json) {
    return KeywordData(
      keywords: Map<String, int>.from(json['keywords']),
      contexts: Map<String, List<String>>.from(
          json['contexts'].map((key, value) => MapEntry(key, List<String>.from(value)))
      ),
      relatedKeywords: Map<String, List<String>>.from(
          json['relatedKeywords'].map((key, value) => MapEntry(key, List<String>.from(value)))
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// lib/models/activity_data.dart
class ActivityData {
  final DateTime timestamp;
  final int movementCount;
  final double movementIntensity;
  final Duration timeSinceLastMove;

  ActivityData({
    required this.timestamp,
    required this.movementCount,
    required this.movementIntensity,
    required this.timeSinceLastMove,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'movementCount': movementCount,
      'movementIntensity': movementIntensity,
      'timeSinceLastMove': timeSinceLastMove.inSeconds,
    };
  }

  // Create from JSON for retrieval
  factory ActivityData.fromJson(Map<String, dynamic> json) {
    return ActivityData(
      timestamp: DateTime.parse(json['timestamp']),
      movementCount: json['movementCount'],
      movementIntensity: json['movementIntensity'],
      timeSinceLastMove: Duration(seconds: json['timeSinceLastMove']),
    );
  }
}



class UserProfile extends ChangeNotifier {
  // User's routines detected by the system
  Map<String, DailyPattern> _dailyPatterns = {};
  Map<String, WeeklyPattern> _weeklyPatterns = {};

  // User's common activities and their typical times
  Map<String, List<TimeOfDay>> _commonActivities = {};

  // User's detected preferences
  Map<String, double> _preferenceRatings = {};

  // User's language usage stats
  int _bengaliPercentage = 95;
  int _otherLanguagePercentage = 5;

  // Getters
  Map<String, DailyPattern> get dailyPatterns => _dailyPatterns;
  Map<String, WeeklyPattern> get weeklyPatterns => _weeklyPatterns;
  Map<String, List<TimeOfDay>> get commonActivities => _commonActivities;
  Map<String, double> get preferenceRatings => _preferenceRatings;
  int get bengaliPercentage => _bengaliPercentage;

  // Methods to update profile based on new data
  void updateDailyPatterns(Map<String, DailyPattern> newPatterns) {
    _dailyPatterns = newPatterns;
    notifyListeners();
  }

  void updateWeeklyPatterns(Map<String, WeeklyPattern> newPatterns) {
    _weeklyPatterns = newPatterns;
    notifyListeners();
  }

  void addActivity(String activity, TimeOfDay time) {
    if (!_commonActivities.containsKey(activity)) {
      _commonActivities[activity] = [];
    }

    _commonActivities[activity]!.add(time);
    notifyListeners();
  }

  void updatePreference(String item, double rating) {
    _preferenceRatings[item] = rating;
    notifyListeners();
  }

  void updateLanguageStats(int bengaliPercent) {
    _bengaliPercentage = bengaliPercent;
    _otherLanguagePercentage = 100 - bengaliPercent;
    notifyListeners();
  }

  // Get the user's typical meal times
  List<TimeOfDay>? getMealTimes(MealType type) {
    String mealKey;

    switch (type) {
      case MealType.breakfast:
        mealKey = 'breakfast';
        break;
      case MealType.lunch:
        mealKey = 'lunch';
        break;
      case MealType.dinner:
        mealKey = 'dinner';
        break;
    }

    return _commonActivities[mealKey];
  }

  // Get user's predicted activity level for current time
  ActivityLevel getPredictedActivityLevel() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final hour = now.hour;

    // Check if we have patterns for this weekday and hour
    if (_weeklyPatterns.containsKey('activity') &&
        _weeklyPatterns['activity']!.hourlyPatterns.containsKey(weekday) &&
        _weeklyPatterns['activity']!.hourlyPatterns[weekday]!.containsKey(hour)) {

      final activityValue = _weeklyPatterns['activity']!.hourlyPatterns[weekday]![hour]!;

      if (activityValue < 0.3) {
        return ActivityLevel.low;
      } else if (activityValue < 0.7) {
        return ActivityLevel.medium;
      } else {
        return ActivityLevel.high;
      }
    }

    return ActivityLevel.medium; // Default
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'dailyPatterns': _dailyPatterns.map((key, value) => MapEntry(key, value.toJson())),
      'weeklyPatterns': _weeklyPatterns.map((key, value) => MapEntry(key, value.toJson())),
      'commonActivities': _commonActivities.map((key, value) =>
          MapEntry(key, value.map((time) =>
          {'hour': time.hour, 'minute': time.minute}).toList())),
      'preferenceRatings': _preferenceRatings,
      'bengaliPercentage': _bengaliPercentage,
    };
  }

  // Create from JSON for retrieval
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = UserProfile();

    profile._dailyPatterns = Map<String, DailyPattern>.from(
        json['dailyPatterns'].map((key, value) =>
            MapEntry(key, DailyPattern.fromJson(value))));

    profile._weeklyPatterns = Map<String, WeeklyPattern>.from(
        json['weeklyPatterns'].map((key, value) =>
            MapEntry(key, WeeklyPattern.fromJson(value))));

    profile._commonActivities = Map<String, List<TimeOfDay>>.from(
        json['commonActivities'].map((key, value) =>
            MapEntry(key, (value as List).map((time) =>
                TimeOfDay(hour: time['hour'], minute: time['minute'])).toList())));

    profile._preferenceRatings = Map<String, double>.from(json['preferenceRatings']);
    profile._bengaliPercentage = json['bengaliPercentage'];
    profile._otherLanguagePercentage = 100 - profile._bengaliPercentage;

    return profile;
  }
}

enum MealType { breakfast, lunch, dinner }
enum ActivityLevel { low, medium, high }

// lib/models/pattern_detection.dart


// Daily pattern class to represent patterns over a 24-hour period
class DailyPattern {
  final String name;
  final Map<int, double> hourlyValues; // Hour -> Activity level (0-1)
  final DateTime lastUpdated;

  DailyPattern({
    required this.name,
    required this.hourlyValues,
    required this.lastUpdated,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'hourlyValues': hourlyValues.map((key, value) => MapEntry(key.toString(), value)),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Create from JSON for retrieval
  factory DailyPattern.fromJson(Map<String, dynamic> json) {
    return DailyPattern(
      name: json['name'],
      hourlyValues: Map<int, double>.from(
          json['hourlyValues'].map((key, value) => MapEntry(int.parse(key), value))
      ),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

// Weekly pattern class to represent patterns over a week
class WeeklyPattern {
  final String name;
  // Map<Weekday, Map<Hour, Value>>
  final Map<int, Map<int, double>> hourlyPatterns;
  final DateTime lastUpdated;

  WeeklyPattern({
    required this.name,
    required this.hourlyPatterns,
    required this.lastUpdated,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'hourlyPatterns': hourlyPatterns.map((weekday, hours) =>
          MapEntry(weekday.toString(),
              hours.map((hour, value) => MapEntry(hour.toString(), value)))),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Create from JSON for retrieval
  factory WeeklyPattern.fromJson(Map<String, dynamic> json) {
    return WeeklyPattern(
      name: json['name'],
      hourlyPatterns: Map<int, Map<int, double>>.from(
          json['hourlyPatterns'].map((weekday, hours) =>
              MapEntry(int.parse(weekday),
                  Map<int, double>.from(hours.map((hour, value) =>
                      MapEntry(int.parse(hour), value)))))),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

// Pattern detector class that analyzes data for patterns
class PatternDetector {
  // Detect daily patterns from activity data
  static DailyPattern detectDailyActivityPattern(List<ActivityData> activityData) {
    // Initialize hourly values map
    final Map<int, List<double>> hourlyActivityValues = {};

    // Group activity data by hour
    for (final data in activityData) {
      final hour = data.timestamp.hour;
      if (!hourlyActivityValues.containsKey(hour)) {
        hourlyActivityValues[hour] = [];
      }

      // Normalize movement count to a 0-1 scale (assumed max count is 100)
      final normalizedValue = data.movementCount / 100.0;
      hourlyActivityValues[hour]!.add(normalizedValue.clamp(0.0, 1.0));
    }

    // Calculate average for each hour
    final Map<int, double> hourlyAverages = {};

    hourlyActivityValues.forEach((hour, values) {
      if (values.isNotEmpty) {
        final average = values.reduce((a, b) => a + b) / values.length;
        hourlyAverages[hour] = average;
      }
    });

    // Fill in missing hours with interpolated values
    for (int hour = 0; hour < 24; hour++) {
      if (!hourlyAverages.containsKey(hour)) {
        // Find nearest hours with data
        int prevHour = hour - 1;
        while (prevHour >= 0 && !hourlyAverages.containsKey(prevHour)) {
          prevHour--;
        }

        int nextHour = hour + 1;
        while (nextHour < 24 && !hourlyAverages.containsKey(nextHour)) {
          nextHour++;
        }

        // Interpolate or use nearest value
        if (prevHour >= 0 && nextHour < 24) {
          // Linear interpolation
          final prevValue = hourlyAverages[prevHour]!;
          final nextValue = hourlyAverages[nextHour]!;
          final ratio = (hour - prevHour) / (nextHour - prevHour);
          hourlyAverages[hour] = prevValue + (nextValue - prevValue) * ratio;
        } else if (prevHour >= 0) {
          hourlyAverages[hour] = hourlyAverages[prevHour]!;
        } else if (nextHour < 24) {
          hourlyAverages[hour] = hourlyAverages[nextHour]!;
        } else {
          hourlyAverages[hour] = 0.0; // Default value
        }
      }
    }

    return DailyPattern(
      name: 'activity',
      hourlyValues: hourlyAverages,
      lastUpdated: DateTime.now(),
    );
  }

  // Detect weekly patterns from daily patterns
  static WeeklyPattern detectWeeklyPattern(
      Map<DateTime, DailyPattern> dailyPatterns,
      String patternName
      ) {
    // Initialize weekly pattern data structure
    final Map<int, Map<int, List<double>>> weekdayHourValues = {};

    // Initialize all weekdays and hours
    for (int weekday = 1; weekday <= 7; weekday++) {
      weekdayHourValues[weekday] = {};
      for (int hour = 0; hour < 24; hour++) {
        weekdayHourValues[weekday]![hour] = [];
      }
    }

    // Group data by weekday and hour
    dailyPatterns.forEach((date, pattern) {
      final weekday = date.weekday;

      pattern.hourlyValues.forEach((hour, value) {
        weekdayHourValues[weekday]![hour]!.add(value);
      });
    });

    // Calculate averages for each weekday and hour
    final Map<int, Map<int, double>> weekdayHourAverages = {};

    weekdayHourValues.forEach((weekday, hourValues) {
      weekdayHourAverages[weekday] = {};

      hourValues.forEach((hour, values) {
        if (values.isNotEmpty) {
          final average = values.reduce((a, b) => a + b) / values.length;
          weekdayHourAverages[weekday]![hour] = average;
        } else {
          weekdayHourAverages[weekday]![hour] = 0.0; // Default value
        }
      });
    });

    return WeeklyPattern(
      name: patternName,
      hourlyPatterns: weekdayHourAverages,
      lastUpdated: DateTime.now(),
    );
  }

  // Detect common meal times from keyword data
  static Map<String, List<TimeOfDay>> detectMealTimes(List<KeywordData> keywordData) {
    // Keywords related to meals in Bengali
    final Map<String, String> mealKeywords = {
      'breakfast': 'নাস্তা', // "nasta" (breakfast)
      'lunch': 'দুপুরের খাবার', // "dupurer khabar" (lunch)
      'dinner': 'রাতের খাবার', // "rater khabar" (dinner)
    };

    // Initialize result map
    final Map<String, List<TimeOfDay>> mealTimes = {
      'breakfast': [],
      'lunch': [],
      'dinner': [],
    };

    // Check each keyword data for meal keywords
    for (final data in keywordData) {
      final timestamp = data.timestamp;

      mealKeywords.forEach((mealType, keyword) {
        // Check if the keyword or related words are in the data
        if (data.keywords.containsKey(keyword) ||
            _containsRelatedWord(data, keyword)) {
          mealTimes[mealType]!.add(TimeOfDay(
            hour: timestamp.hour,
            minute: timestamp.minute,
          ));
        }
      });
    }

    // Process meal times to find patterns
    final Map<String, List<TimeOfDay>> commonMealTimes = {};

    mealTimes.forEach((meal, times) {
      if (times.isNotEmpty) {
        // Group times by hour
        final Map<int, int> hourFrequency = {};

        for (final time in times) {
          final hour = time.hour;
          hourFrequency[hour] = (hourFrequency[hour] ?? 0) + 1;
        }

        // Find most common hour
        int mostCommonHour = -1;
        int maxFrequency = 0;

        hourFrequency.forEach((hour, frequency) {
          if (frequency > maxFrequency) {
            maxFrequency = frequency;
            mostCommonHour = hour;
          }
        });

        // Calculate average minute within most common hour
        if (mostCommonHour >= 0) {
          final List<int> minutes = [];

          for (final time in times) {
            if (time.hour == mostCommonHour) {
              minutes.add(time.minute);
            }
          }

          final averageMinute = minutes.isNotEmpty
              ? (minutes.reduce((a, b) => a + b) / minutes.length).round()
              : 0;

          commonMealTimes[meal] = [
            TimeOfDay(hour: mostCommonHour, minute: averageMinute),
          ];
        }
      }
    });

    return commonMealTimes;
  }

  // Helper method to check if data contains words related to a keyword
  static bool _containsRelatedWord(KeywordData data, String keyword) {
    // Check if the keyword is in any of the related keywords lists
    for (final relatedList in data.relatedKeywords.values) {
      if (relatedList.contains(keyword)) {
        return true;
      }
    }

    // Check if the keyword is in any context list
    for (final contextList in data.contexts.values) {
      if (contextList.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  // Detect when a break might be needed based on activity data
  static List<TimeOfDay> detectBreakTimes(List<ActivityData> activityData) {
    if (activityData.length < 12) return []; // Need at least 1 hour of data

    final List<TimeOfDay> suggestedBreakTimes = [];

    // Analyze continuous high activity periods
    int consecutiveHighActivity = 0;
    ActivityData? lastHighActivityData;

    for (int i = 0; i < activityData.length; i++) {
      final data = activityData[i];

      if (data.movementCount > 50) { // High activity threshold
        consecutiveHighActivity++;
        lastHighActivityData = data;
      } else {
        // If we had at least 60 minutes of high activity followed by low activity,
        // this might be a good break time pattern
        if (consecutiveHighActivity >= 12 && lastHighActivityData != null) {
          suggestedBreakTimes.add(TimeOfDay(
            hour: data.timestamp.hour,
            minute: data.timestamp.minute,
          ));
        }

        consecutiveHighActivity = 0;
        lastHighActivityData = null;
      }
    }

    return suggestedBreakTimes;
  }
}