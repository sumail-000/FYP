import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BadgeType {
  newcomer,
  participant,
  contributor,
  influencer,
  academicLeader,
}

class Badge {
  final String id;
  final BadgeType type;
  final String name;
  final String description;
  final Color color;
  final IconData icon;
  final int pointsRequired;
  final Timestamp? earnedAt;
  
  const Badge({
    required this.id,
    required this.type,
    required this.name, 
    required this.description,
    required this.color,
    required this.icon,
    required this.pointsRequired,
    this.earnedAt,
  });
  
  // Check if the badge is earned
  bool get isEarned => earnedAt != null;
  
  // Factory method to create a Badge object from Firestore document
  factory Badge.fromFirestore(Map<String, dynamic> data, String id) {
    return Badge(
      id: id,
      type: _stringToBadgeType(data['type'] ?? 'newcomer'),
      name: data['name'] ?? 'Unknown Badge',
      description: data['description'] ?? '',
      color: _stringToColor(data['color'] ?? '#2D6DA8'),
      icon: _stringToIcon(data['icon'] ?? 'emoji_events'),
      pointsRequired: data['pointsRequired'] ?? 0,
      earnedAt: data['earnedAt'],
    );
  }
  
  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'name': name,
      'description': description,
      'color': _colorToString(color),
      'icon': _iconToString(icon),
      'pointsRequired': pointsRequired,
      'earnedAt': earnedAt,
    };
  }
  
  // Create a copy with specific fields updated
  Badge copyWith({
    String? id,
    BadgeType? type,
    String? name,
    String? description,
    Color? color,
    IconData? icon,
    int? pointsRequired,
    Timestamp? earnedAt,
    bool? clearEarnedAt,
  }) {
    return Badge(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      earnedAt: clearEarnedAt == true ? null : (earnedAt ?? this.earnedAt),
    );
  }
  
  // Get all available badges with default configurations
  static List<Badge> getDefaultBadges() {
    return [
      Badge(
        id: 'newcomer',
        type: BadgeType.newcomer,
        name: 'Newcomer',
        description: 'Joined Academia Hub and started your academic journey.',
        color: Colors.green,
        icon: Icons.emoji_people,
        pointsRequired: 0,
      ),
      Badge(
        id: 'participant',
        type: BadgeType.participant,
        name: 'Participant',
        description: 'Actively participating in the academic community.',
        color: Colors.blue,
        icon: Icons.groups,
        pointsRequired: 150,
      ),
      Badge(
        id: 'contributor',
        type: BadgeType.contributor,
        name: 'Contributor',
        description: 'Regularly sharing valuable academic resources.',
        color: Colors.purple,
        icon: Icons.upload_file,
        pointsRequired: 500,
      ),
      Badge(
        id: 'influencer',
        type: BadgeType.influencer,
        name: 'Influencer',
        description: 'Your contributions are making a significant impact.',
        color: Colors.orange,
        icon: Icons.trending_up,
        pointsRequired: 1000,
      ),
      Badge(
        id: 'academicLeader',
        type: BadgeType.academicLeader,
        name: 'Academic Leader',
        description: 'A top contributor recognized for exceptional dedication.',
        color: Colors.red,
        icon: Icons.workspace_premium,
        pointsRequired: 2000,
      ),
    ];
  }
  
  // Helper methods to convert between types and strings
  static BadgeType _stringToBadgeType(String type) {
    switch (type.toLowerCase()) {
      case 'newcomer': return BadgeType.newcomer;
      case 'participant': return BadgeType.participant;
      case 'contributor': return BadgeType.contributor;
      case 'influencer': return BadgeType.influencer;
      case 'academicleader': return BadgeType.academicLeader;
      default: return BadgeType.newcomer;
    }
  }
  
  static Color _stringToColor(String colorString) {
    if (colorString.startsWith('#')) {
      try {
        return Color(int.parse('FF${colorString.substring(1)}', radix: 16));
      } catch (e) {
        return Colors.blue;
      }
    }
    return Colors.blue;
  }
  
  static String _colorToString(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }
  
  static IconData _stringToIcon(String iconName) {
    switch (iconName) {
      case 'emoji_people': return Icons.emoji_people;
      case 'groups': return Icons.groups;
      case 'upload_file': return Icons.upload_file;
      case 'trending_up': return Icons.trending_up;
      case 'workspace_premium': return Icons.workspace_premium;
      default: return Icons.emoji_events;
    }
  }
  
  static String _iconToString(IconData icon) {
    if (icon == Icons.emoji_people) return 'emoji_people';
    if (icon == Icons.groups) return 'groups';
    if (icon == Icons.upload_file) return 'upload_file';
    if (icon == Icons.trending_up) return 'trending_up';
    if (icon == Icons.workspace_premium) return 'workspace_premium';
    return 'emoji_events';
  }
} 