import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/parking_spot.dart';

class StaticDataService {
  static const String _lastUpdateKey = 'static_data_last_update';
  static const String _cachedDataKey = 'static_data_cache';
  // Centralized Firebase-hosted data source
  static const String _defaultUrl = 'https://spotshare-5103d.web.app/parking_data.json';

  /// Fetches data from GitHub and caches it locally.
  Future<List<ParkingSpot>> loadStaticSpots({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check cache first
    if (!forceRefresh) {
      final cachedJson = prefs.getString(_cachedDataKey);
      if (cachedJson != null) {
        debugPrint('Loading static data from local cache (Web compatible)');
        return _parseJson(cachedJson);
      }
    }

    try {
      debugPrint('Fetching static data from GitHub: $_defaultUrl');
      final response = await http.get(Uri.parse(_defaultUrl)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final content = response.body;
        
        // Save to preferences (Web/Mobile compatible)
        await prefs.setString(_cachedDataKey, content);
        await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
        
        return _parseJson(content);
      } else {
        debugPrint('Failed to fetch from GitHub (Status: ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('Error fetching static data: $e');
    }

    // Final fallback to older cache
    final fallbackJson = prefs.getString(_cachedDataKey);
    if (fallbackJson != null) return _parseJson(fallbackJson);
    
    return [];
  }

  List<ParkingSpot> _parseJson(String jsonString) {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> spotsJson = data['spots'] ?? [];
      
      return spotsJson.map<ParkingSpot>((s) {
        // Map static format to ParkingSpot model
        return ParkingSpot(
          id: 'static_${s['title']}_${s['lat']}',
          title: s['title'] ?? 'Unknown',
          address: s['address'] ?? '',
          lat: (s['lat'] as num).toDouble(),
          lng: (s['lng'] as num).toDouble(),
          region: s['type'] ?? 'PUBLIC',
          isActive: true,
          isPremium: false,
          ownerId: 'STATIC_DATA',
          price: (s['fee'] is int) ? s['fee'] : 0,
          priceUnit: '시간',
          penaltyRate: 0,
          imageUrl: '',
          bank: '',
          accountNo: '',
          depositCode: '',
          type: s['type'] ?? 'PUBLIC',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error parsing static JSON: $e');
      return [];
    }
  }
}
