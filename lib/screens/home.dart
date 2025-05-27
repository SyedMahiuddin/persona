// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/audio_service.dart';
import '../services/activity_tracker.dart';
import '../services/insights_service.dart';
import '../widgets/activity_chart.dart';
import '../widgets/insight_card.dart';
import '../widgets/status_indicator.dart';
import 'settings_screen.dart';
import 'insights_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isListening = false;
  bool _isTracking = false;
  List<Insight> _recentInsights = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start services when app launches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    final audioService = Provider.of<AudioService>(context, listen: false);
    final activityTracker = Provider.of<ActivityTracker>(context, listen: false);
    final insightsService = Provider.of<InsightsService>(context, listen: false);

    // Initialize audio service
    await audioService.initialize();

    // Start listening and tracking
    await audioService.startListening();
    await activityTracker.startTracking();

    setState(() {
      _isListening = true;
      _isTracking = true;
    });

    // Listen for new insights
    insightsService.insightsStream.listen((insights) {
      setState(() {
        // Filter to show only high priority insights on home screen
        _recentInsights = insights
            .where((insight) => insight.priority == InsightPriority.high)
            .toList();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audioService = Provider.of<AudioService>(context, listen: false);
    final activityTracker = Provider.of<ActivityTracker>(context, listen: false);

    if (state == AppLifecycleState.paused) {
      // App going to background
      audioService.stopListening();
      activityTracker.stopTracking();
      setState(() {
        _isListening = false;
        _isTracking = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      audioService.startListening();
      activityTracker.startTracking();
      setState(() {
        _isListening = true;
        _isTracking = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toggleListening() async {
    final audioService = Provider.of<AudioService>(context, listen: false);

    if (_isListening) {
      await audioService.stopListening();
    } else {
      await audioService.startListening();
    }

    setState(() {
      _isListening = !_isListening;
    });
  }

  void _toggleTracking() async {
    final activityTracker = Provider.of<ActivityTracker>(context, listen: false);

    if (_isTracking) {
      await activityTracker.stopTracking();
    } else {
      await activityTracker.startTracking();
    }

    setState(() {
      _isTracking = !_isTracking;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Persona'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StatusIndicator(
                    icon: Icons.mic,
                    label: 'Listening',
                    isActive: _isListening,
                    onTap: _toggleListening,
                  ),
                  StatusIndicator(
                    icon: Icons.directions_run,
                    label: 'Activity Tracking',
                    isActive: _isTracking,
                    onTap: _toggleTracking,
                  ),
                  StatusIndicator(
                    icon: Icons.translate,
                    label: 'Bengali: ${userProfile.bengaliPercentage}%',
                    isActive: true,
                    onTap: null,
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Activity chart
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 200,
                        child: ActivityChart(),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Recent insights
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => InsightsScreen()),
                          );
                        },
                        child: Text('See All'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_recentInsights.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No insights yet. Persona is still learning about your patterns.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _recentInsights
                          .take(3)
                          .map((insight) => InsightCard(insight: insight))
                          .toList(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => InsightsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnalyticsScreen()),
            );
          }
        },
      ),
    );
  }
}