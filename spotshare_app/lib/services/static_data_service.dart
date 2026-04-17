import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/parking_spot.dart';

class StaticDataService {
  static const String _lastUpdateKey = 'static_data_last_update';
  // Note: Replace with your actual GitHub Pages URL after deployment
  static const String _defaultUrl = 'https://chenghun1234-dotcom.github.io/SPOTSHARE/parking_data.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/static_parking_data.json');
  }

  /// Fetches data from GitHub and caches it locally.
  /// If skipDownload is true, it only returns cached data if available.
  Future<List<ParkingSpot>> loadStaticSpots({bool forceRefresh = false}) async {
    final file = await _localFile;
    
    if (!forceRefresh && await file.exists()) {
      debugPrint('Loading static data from local cache');
      return _parseJson(await file.readAsString());
    }

    try {
      debugPrint('Fetching static data from GitHub: $_defaultUrl');
      final response = await http.get(Uri.parse(_defaultUrl)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final content = response.body;
        await file.writeAsString(content);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
        
        return _parseJson(content);
      } else {
        debugPrint('Failed to fetch from GitHub (Status: ${response.statusCode}). Using cache if exists.');
      }
    } catch (e) {
      debugPrint('Error fetching static data: $e');
    }

    if (await file.exists()) {
      return _parseJson(await file.readAsString());
    }
    
    return [];
  }

  List<ParkingSpot> _parseJson(String jsonString) {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> spotsJson = data['spots'] ?? [];
      
      return spotsJson.map((s) {
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
        );
      }).toList();
    } catch (e) {
      debugPrint('Error parsing static JSON: $e');
      return [];
    }
  }
}
