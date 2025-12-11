import 'package:flutter/material.dart';

/// Represents a single app permission requirement
class AppPermission {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  bool isGranted;
  final bool isRequired;

  AppPermission({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.isGranted = false,
    this.isRequired = true,
  });

  /// Create a copy of this permission with updated fields
  AppPermission copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    Color? iconColor,
    bool? isGranted,
    bool? isRequired,
  }) {
    return AppPermission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      isGranted: isGranted ?? this.isGranted,
      isRequired: isRequired ?? this.isRequired,
    );
  }
}
