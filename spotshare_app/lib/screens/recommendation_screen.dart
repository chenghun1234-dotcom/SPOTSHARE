import 'package:flutter/material.dart';
import '../services/statistics_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({Key? key}) : super(key: key);

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<Map<String, dynamic>> topSpots = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final stats = StatisticsService();
    final spots = await stats.getTopSpots(limit: 5);
    setState(() {
      topSpots = spots;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('추천 주차장')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: topSpots.length,
              itemBuilder: (context, idx) {
                final spot = topSpots[idx];
                return ListTile(
                  leading: Icon(Icons.local_parking, color: Colors.blue),
                  title: Text(spot['title'] ?? ''),
                  subtitle: Text(spot['address'] ?? ''),
                  trailing: Text('${spot['price']}원'),
                );
              },
            ),
    );
  }
}
