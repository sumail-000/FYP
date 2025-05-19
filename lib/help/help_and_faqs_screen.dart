import 'package:flutter/material.dart';

class HelpAndFaqsScreen extends StatefulWidget {
  const HelpAndFaqsScreen({Key? key}) : super(key: key);

  @override
  _HelpAndFaqsScreenState createState() => _HelpAndFaqsScreenState();
}

class _HelpAndFaqsScreenState extends State<HelpAndFaqsScreen> {
  // List of FAQ items with questions and answers
  final List<Map<String, String>> _faqItems = [
    {
      'question': 'How do I upload a document?',
      'answer': 'To upload a document, go to the Dashboard screen and tap on the "+" button. Select "Upload Document" from the menu, then choose a file from your device. Fill in the document details like title, course, and description, then tap "Upload".'
    },
    {
      'question': 'How do I earn activity points?',
      'answer': 'You can earn activity points by completing various actions in the app, such as uploading documents, connecting with other users, completing your profile, verifying your university email, logging in daily, and receiving positive ratings on your shared resources.'
    },
    {
      'question': 'What are badges and how do I earn them?',
      'answer': 'Badges are achievements that showcase your contributions and participation. They are earned automatically as you accumulate activity points. Different badges are awarded at various point thresholds, such as Bronze (20 points), Silver (50 points), Gold (100 points), etc.'
    },
    {
      'question': 'How do I connect with other users?',
      'answer': 'You can connect with other users by visiting their profile and tapping the "Connect" button. You can find users through document contributions, the chat room, or by searching for them. Once they accept your connection request, you\'ll be added to each other\'s connections list.'
    },
    {
      'question': 'How do I change my profile information?',
      'answer': 'To update your profile information, go to your Profile screen and tap on "Edit Bio". You can change your bio from there. Note that your name cannot be changed after account creation to maintain consistency across the platform.'
    },
    {
      'question': 'How do I change my password?',
      'answer': 'To change your password, go to your Profile screen and tap on "Change Password". Enter your current password followed by your new password, then confirm the new password and tap "Update Password".'
    },
    {
      'question': 'What happens if I forget my password?',
      'answer': 'If you forget your password, tap on "Forgot Password" on the login screen or in the Change Password section. Enter your email address, and we\'ll send you a link to reset your password.'
    },
    {
      'question': 'How do I delete my account?',
      'answer': 'Currently, account deletion is not available through the app interface. Please contact our support team at support@academiahub.com to request account deletion.'
    },
    {
      'question': 'Is my data secure?',
      'answer': 'Yes, we take data security seriously. All data is encrypted and stored securely in Firebase. Personal information is only shared with other users according to your privacy settings. We never share your data with third parties without your explicit consent.'
    },
    {
      'question': 'How can I report inappropriate content?',
      'answer': 'If you encounter inappropriate content, you can report it by tapping the "..." menu on the content and selecting "Report". Provide details about why you\'re reporting it, and our moderation team will review it promptly.'
    },
  ];

  // Track expanded FAQ items
  List<bool> _expandedItems = [];

  @override
  void initState() {
    super.initState();
    // Initialize all FAQs as collapsed
    _expandedItems = List.generate(_faqItems.length, (index) => false);
  }

  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & FAQs',
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
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Help section header
              _buildSectionHeader('Need Help?', blueColor, orangeColor),
              SizedBox(height: 16),
              
              // Contact support card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: blueColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.email_outlined,
                            color: blueColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contact Support',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Reach out to our team for personalized assistance',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      'Email us at:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.mail, size: 18, color: orangeColor),
                        SizedBox(width: 8),
                        Text(
                          'support@academiahub.com',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: blueColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Response time: Usually within 24 hours',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // FAQ section header
              _buildSectionHeader('Frequently Asked Questions', blueColor, orangeColor),
              SizedBox(height: 16),
              
              // FAQ items
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _faqItems.length,
                itemBuilder: (context, index) {
                  return _buildFaqItem(
                    question: _faqItems[index]['question']!,
                    answer: _faqItems[index]['answer']!,
                    isExpanded: _expandedItems[index],
                    onTap: () {
                      setState(() {
                        _expandedItems[index] = !_expandedItems[index];
                      });
                    },
                    blueColor: blueColor,
                    orangeColor: orangeColor,
                  );
                },
              ),
              
              SizedBox(height: 30),
              
              // Help topics section
              _buildSectionHeader('Help Topics', blueColor, orangeColor),
              SizedBox(height: 16),
              
              // Help topic cards
              _buildHelpTopicCard(
                title: 'Getting Started',
                description: 'Learn the basics of using Academia Hub',
                icon: Icons.play_circle_outline,
                color: blueColor,
              ),
              
              SizedBox(height: 12),
              
              _buildHelpTopicCard(
                title: 'Document Management',
                description: 'How to upload, organize, and share documents',
                icon: Icons.folder_outlined,
                color: blueColor,
              ),
              
              SizedBox(height: 12),
              
              _buildHelpTopicCard(
                title: 'Activity Points & Badges',
                description: 'Understanding the rewards system',
                icon: Icons.emoji_events_outlined,
                color: blueColor,
              ),
              
              SizedBox(height: 12),
              
              _buildHelpTopicCard(
                title: 'Account Settings',
                description: 'Managing your profile and preferences',
                icon: Icons.settings_outlined,
                color: blueColor,
              ),
              
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, Color primaryColor, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFaqItem({
    required String question,
    required String answer,
    required bool isExpanded,
    required VoidCallback onTap,
    required Color blueColor,
    required Color orangeColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isExpanded ? blueColor.withOpacity(0.3) : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question row with toggle icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: orangeColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: blueColor,
                      size: 24,
                    ),
                  ],
                ),
                
                // Answer (only visible when expanded)
                if (isExpanded) ...[
                  SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey[300]),
                  SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      answer,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHelpTopicCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Show topic details in a future version
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title content coming soon')),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
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
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 