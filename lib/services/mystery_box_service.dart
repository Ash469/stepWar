// ignore_for_file: unused_import

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class MysteryBoxService {
  final String _baseUrl = "http://stepwars.ap-south-1.elasticbeanstalk.com/api";

  Future<Map<String, dynamic>> openMysteryBox(
      String userId, String boxType) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/mystery-box/open'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'boxType': boxType,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return responseBody['reward'];
      } else {
        // If the server responded with an error, throw an exception with the message
        throw Exception(responseBody['error'] ?? 'Failed to open mystery box.');
      }
    } catch (e) {
      // Handle network errors or other exceptions
      print("Error in openMysteryBox (Flutter): $e");
      rethrow; // Re-throw the exception to be caught by the UI
    }
  }
}
