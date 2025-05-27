// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../widgets/keyword_cloud.dart';
import '../widgets/daily_pattern_chart.dart';
import '../services/storage_service.dart';

class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Keywords'),
            Tab(text: 'Activity'),
            Tab(text: 'Patterns'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKeywordsTab(),
          _buildActivityTab(),
          _buildPatternsTab(),
        ],
      ),
    );
  }

  Widget _buildKeywordsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Detected Keywords',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: KeywordCloud(),
          ),
          SizedBox(height: 16),
          Text(
            'Language Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Consumer<UserProfile>(
            builder: (context, userProfile, child) {
              return Row(
                children: [
                  Expanded(
                    flex: userProfile.bengaliPercentage,
                    child: Container(
                      height: 24,
                      color: Colors.indigo,
                      alignment: Alignment.center,
                      child: Text(
                        'Bengali ${userProfile.bengaliPercentage}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 100 - userProfile.bengaliPercentage,
                    child: Container(
                      height: 24,
                      color: Colors.blue,
                      alignment: Alignment.center,
                      child: Text(
                        'Other ${100 - userProfile.bengaliPercentage}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    final storageService = Provider.of<StorageService>(context);

    return FutureBuilder<List<ActivityData>>(
      future: storageService.loadActivityHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No activity data available yet.'),
          );
        }

        final activityData = snapshot.data!;

        // Calculate activity statistics
        int totalMovement = 0;
        double avgMovementIntensity = 0;

        for (final data in activityData) {
          totalMovement += data.movementCount;
          avgMovementIntensity += data.movementIntensity;
        }

        if (activityData.isNotEmpty) {
          avgMovementIntensity /= activityData.length;
        }

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),

              // Activity stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Movement',
                      totalMovement.toString(),
                      Icons.directions_run,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Avg. Intensity',
                      avgMovementIntensity.toStringAsFixed(1),
                      Icons.speed,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              Text(
                'Daily Activity Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 16),

              // Group activity by hour
              _buildHourlyActivityChart(activityData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyActivityChart(List<ActivityData> activityData) {
    // Group activity data by hour
    final Map<int, List<ActivityData>> hourlyData = {};

    for (final data in activityData) {
      final hour = data.timestamp.hour;

      if (!hourlyData.containsKey(hour)) {
        hourlyData[hour] = [];
      }

      hourlyData[hour]!.add(data);
    }

    // Calculate average movement per hour
    final Map<int, double> hourlyAvgMovement = {};

    hourlyData.forEach((hour, dataList) {
      double totalMovement = 0;

      for (final data in dataList) {
        totalMovement += data.movementCount;
      }

      hourlyAvgMovement[hour] = totalMovement / dataList.length;
    });

    return Expanded(
      child: ListView.builder(
        itemCount: 24,
        itemBuilder: (context, index) {
          final hour = index;
          final avgMovement = hourlyAvgMovement[hour] ?? 0;

          return ListTile(
            leading: Text(
              '$hour:00',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            title: LinearProgressIndicator(
              value: avgMovement / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getActivityColor(avgMovement),
              ),
            ),
            trailing: Text(
              avgMovement.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getActivityColor(double value) {
    if (value < 20) {
      return Colors.blue;
    } else if (value < 50) {
      return Colors.green;
    } else if (value < 80) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildPatternsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Activity Pattern',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: DailyPatternChart(),
          ),
          SizedBox(height: 24),

          Text(
            'Detected Routines',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          Expanded(
            child: _buildRoutinesPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinesPanel() {
    return Consumer<UserProfile>(
      builder: (context, userProfile, child) {
        // Display meal times if available
        final breakfastTimes = userProfile.getMealTimes(MealType.breakfast);
        final lunchTimes = userProfile.getMealTimes(MealType.lunch);
        final dinnerTimes = userProfile.getMealTimes(MealType.dinner);

        if (breakfastTimes == null && lunchTimes == null && dinnerTimes == null) {
          return Center(
            child: Text('No routines detected yet.'),
          );
        }

        return ListView(
          children: [
            if (breakfastTimes != null && breakfastTimes.isNotEmpty)
              _buildRoutineItem(
                'Breakfast',
                'Usually around ${_formatTimeOfDay(breakfastTimes.first)}',
                Icons.free_breakfast,
                Colors.orange,
              ),

            if (lunchTimes != null && lunchTimes.isNotEmpty)
              _buildRoutineItem(
                'Lunch',
                'Usually around ${_formatTimeOfDay(lunchTimes.first)}',
                Icons.lunch_dining,
                Colors.green,
              ),

            if (dinnerTimes != null && dinnerTimes.isNotEmpty)
              _buildRoutineItem(
                'Dinner',
                'Usually around ${_formatTimeOfDay(dinnerTimes.first)}',
                Icons.dinner_dining,
                Colors.indigo,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRoutineItem(String title, String subtitle, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }
}

