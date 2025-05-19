import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityType {
  static const String profileCompletion = 'profile_completion';
  static const String universityEmail = 'university_email_verification';
  static const String firstLogin = 'first_login';
  static const String resourceUpload = 'resource_upload';
  static const String dailyLogin = 'daily_login';
  static const String connections = 'connections';
  static const String custom = 'custom_activity';
}

class ActivityPointsModel {
  final String userId;
  final Map<String, bool> oneTimeActivities;
  final Map<String, Timestamp> lastActivityTimestamps;
  final int totalPoints;
  final int currentStreak;
  final int maxStreak;
  final Timestamp? lastLoginDate;
  
  ActivityPointsModel({
    required this.userId,
    required this.oneTimeActivities,
    required this.lastActivityTimestamps,
    required this.totalPoints,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.lastLoginDate,
  });
  
  factory ActivityPointsModel.initial(String userId) {
    return ActivityPointsModel(
      userId: userId,
      oneTimeActivities: {
        ActivityType.profileCompletion: false,
        ActivityType.universityEmail: false,
        ActivityType.firstLogin: false,
      },
      lastActivityTimestamps: {},
      totalPoints: 0,
      currentStreak: 0,
      maxStreak: 0,
      lastLoginDate: null,
    );
  }
  
  factory ActivityPointsModel.fromMap(Map<String, dynamic> map, String userId) {
    Map<String, bool> oneTimeActivities = {};
    if (map['oneTimeActivities'] != null) {
      map['oneTimeActivities'].forEach((key, value) {
        oneTimeActivities[key] = value;
      });
    }
    
    Map<String, Timestamp> lastActivityTimestamps = {};
    if (map['lastActivityTimestamps'] != null) {
      map['lastActivityTimestamps'].forEach((key, value) {
        if (value is Timestamp) {
          lastActivityTimestamps[key] = value;
        }
      });
    }
    
    return ActivityPointsModel(
      userId: userId,
      oneTimeActivities: oneTimeActivities,
      lastActivityTimestamps: lastActivityTimestamps,
      totalPoints: map['totalPoints'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      maxStreak: map['maxStreak'] ?? 0,
      lastLoginDate: map['lastLoginDate'],
    );
  }
  
  factory ActivityPointsModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ActivityPointsModel.fromMap(data, doc.id);
  }
  
  Map<String, dynamic> toMap() {
    return {
      'oneTimeActivities': oneTimeActivities,
      'lastActivityTimestamps': lastActivityTimestamps,
      'totalPoints': totalPoints,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'lastLoginDate': lastLoginDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  ActivityPointsModel copyWith({
    String? userId,
    Map<String, bool>? oneTimeActivities,
    Map<String, Timestamp>? lastActivityTimestamps,
    int? totalPoints,
    int? currentStreak,
    int? maxStreak,
    Timestamp? lastLoginDate,
  }) {
    return ActivityPointsModel(
      userId: userId ?? this.userId,
      oneTimeActivities: oneTimeActivities ?? this.oneTimeActivities,
      lastActivityTimestamps: lastActivityTimestamps ?? this.lastActivityTimestamps,
      totalPoints: totalPoints ?? this.totalPoints,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    );
  }
  
  // Add points for one-time activity
  ActivityPointsModel addOneTimeActivity(String activityType, int points) {
    if (oneTimeActivities.containsKey(activityType) && 
        oneTimeActivities[activityType] == false) {
      
      Map<String, bool> updatedActivities = Map.from(oneTimeActivities);
      updatedActivities[activityType] = true;
      
      Map<String, Timestamp> updatedTimestamps = Map.from(lastActivityTimestamps);
      updatedTimestamps[activityType] = Timestamp.now();
      
      return copyWith(
        oneTimeActivities: updatedActivities,
        lastActivityTimestamps: updatedTimestamps,
        totalPoints: totalPoints + points,
      );
    }
    
    return this;
  }
  
  // Add points for recurring activities like resource uploads
  ActivityPointsModel addActivityPoints(String activityType, int points) {
    // Update timestamp for this activity
    Map<String, Timestamp> updatedTimestamps = Map.from(lastActivityTimestamps);
    updatedTimestamps[activityType] = Timestamp.now();
    
    // Add points to total
    return copyWith(
      lastActivityTimestamps: updatedTimestamps,
      totalPoints: totalPoints + points,
    );
  }
  
  // Track daily login streak and award points
  ActivityPointsModel trackDailyLogin(int points) {
    final now = Timestamp.now();
    final today = DateTime(now.toDate().year, now.toDate().month, now.toDate().day);
    
    // If no previous login, this is the first one
    if (lastLoginDate == null) {
      Map<String, Timestamp> updatedTimestamps = Map.from(lastActivityTimestamps);
      updatedTimestamps[ActivityType.dailyLogin] = now;
      
      return copyWith(
        lastActivityTimestamps: updatedTimestamps,
        totalPoints: totalPoints + points,
        currentStreak: 1,
        maxStreak: 1,
        lastLoginDate: now,
      );
    }
    
    // Get the date of the last login
    final lastLogin = lastLoginDate!.toDate();
    final lastLoginDay = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
    
    // Calculate the difference in days
    final difference = today.difference(lastLoginDay).inDays;
    
    // If already logged in today, don't add points again
    if (difference == 0) {
      return this;
    }
    
    Map<String, Timestamp> updatedTimestamps = Map.from(lastActivityTimestamps);
    updatedTimestamps[ActivityType.dailyLogin] = now;
    
    // If logged in yesterday, increase streak
    if (difference == 1) {
      final newStreak = currentStreak + 1;
      final newMaxStreak = newStreak > maxStreak ? newStreak : maxStreak;
      
      return copyWith(
        lastActivityTimestamps: updatedTimestamps,
        totalPoints: totalPoints + points,
        currentStreak: newStreak,
        maxStreak: newMaxStreak,
        lastLoginDate: now,
      );
    }
    
    // If missed a day or more, reset streak
    return copyWith(
      lastActivityTimestamps: updatedTimestamps,
      totalPoints: totalPoints + points,
      currentStreak: 1,
      lastLoginDate: now,
    );
  }
} 