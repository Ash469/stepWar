import 'package:firebase_remote_config/firebase_remote_config.dart';

// const String baseUrl = 'http://10.106.238.52:5000';
const String baseUrl = 'http://3.109.141.189:5000';

// Get backend URL from Remote Config with fallback
String getBackendUrl() {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    final url = remoteConfig.getString('backend_url');
    return url.isNotEmpty ? url : baseUrl;
  } catch (e) {
    return baseUrl;
  }
  // return baseUrl;
}
const String KO_diff = "200";
const String Draw = "50";
const String Battle_Time = "10";
const String Multiplier_1_5x = "150";
const String Multiplier_2x = "200";
const String Multiplier_3x = "300";
const String KO_bonous = "5000";
const String Draw_bonous = "1000";
const String Bronze_box = "1000";
const String Silver_box = "5000";
const String Gold_box = "10000";
const String Debounce_duration = "15";

