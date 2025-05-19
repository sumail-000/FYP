import 'package:flutter/material.dart';
import '../model/badge_model.dart' as models;

class ProfileBadgeOverlay extends StatelessWidget {
  final models.Badge badge;
  final double avatarSize;
  
  const ProfileBadgeOverlay({
    Key? key,
    required this.badge,
    required this.avatarSize,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!badge.isEarned) {
      return SizedBox.shrink();
    }
    
    final badgeSize = avatarSize * 0.35; // Size relative to avatar
    
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              badge.color.withOpacity(0.9),
              badge.color.withOpacity(0.7),
            ],
          ),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            badge.icon,
            color: Colors.white,
            size: badgeSize * 0.6,
          ),
        ),
      ),
    );
  }
} 