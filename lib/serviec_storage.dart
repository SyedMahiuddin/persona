// lib/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'model/model.dart';

class StorageService {
  static const String _keywordHistoryKey = 'keyword_history';
  static const String _activityHistoryKey = 'activity_history';
  static const String _userProfileKey = 'user_profile';
  static const String _dailyPatternsKey = 'daily_patterns';
  static const String _weeklyPatternsKey = 'weekly_patterns';

  // Save keyword data to local storage
  Future<void> saveKeywordData(KeywordData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history = prefs.getStringList(_keywordHistoryKey) ?? [];

      // Add new data
      history.add(jsonEncode(data.toJson()));

      // Limit history size to avoid excessive storage
      if (history.length > 1000) {
        history.removeAt(0);
      }

      // Save back to storage
      await prefs.setStringList(_keywordHistoryKey, history);

    } catch (e) {
      print('Error saving keyword data: $e');
    }
  }

  // Load all keyword history
  Future<List<KeywordData>> loadKeywordHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history = prefs.getStringList(_keywordHistoryKey) ?? [];

      return history.map((jsonString) =>
          KeywordData.fromJson(jsonDecode(jsonString))).toList();

    } catch (e) {
      print('Error loading keyword history: $e');
      return [];
    }
  }

  // Save activity data to local storage
  Future<void> saveActivityData(ActivityData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history = prefs.getStringList(_activityHistoryKey) ?? [];

      // Add new data
      history.add(jsonEncode(data.toJson()));

      // Limit history size
      if (history.length > 1000) {
        history.removeAt(0);
      }

      // Save back to storage
      await prefs.setStringList(_activityHistoryKey, history);

    } catch (e) {
      print('Error saving activity data: $e');
    }
  }

  // Load all activity history
  Future<List<ActivityData>> loadActivityHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history = prefs.getStringList(_activityHistoryKey) ?? [];

      return history.map((jsonString) =>
          ActivityData.fromJson(jsonDecode(jsonString))).toList();

    } catch (e) {
      print('Error loading activity history: $e');
      return [];
    }
  }

  // Save user profile
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(profile.toJson());

      await prefs.setString(_userProfileKey, json);

    } catch (e) {
      print('Error saving user profile: $e');
    }
  }

  // Load user profile
  Future<UserProfile?> loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_userProfileKey);

      if (json != null) {
        return UserProfile.fromJson(jsonDecode(json));
      }

      return null;

    } catch (e) {
      print('Error loading user profile: $e');
      return null;
    }
  }

  // Save daily patterns to JSON files (using file system for larger data)
  Future<void> saveDailyPatterns(Map<DateTime, DailyPattern> patterns) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_dailyPatternsKey.json');

      // Convert DateTime keys to strings for JSON
      final jsonPatterns = {};
      patterns.forEach((date, pattern) {
        jsonPatterns[date.toIso8601String()] = pattern.toJson();
      });

      await file.writeAsString(jsonEncode(jsonPatterns));

    } catch (e) {
      print('Error saving daily patterns: $e');
    }
  }

  // Load daily patterns from JSON files
  Future<Map<DateTime, DailyPattern>> loadDailyPatterns() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_dailyPatternsKey.json');

      if (!await file.exists()) {
        return {};
      }

      final String jsonString = await file.readAsString();
      final jsonPatterns = jsonDecode(jsonString);

      // Convert string keys back to DateTime
      final Map<DateTime, DailyPattern> patterns = {};
      jsonPatterns.forEach((dateString, patternJson) {
        patterns[DateTime.parse(dateString)] = DailyPattern.fromJson(patternJson);
      });

      return patterns;

    } catch (e) {
      print('Error loading daily patterns: $e');
      return {};
    }
  }

  // Save weekly patterns
  Future<void> saveWeeklyPatterns(Map<String, WeeklyPattern> patterns) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_weeklyPatternsKey.json');

      final jsonPatterns = {};
      patterns.forEach((name, pattern) {
        jsonPatterns[name] = pattern.toJson();
      });

      await file.writeAsString(jsonEncode(jsonPatterns));

    } catch (e) {
      print('Error saving weekly patterns: $e');
    }
  }

  // Load weekly patterns
  Future<Map<String, WeeklyPattern>> loadWeeklyPatterns() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_weeklyPatternsKey.json');

      if (!await file.exists()) {
        return {};
      }

      final String jsonString = await file.readAsString();
      final jsonPatterns = jsonDecode(jsonString);

      final Map<String, WeeklyPattern> patterns = {};
      jsonPatterns.forEach((name, patternJson) {
        patterns[name] = WeeklyPattern.fromJson(patternJson);
      });

      return patterns;

    } catch (e) {
      print('Error loading weekly patterns: $e');
      return {};
    }
  }

  // Export all data for backup
  Future<File> exportAllData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportFile = File('${dir.path}/persona_data_export.json');

      // Gather all data
      final userData = {
        'keywordHistory': await loadKeywordHistory(),
        'activityHistory': await loadActivityHistory(),
        'userProfile': await loadUserProfile(),
        'dailyPatterns': await loadDailyPatterns(),
        'weeklyPatterns': await loadWeeklyPatterns(),
      };

      // Write to export file
      await exportFile.writeAsString(jsonEncode(userData));

      return exportFile;

    } catch (e) {
      print('Error exporting data: $e');
      throw Exception('Failed to export data: $e');
    }
  }

  // Import data from backup
  Future<void> importData(String jsonString) async {
    try {
      final userData = jsonDecode(jsonString);

      // First clear existing data
      await clearAllData();

      // Parse and save each data type
      if (userData.containsKey('keywordHistory')) {
        final keywordHistory = (userData['keywordHistory'] as List)
            .map((item) => KeywordData.fromJson(item))
            .toList();

        for (final data in keywordHistory) {
          await saveKeywordData(data);
        }
      }

      if (userData.containsKey('activityHistory')) {
        final activityHistory = (userData['activityHistory'] as List)
            .map((item) => ActivityData.fromJson(item))
            .toList();

        for (final data in activityHistory) {
          await saveActivityData(data);
        }
      }

      if (userData.containsKey('userProfile')) {
        final userProfile = UserProfile.fromJson(userData['userProfile']);
        await saveUserProfile(userProfile);
      }

      if (userData.containsKey('dailyPatterns')) {
        final Map<DateTime, DailyPattern> dailyPatterns = {};
        userData['dailyPatterns'].forEach((dateString, pattern) {
          dailyPatterns[DateTime.parse(dateString)] = DailyPattern.fromJson(pattern);
        });

        await saveDailyPatterns(dailyPatterns);
      }

      if (userData.containsKey('weeklyPatterns')) {
        final Map<String, WeeklyPattern> weeklyPatterns = {};
        userData['weeklyPatterns'].forEach((name, pattern) {
          weeklyPatterns[name] = WeeklyPattern.fromJson(pattern);
        });

        await saveWeeklyPatterns(weeklyPatterns);
      }

    } catch (e) {
      print('Error importing data: $e');
      throw Exception('Failed to import data: $e');
    }
  }

  // Clear all stored data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keywordHistoryKey);
      await prefs.remove(_activityHistoryKey);
      await prefs.remove(_userProfileKey);

      final dir = await getApplicationDocumentsDirectory();
      final dailyPatternsFile = File('${dir.path}/$_dailyPatternsKey.json');
      final weeklyPatternsFile = File('${dir.path}/$_weeklyPatternsKey.json');

      if (await dailyPatternsFile.exists()) {
        await dailyPatternsFile.delete();
      }

      if (await weeklyPatternsFile.exists()) {
        await weeklyPatternsFile.delete();
      }

    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}