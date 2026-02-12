import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String? email;
  final String? username;
  final String? profileImageUrl;
  final DateTime? dob;
  final String? gender;
  final double? weight;
  final double? height;
  final String? contactNo;
  final int? stepGoal;
  final int? todaysStepCount;
  final int? coins;
  final Map<String, dynamic>? multipliers;
  final Map<String, dynamic>? rewards;
  final Map<String, dynamic>? stats;
  final Map<String, String>? mysteryBoxLastOpened; 
  final List<String>? interestAreas;
  final String? avgDailySteps;

  UserModel({
    required this.userId,
    this.email,
    this.username,
    this.profileImageUrl,
    this.dob,
    this.gender,
    this.weight,
    this.height,
    this.contactNo,
    this.stepGoal,
    this.todaysStepCount,
    this.coins,
    this.multipliers,
    this.rewards,
    this.stats,
    this.mysteryBoxLastOpened, 
    this.interestAreas,
    this.avgDailySteps,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'gender': gender,
      'weight': weight,
      'height': height,
      'contactNo': contactNo,
      'stepGoal': stepGoal,
      'todaysStepCount': todaysStepCount,
      'coins': coins,
      'multipliers': multipliers,
      'rewards': rewards,
      'stats': stats,
      'mysteryBoxLastOpened': mysteryBoxLastOpened, 
      'interestAreas': interestAreas,
      'avgDailySteps': avgDailySteps,
    };
  }

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    if (dateValue is String) {
      return DateTime.tryParse(dateValue);
    }
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['uid'] ?? json['userId'] ?? '',
      email: json['email'],
      username: json['username'],
      profileImageUrl: json['profileImageUrl'],
      dob: _parseDate(json['dob']),
      gender: json['gender'],
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      contactNo: json['contactNo'],
      stepGoal: (json['stepGoal'] as num?)?.toInt(),
      todaysStepCount: (json['todaysStepCount'] as num?)?.toInt(),
      coins: (json['coins'] as num?)?.toInt(),
      multipliers: json['multipliers'] as Map<String, dynamic>?,
      rewards: json['rewards'] as Map<String, dynamic>?,
      stats: json['stats'] as Map<String, dynamic>?,
      // --- NEW --- Safely parse the map from JSON
      mysteryBoxLastOpened: (json['mysteryBoxLastOpened'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value.toString())),
      interestAreas: (json['interestAreas'] as List<dynamic>?)?.cast<String>(),
      avgDailySteps: json['avgDailySteps'] as String?,
    );
  }

  UserModel copyWith({
    String? userId,
    String? email,
    String? username,
    String? profileImageUrl,
    DateTime? dob,
    String? gender,
    double? weight,
    double? height,
    String? contactNo,
    int? stepGoal,
    int? todaysStepCount,
    int? coins,
    Map<String, dynamic>? multipliers,
    Map<String, dynamic>? rewards,
    Map<String, dynamic>? stats,
    Map<String, String>? mysteryBoxLastOpened,
    List<String>? interestAreas,
    String? avgDailySteps,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      contactNo: contactNo ?? this.contactNo,
      stepGoal: stepGoal ?? this.stepGoal,
      todaysStepCount: todaysStepCount ?? this.todaysStepCount,
      coins: coins ?? this.coins,
      multipliers: multipliers ?? this.multipliers,
      rewards: rewards ?? this.rewards,
      stats: stats ?? this.stats,
      mysteryBoxLastOpened: mysteryBoxLastOpened ?? this.mysteryBoxLastOpened,
      interestAreas: interestAreas ?? this.interestAreas,
      avgDailySteps: avgDailySteps ?? this.avgDailySteps,
    );
  }
}