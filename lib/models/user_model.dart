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
  });

  // Convert a UserModel into a Map. The keys must correspond to the names of the
  // fields in Firestore.
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
    };
  }

  // Create a UserModel from a Firestore document.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      email: json['email'],
      username: json['username'],
      profileImageUrl: json['profileImageUrl'],
      dob: json['dob'] != null ? (json['dob'] as Timestamp).toDate() : null,
      gender: json['gender'],
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      contactNo: json['contactNo'],
      stepGoal: (json['stepGoal'] as num?)?.toInt(),
      todaysStepCount: (json['todaysStepCount'] as num?)?.toInt(),
    );
  }
}

