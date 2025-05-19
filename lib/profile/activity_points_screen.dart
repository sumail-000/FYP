import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/activity_points_model.dart';
import '../services/activity_points_service.dart';

class ActivityPointsScreen extends StatelessWidget {
  final ActivityPointsModel? activityPoints;
  final bool isLoading;
  
  const ActivityPointsScreen({
    Key? key,
    required this.activityPoints,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activity Points',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: blueColor,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: orangeColor))
          : _buildBody(context, orangeColor),
    );
  }
  
  Widget _buildBody(BuildContext context, Color orangeColor) {
    if (activityPoints == null) {
      return Center(
        child: Text(
          'No activity points data found',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }
    
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total points card
            _buildTotalPointsCard(orangeColor),
            
            SizedBox(height: 24),
            
            // One-time activities section
            Text(
              'One-time Activities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF125F9D),
              ),
            ),
            SizedBox(height: 16),
            _buildActivityItem(
              'Profile Completion', 
              ActivityPointsService.PROFILE_COMPLETION_POINTS, 
              activityPoints!.oneTimeActivities[ActivityType.profileCompletion] ?? false,
              Icons.person_outline,
              'Complete your profile with your name and university details.',
            ),
            _buildActivityItem(
              'University Email Verification', 
              ActivityPointsService.UNIVERSITY_EMAIL_POINTS, 
              activityPoints!.oneTimeActivities[ActivityType.universityEmail] ?? false,
              Icons.email_outlined,
              'Sign up or login with a verified university email address.',
            ),
            _buildActivityItem(
              'First Login', 
              ActivityPointsService.FIRST_LOGIN_POINTS, 
              activityPoints!.oneTimeActivities[ActivityType.firstLogin] ?? false,
              Icons.login_outlined,
              'Log in to the Academia Hub app for the first time.',
            ),
            
            SizedBox(height: 24),
            
            // Active Recurring Activities section
            Text(
              'Active Recurring Activities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF125F9D),
              ),
            ),
            SizedBox(height: 16),
            
            // Daily Login Streak - show if user has an active streak
            if (activityPoints!.currentStreak > 0)
              _buildActiveStreakCard(
                'Daily Login Streak',
                ActivityPointsService.DAILY_LOGIN_POINTS,
                Icons.local_fire_department,
                'You\'ve logged in for ${activityPoints!.currentStreak} consecutive ${activityPoints!.currentStreak == 1 ? "day" : "days"}! Keep your streak going.',
                activityPoints!.currentStreak,
                activityPoints!.maxStreak,
                orangeColor
              ),
            
            // Resource uploads - only show in Active if user has already uploaded
            if (activityPoints!.lastActivityTimestamps.containsKey(ActivityType.resourceUpload))
              _buildRecurringActivityItem(
                'Resource Upload',
                ActivityPointsService.RESOURCE_UPLOAD_POINTS,
                true,
                Icons.upload_file,
                'Earn ${ActivityPointsService.RESOURCE_UPLOAD_POINTS} points for each document you upload.',
                activityPoints!.lastActivityTimestamps[ActivityType.resourceUpload],
              ),
            
            // Connections - show in Active if user has made connections (to be implemented)
            // This is a placeholder for future connection activity tracking
            // if (activityPoints!.lastActivityTimestamps.containsKey('connections'))
            //   _buildRecurringActivityItem(
            //     'Adding Connections',
            //     5, // 5 points per connection
            //     true,
            //     Icons.people_outline,
            //     'Earn 5 points for each new connection you make with other users.',
            //     activityPoints!.lastActivityTimestamps['connections'],
            //   ),
            
            SizedBox(height: 24),
            
            // Future opportunities section
            Text(
              'Upcoming Point Opportunities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF125F9D),
              ),
            ),
            SizedBox(height: 16),
            
            // Only show Daily Login in upcoming if user doesn't have an active streak
            if (activityPoints!.currentStreak == 0)
              _buildFutureOpportunityCard(
                'Daily Login',
                ActivityPointsService.DAILY_LOGIN_POINTS,
                Icons.calendar_today,
                'Earn points by logging in daily to stay connected with your academic community.',
                orangeColor,
              ),
            
            // Resource Upload - show in upcoming only if user hasn't uploaded yet
            if (!activityPoints!.lastActivityTimestamps.containsKey(ActivityType.resourceUpload))
              _buildFutureOpportunityCard(
                'Resource Upload',
                ActivityPointsService.RESOURCE_UPLOAD_POINTS,
                Icons.upload_file,
                'Earn points by uploading study materials and documents to help others.',
                orangeColor,
              ),
            
            // Adding connections opportunity - Move to Active Recurring when implemented
            // Only show in upcoming if user hasn't made any connections yet
            // This needs to be updated when connections feature is implemented
            if (!activityPoints!.lastActivityTimestamps.containsKey('connections'))
              _buildFutureOpportunityCard(
                'Adding Connections',
                5, // 5 points per connection
                Icons.people_outline,
                'Earn points by connecting with other users in the Academia Hub community.',
                orangeColor,
              ),
            
            // You can add more upcoming opportunities here
          ],
        ),
      ),
    );
  }
  
  Widget _buildTotalPointsCard(Color orangeColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [orangeColor, orangeColor.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.star,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Total Points',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${activityPoints?.totalPoints ?? 0}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            // Show streak information if user has a streak
            if (activityPoints != null && activityPoints!.currentStreak > 0) ...[
              SizedBox(height: 16),
              Divider(
                color: Colors.white.withOpacity(0.2),
                thickness: 1,
                height: 1,
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Current Streak: ${activityPoints!.currentStreak} ${activityPoints!.currentStreak == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (activityPoints!.maxStreak > activityPoints!.currentStreak) ...[
                SizedBox(height: 4),
                Text(
                  'Best: ${activityPoints!.maxStreak} days',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityItem(String title, int points, bool completed, IconData icon, String description) {
    final Color primaryColor = Color(0xFF2D6DA8); // Blue color from app's theme
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: completed ? Colors.white : Colors.grey[50],
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: completed ? Colors.green.withOpacity(0.1) : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        completed ? Icons.check_circle : icon,
                        color: completed ? Colors.green : Colors.grey[500],
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: completed ? Colors.black87 : Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: completed ? Colors.grey[600] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: completed ? Colors.green.withOpacity(0.1) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+$points',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: completed ? Colors.green : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // "Not Completed" indicator for incomplete activities
          if (!completed)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'Not Completed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFutureOpportunityCard(
    String title, 
    int points, 
    IconData icon, 
    String description,
    Color color
  ) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+$points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringActivityItem(
    String title, 
    int points, 
    bool hasActivity, 
    IconData icon, 
    String description,
    Timestamp? lastActivity
  ) {
    // Format the last activity time if available
    String lastActivityText = '';
    if (lastActivity != null) {
      // Convert timestamp to local date time
      final dateTime = lastActivity.toDate().toLocal();
      // Format as "Last upload: Feb 24, 2023"
      lastActivityText = 'Last upload: ${dateTime.day} ${_getMonthName(dateTime.month)}, ${dateTime.year}';
    }
    
    final Color orangeColor = Color(0xFFf06517); // Orange color from app's theme
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasActivity ? orangeColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: hasActivity ? orangeColor : Colors.grey,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (lastActivityText.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          lastActivityText,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: orangeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+$points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: orangeColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveStreakCard(
    String title, 
    int points, 
    IconData icon, 
    String description,
    int currentStreak,
    int maxStreak,
    Color color
  ) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '+$points',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '/day',
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 10),
            
            // Streak meter
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Current streak section
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '$currentStreak ${currentStreak == 1 ? "day" : "days"}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  
                  // Best streak section - only show if different from current
                  if (maxStreak > currentStreak)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Best: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '$maxStreak days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to get month name from month number
  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
} 