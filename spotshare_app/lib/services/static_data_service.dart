import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import '../models/parking_spot.dart';

class StaticDataService {
  static const String _dbName = 'spotshare_static.db';
  static const String _versionUrl = 'https://spotshare-5103d.web.app/version.json';
  static const String _dataUrl = 'https://spotshare-5103d.web.app/parking_data.json';
  
  // Sembast stores
  final _metadataStore = stringMapStoreFactory.store('metadata');
  final _spotsStore = intMapStoreFactory.store('spots');

  Future<Database> _openDb() async {
    final factory = databaseFactoryWeb;
    return await factory.openDatabase(_dbName);
  }

  /// 메인 로딩 함수: 버전 체크 후 필요할 때만 다운로드
  Future<List<ParkingSpot>> loadStaticSpots({bool forceRefresh = false}) async {
    final db = await _openDb();
    
    try {
      // 1. 서버의 최신 버전 정보(JSON)만 살짝 가져옴 (트래픽 최소화)
      debugPrint('Checking static data version...');
      final vResponse = await http.get(Uri.parse(_versionUrl)).timeout(const Duration(seconds: 5));
      
      if (vResponse.statusCode == 200) {
        final serverVersion = json.decode(vResponse.body);
        final serverUpdatedAt = serverVersion['updatedAt'] as String;
        
        // 2. 로컬에 저장된 마지막 업데이트 시간 확인
        final localMeta = await _metadataStore.record('last_update').get(db);
        final localUpdatedAt = localMeta?['updatedAt'] as String?;

        // 3. 변경사항이 있거나 강제 새로고침인 경우만 다운로드
        if (forceRefresh || localUpdatedAt != serverUpdatedAt) {
          debugPrint('Update found! Downloading full dataset (6MB)...');
          return await _downloadAndCache(db, serverUpdatedAt);
        } else {
          debugPrint('No update needed. Loading from IndexedDB.');
          return await _loadFromDb(db);
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e. Falling back to local cache.');
    }

    // 서버 연결 실패 시 로컬 데이터 반환
    return await _loadFromDb(db);
  }

  /// 백그라운드에서 데이터를 받고 DB에 저장
  Future<List<ParkingSpot>> _downloadAndCache(Database db, String updatedAt) async {
    final response = await http.get(Uri.parse(_dataUrl)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return [];

    // 대용량 연산은 메인 쓰레드를 방해하지 않도록 compute 활용
    final List<ParkingSpot> spots = await compute(_parseAndMapJson, response.body);

    if (spots.isNotEmpty) {
      // 기존 데이터 삭제 후 일괄 저장 (Transaction)
      await db.transaction((txn) async {
        await _spotsStore.delete(txn);
        final List<Map<String, dynamic>> maps = spots.map((s) => _modelToMap(s)).toList();
        await _spotsStore.addAll(txn, maps);
        await _metadataStore.record('last_update').put(txn, {'updatedAt': updatedAt});
      });
      debugPrint('Successfully cached ${spots.length} spots to IndexedDB.');
    }
    
    return spots;
  }

  /// 로컬 DB에서 데이터 읽기
  Future<List<ParkingSpot>> _loadFromDb(Database db) async {
    final snapshots = await _spotsStore.find(db);
    if (snapshots.isEmpty) return [];
    
    debugPrint('Fetched ${snapshots.length} spots from local IndexedDB.');
    return snapshots.map((s) => _mapToModel(s.value)).toList();
  }

  // --- Helper Methods (Isolate-safe parsing) ---

  static List<ParkingSpot> _parseAndMapJson(String jsonString) {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> spotsJson = data['spots'] ?? [];
      
      return spotsJson.map<ParkingSpot>((s) {
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
      return [];
    }
  }

  static Map<String, dynamic> _modelToMap(ParkingSpot s) {
    return {
      'id': s.id,
      'title': s.title,
      'address': s.address,
      'lat': s.lat,
      'lng': s.lng,
      'type': s.type,
      'price': s.price,
    };
  }

  static ParkingSpot _mapToModel(Map<String, dynamic> m) {
    return ParkingSpot(
      id: m['id'],
      title: m['title'],
      address: m['address'],
      lat: m['lat'],
      lng: m['lng'],
      type: m['type'] ?? 'PUBLIC',
      price: m['price'] ?? 0,
      region: m['type'] ?? 'PUBLIC',
      priceUnit: '시간',
      penaltyRate: 0,
      bank: '',
      accountNo: '',
      depositCode: '',
      isPremium: false,
      imageUrl: '',
      isActive: true,
    );
  }
}
