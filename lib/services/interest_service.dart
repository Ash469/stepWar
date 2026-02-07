import 'dart:convert';
import 'package:http/http.dart' as http;
import '../const/string.dart';

class InterestService {
  String get _baseUrl => '${getBackendUrl()}/api';

  Future<List<String>> fetchInterests() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/interests'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List interests = data['interests'];
          return interests.map<String>((i) => i['name'] as String).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching interests: $e');
      return [];
    }
  }
}
