import 'dart:convert';
import 'package:http/http.dart' as http;

class PublicParkingService {
  final String apiUrl;
  PublicParkingService(this.apiUrl);

  Future<List<Map<String, dynamic>>> fetchPublicParkings() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // 실제 데이터 구조에 맞게 파싱
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    } else {
      throw Exception('Failed to load public parking data');
    }
  }
}
