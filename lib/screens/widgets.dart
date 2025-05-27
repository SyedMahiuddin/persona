// lib/widgets/activity_chart.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/activity_tracker.dart';
import '../models/activity_data.dart';

class ActivityChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activityTracker = Provider.of<ActivityTracker>(context);
    final activityHistory = activityTracker.activityHistory;

    if (activityHistory.isEmpty) {
      return Center(
        child: Text('Not enough activity data yet.'),
      );
    }

    // Get last 24 data points or all if less than 24
    final dataPoints = activityHistory.length > 24
        ? activityHistory.sublist(activityHistory.length - 24)
        : activityHistory;

    // Prepare data for the chart
    final List<FlSpot> spots = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final data = dataPoints[i];

      // Normalize movement count to a 0-10 scale
      final normalizedValue = data.movementCount / 10.0;
      spots.add(FlSpot(i.toDouble(), normalizedValue.clamp(0, 10)));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTextStyles: (context, value) => const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
            getTitles: (value) {
              if (value.toInt() % 4 == 0 && value.toInt() < dataPoints.length) {
                final data = dataPoints[value.toInt()];
                return '${data.timestamp.hour}:${data.timestamp.minute.toString().padLeft(2, '0')}';
              }
              return '';
            },
          ),
          leftTitles: SideTitles(
            showTitles: true,
            getTextStyles: (context, value) => const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
            getTitles: (value) {
              if (value % 2 == 0) {
                return value.toInt().toString();
              }
              return '';
            },
            reservedSize: 28,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black, width: 1),
        ),
        minX: 0,
        maxX: dataPoints.length.toDouble() - 1,
        minY: 0,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            colors: [Theme.of(context).primaryColor],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// lib/widgets/insight_card.dart
import 'package:flutter/material.dart';
import '../services/insights_service.dart';

class InsightCard extends StatelessWidget {
  final Insight insight;

  const InsightCard({
    Key? key,
    required this.insight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIcon(),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildPriorityIndicator(),
              ],
            ),
            SizedBox(height: 8),
            Text(insight.description),
            SizedBox(height: 8),
            Text(
              _formatTimestamp(insight.timestamp),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (insight.type) {
      case InsightType.activity:
        icon = Icons.directions_run;
        color = Colors.blue;
        break;
      case InsightType.keywords:
        icon = Icons.topic;
        color = Colors.purple;
        break;
      case InsightType.routine:
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case InsightType.actionItem:
        icon = Icons.assignment;
        color = Colors.red;
        break;
      case InsightType.breakSuggestion:
        icon = Icons.free_breakfast;
        color = Colors.green;
        break;
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildPriorityIndicator() {
    Color color;

    switch (insight.priority) {
      case InsightPriority.low:
        color = Colors.green;
        break;
      case InsightPriority.medium:
        color = Colors.orange;
        break;
      case InsightPriority.high:
        color = Colors.red;
        break;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute(s) ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour(s) ago';
    } else {
      return '${difference.inDays} day(s) ago';
    }
  }
}

// lib/widgets/status_indicator.dart
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const StatusIndicator({
    Key? key,
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/widgets/keyword_cloud.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/keyword_data.dart';

class KeywordCloud extends StatefulWidget {
  final int maxKeywords;

  const KeywordCloud({
    Key? key,
    this.maxKeywords = 30,
  }) : super(key: key);

  @override
  _KeywordCloudState createState() => _KeywordCloudState();
}

class _KeywordCloudState extends State<KeywordCloud> {
  List<KeywordItem> _keywordItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    final storageService = Provider.of<StorageService>(context, listen: false);

    // Load keyword history
    final keywordHistory = await storageService.loadKeywordHistory();

    if (keywordHistory.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Aggregate keywords from all history
    final Map<String, int> allKeywords = {};

    for (final data in keywordHistory) {
      data.keywords.forEach((keyword, count) {
        allKeywords[keyword] = (allKeywords[keyword] ?? 0) + count;
      });
    }

    // Sort by frequency
    final sortedKeywords = allKeywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate font sizes based on frequency
    final maxCount = sortedKeywords.isNotEmpty
        ? sortedKeywords.first.value
        : 1;

    final items = sortedKeywords
        .take(widget.maxKeywords)
        .map((entry) {
      // Scale font size between 12 and 24 based on frequency
      final fontSize = 12 + (entry.value / maxCount) * 12;

      return KeywordItem(
        text: entry.key,
        count: entry.value,
        fontSize: fontSize,
      );
    })
        .toList();

    setState(() {
      _keywordItems = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_keywordItems.isEmpty) {
      return Center(
        child: Text('No keywords detected yet.'),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _keywordItems.map((item) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            item.text,
            style: TextStyle(
              fontSize: item.fontSize,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class KeywordItem {
  final String text;
  final int count;
  final double fontSize;

  KeywordItem({
    required this.text,
    required this.count,
    required this.fontSize,
  });
}

// lib/widgets/daily_pattern_chart.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/pattern_detection.dart';
import '../models/user_profile.dart';

class DailyPatternChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context);
    final dailyPatterns = userProfile.dailyPatterns;

    if (dailyPatterns.isEmpty || !dailyPatterns.containsKey('activity')) {
      return Center(
        child: Text('Not enough data to show patterns yet.'),
      );
    }

    final activityPattern = dailyPatterns['activity']!;
    final hourlyValues = activityPattern.hourlyValues;

    // Prepare data for the chart
    final List<FlSpot> spots = [];

    for (int hour = 0; hour < 24; hour++) {
      if (hourlyValues.containsKey(hour)) {
        spots.add(FlSpot(hour.toDouble(), hourlyValues[hour]! * 10));
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTextStyles: (context, value) => const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
            getTitles: (value) {
              final hour = value.toInt();
              if (hour % 4 == 0) {
                return '$hour:00';
              }
              return '';
            },
          ),
          leftTitles: SideTitles(
            showTitles: true,
            getTextStyles: (context, value) => const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
            getTitles: (value) {
              if (value % 2 == 0) {
                return (value / 10).toString();
              }
              return '';
            },
            reservedSize: 28,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black, width: 1),
        ),
        minX: 0,
        maxX: 23,
        minY: 0,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            colors: [Colors.purple],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              colors: [
                Colors.purple.withOpacity(0.3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}