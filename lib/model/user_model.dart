import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, teacher, undefined }

class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? university;
  final UserRole role;
  final bool isProfileComplete;
  
  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.university,
    this.role = UserRole.undefined,
    this.isProfileComplete = false,
  });
  
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    UserRole parseRole(String? roleStr) {
      if (roleStr == null) return UserRole.undefined;
      switch (roleStr) {
        case 'student': return UserRole.student;
        case 'teacher': return UserRole.teacher;
        default: return UserRole.undefined;
      }
    }
    
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      name: map['name'],
      university: map['university'],
      role: parseRole(map['role']),
      isProfileComplete: map['isProfileComplete'] ?? false,
    );
  }
  
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }
  
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'university': university,
      'role': role.toString().split('.').last,
      'isProfileComplete': isProfileComplete,
    };
  }
  
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? university,
    UserRole? role,
    bool? isProfileComplete,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      university: university ?? this.university,
      role: role ?? this.role,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }
} 