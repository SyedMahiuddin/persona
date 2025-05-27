// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:persona/screens/widgets.dart';
import 'package:provider/provider.dart';
import '../activity_track.dart';
import '../audio.dart';
import '../insight_serviece.dart';
import '../model/model.dart';
import '../services/audio_service.dart';
import '../services/activity_tracker.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../serviec_storage.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _continuousListening = true;
  bool _recordMovement = true;
  bool _showNotifications = true;
  bool _exportingData = false;

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          // General Settings
          _buildSectionHeader('General Settings'),

          SwitchListTile(
            title: Text('Continuous Listening'),
            subtitle: Text('Allow Persona to continuously listen to your microphone'),
            value: _continuousListening,
            onChanged: (value) {
              setState(() {
                _continuousListening = value;
              });

              final audioService = Provider.of<AudioService>(context, listen: false);

              if (value) {
                audioService.startListening();
              } else {
                audioService.stopListening();
              }
            },
          ),

          SwitchListTile(
            title: Text('Record Movement'),
            subtitle: Text('Allow Persona to track your activity levels'),
            value: _recordMovement,
            onChanged: (value) {
              setState(() {
                _recordMovement = value;
              });

              final activityTracker = Provider.of<ActivityTracker>(context, listen: false);

              if (value) {
                activityTracker.startTracking();
              } else {
                activityTracker.stopTracking();
              }
            },
          ),

          SwitchListTile(
            title: Text('Show Notifications'),
            subtitle: Text('Receive notifications for important insights'),
            value: _showNotifications,
            onChanged: (value) {
              setState(() {
                _showNotifications = value;
              });

              // TODO: Implement notification settings
            },
          ),

          // Language Settings
          _buildSectionHeader('Language Settings'),

          Consumer<UserProfile>(
            builder: (context, userProfile, child) {
              return ListTile(
                title: Text('Bengali Language Percentage'),
                subtitle: Slider(
                  value: userProfile.bengaliPercentage.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${userProfile.bengaliPercentage}%',
                  onChanged: (value) {
                    userProfile.updateLanguageStats(value.round());
                  },
                ),
                trailing: Text('${userProfile.bengaliPercentage}%'),
              );
            },
          ),

          // Data Management
          _buildSectionHeader('Data Management'),

          ListTile(
            title: Text('Export Data'),
            subtitle: Text('Save your Persona data to a file'),
            trailing: _exportingData
                ? CircularProgressIndicator()
                : Icon(Icons.download),
            onTap: _exportingData
                ? null
                : () async {
              setState(() {
                _exportingData = true;
              });

              try {
                final exportFile = await storageService.exportAllData();

                // Share file
                await Share.shareFiles(
                  [exportFile.path],
                  text: 'Persona Data Export',
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error exporting data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _exportingData = false;
                });
              }
            },
          ),

          ListTile(
            title: Text('Import Data'),
            subtitle: Text('Load Persona data from a file'),
            trailing: Icon(Icons.upload),
            onTap: () async {
              try {
                // Pick a file
                final result = await FilePicker.platform.pickFiles();

                if (result != null) {
                  final file = File(result.files.single.path!);
                  final jsonString = await file.readAsString();

                  // Import data
                  await storageService.importData(jsonString);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Data imported successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error importing data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),

          ListTile(
            title: Text('Clear All Data'),
            subtitle: Text('Delete all your saved Persona data'),
            trailing: Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Clear All Data?'),
                  content: Text(
                      'This will delete all your saved data and patterns. ' +
                          'This action cannot be undone.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();

                        try {
                          await storageService.clearAllData();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('All data cleared successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error clearing data: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text('Clear Data'),
                    ),
                  ],
                ),
              );
            },
          ),

          // About
          _buildSectionHeader('About'),

          ListTile(
            title: Text('Persona'),
            subtitle: Text('Version 1.0.0'),
            trailing: Icon(Icons.info_outline),
          ),

          ListTile(
            title: Text('Privacy Policy'),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              // Show privacy policy dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Privacy Policy'),
                  content: SingleChildScrollView(
                    child: Text(
                        'Persona App Privacy Policy\n\n' +
                            'Your data stays on your device. Persona does not transmit your audio or activity data to any server. ' +
                            'All processing happens locally on your device using offline ML models.\n\n' +
                            'Microphone access is used only to detect keywords and patterns in your speech, ' +
                            'primarily to assist you based on your activity patterns.\n\n' +
                            'You can export your data at any time and clear all data from the app if you wish.'
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}



class InsightsScreen extends StatefulWidget {
  @override
  _InsightsScreenState createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final insightsService = Provider.of<InsightsService>(context);
    final allInsights = insightsService.currentInsights;

    // Apply filter if selected
    final List<Insight> filteredInsights = _selectedFilter != null
        ? allInsights.where((insight) => insight.type == _selectedFilter).toList()
        : allInsights;

    return Scaffold(
      appBar: AppBar(
        title: Text('Insights'),
        actions: [
          PopupMenuButton<InsightType?>(
            icon: Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() {
                _selectedFilter = type;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text('All Insights'),
              ),
              PopupMenuItem(
                value: InsightType.activity,
                child: Text('Activity'),
              ),
              PopupMenuItem(
                value: InsightType.keywords,
                child: Text('Keywords'),
              ),
              PopupMenuItem(
                value: InsightType.routine,
                child: Text('Routines'),
              ),
              PopupMenuItem(
                value: InsightType.actionItem,
                child: Text('Action Items'),
              ),
              PopupMenuItem(
                value: InsightType.breakSuggestion,
                child: Text('Break Suggestions'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter chip row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(null, 'All'),
                  SizedBox(width: 8),
                  _buildFilterChip(InsightType.activity, 'Activity'),
                  SizedBox(width: 8),
                  _buildFilterChip(InsightType.keywords, 'Keywords'),
                  SizedBox(width: 8),
                  _buildFilterChip(InsightType.routine, 'Routines'),
                  SizedBox(width: 8),
                  _buildFilterChip(InsightType.actionItem, 'Action Items'),
                  SizedBox(width: 8),
                  _buildFilterChip(InsightType.breakSuggestion, 'Breaks'),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Insights count
            Text(
              '${filteredInsights.length} Insights',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),

            SizedBox(height: 8),

            // Insights list
            Expanded(
              child: filteredInsights.isEmpty
                  ? Center(
                child: Text(
                  _selectedFilter != null
                      ? 'No ${_insightTypeToString(_selectedFilter!)} insights available.'
                      : 'No insights available yet.',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: filteredInsights.length,
                itemBuilder: (context, index) {
                  return InsightCard(
                    insight: filteredInsights[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(InsightType? type, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == type,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
      },
    );
  }

  String _insightTypeToString(InsightType type) {
    switch (type) {
      case InsightType.activity:
        return 'activity';
      case InsightType.keywords:
        return 'keyword';
      case InsightType.routine:
        return 'routine';
      case InsightType.actionItem:
        return 'action item';
      case InsightType.breakSuggestion:
        return 'break suggestion';
    }
  }
}