import 'package:flutter/material.dart';
import '../model/badge_model.dart' as models;

class BadgeWidget extends StatelessWidget {
  final models.Badge badge;
  final double size;
  final bool showName;
  final bool showDescription;
  final bool showUnearned;
  final VoidCallback? onTap;

  const BadgeWidget({
    Key? key,
    required this.badge,
    this.size = 60.0,
    this.showName = false,
    this.showDescription = false,
    this.showUnearned = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If badge is not earned and we don't want to show unearned badges
    if (!badge.isEarned && !showUnearned) {
      return SizedBox.shrink();
    }
    
    final isEarned = badge.isEarned;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge icon with modern styling
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isEarned ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  badge.color.withOpacity(0.8),
                  badge.color.withOpacity(0.6),
                ],
              ) : null,
              color: isEarned ? null : Colors.grey[200],
              border: Border.all(
                color: isEarned ? badge.color : Colors.grey[400]!,
                width: 2,
              ),
              boxShadow: isEarned ? [
                BoxShadow(
                  color: badge.color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ] : null,
            ),
            child: Center(
              child: isEarned
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect
                      Icon(
                        badge.icon,
                        color: Colors.white.withOpacity(0.4),
                        size: size * 0.65,
                      ),
                      // Main icon
                      Icon(
                        badge.icon,
                        color: Colors.white,
                        size: size * 0.5,
                      ),
                    ],
                  )
                : Icon(
                    badge.icon,
                    color: Colors.grey[400],
                    size: size * 0.5,
                  ),
            ),
          ),
          
          // Badge name (optional)
          if (showName) ...[
            SizedBox(height: 6),
            Text(
              badge.name,
              style: TextStyle(
                color: isEarned ? Colors.black87 : Colors.grey[600],
                fontWeight: isEarned ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          // Badge description (optional)
          if (showDescription && isEarned) ...[
            SizedBox(height: 4),
            Container(
              constraints: BoxConstraints(maxWidth: size * 3),
              child: Text(
                badge.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          
          // Lock icon for unearned badges with improved styling
          if (!isEarned && showUnearned) ...[
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${badge.pointsRequired} pts',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Updated badge row with improved styling
class BadgesRow extends StatelessWidget {
  final List<models.Badge> badges;
  final double size;
  final bool showUnearned;
  final bool showName;
  final Function(models.Badge)? onBadgeTap;
  
  const BadgesRow({
    Key? key,
    required this.badges,
    this.size = 40.0,
    this.showUnearned = false,
    this.showName = false,
    this.onBadgeTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final earnedBadges = badges.where((badge) => badge.isEarned).toList();
    final unearnedBadges = badges.where((badge) => !badge.isEarned).toList();
    
    // Skip if no badges to show at all
    if (badges.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Badges',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 10),
          
          // Show placeholder when no earned badges and not showing unearned
          if (earnedBadges.isEmpty && !showUnearned)
            _buildNoBadgesMessage()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Show earned badges first with a nice shadow effect
                  ...earnedBadges.map((badge) => Container(
                    margin: const EdgeInsets.only(right: 15.0),
                    child: BadgeWidget(
                      badge: badge,
                      size: size,
                      showName: showName,
                      onTap: onBadgeTap != null ? () => onBadgeTap!(badge) : null,
                    ),
                  )),
                  
                  // Then show unearned badges if enabled
                  if (showUnearned) ...unearnedBadges.map((badge) => Container(
                    margin: const EdgeInsets.only(right: 15.0),
                    child: BadgeWidget(
                      badge: badge,
                      size: size,
                      showName: showName,
                      showUnearned: true,
                      onTap: onBadgeTap != null ? () => onBadgeTap!(badge) : null,
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  // Widget to show when user has no earned badges
  Widget _buildNoBadgesMessage() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: Colors.grey[400],
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No badges earned yet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Continue participating to earn badges',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced primary badge widget for profile display
class PrimaryBadgeWidget extends StatelessWidget {
  final models.Badge badge;
  final bool showName;
  final bool showLabel;
  final double size;
  
  const PrimaryBadgeWidget({
    Key? key,
    required this.badge,
    this.showName = true,
    this.showLabel = true,
    this.size = 28.0,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Only show earned badges
    if (!badge.isEarned) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badge.color.withOpacity(0.9),
            badge.color.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badge.color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge.icon,
            color: Colors.white,
            size: size,
          ),
          if (showLabel) ...[
            SizedBox(width: 6),
            Text(
              showName ? badge.name : 'Badge',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// New widget for displaying badge on profile avatar
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