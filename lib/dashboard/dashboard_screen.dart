import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'dart:developer' as developer;
import 'dashboard_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/profile_screen.dart';
import '../chatroom/chatroom_screen.dart';
import '../services/presence_service.dart';
import '../chatbot/chatbot_screen.dart';
import '../services/activity_points_service.dart';
import 'display_style_helper.dart'; // Import the new helper

// Enum for document sort options
enum SortOption { newest, oldest, nameAZ, nameZA, fileSize, fileType }

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _profileImageUrl;
  int _selectedIndex = 0;
  bool _isStreakMessageShown = false;

  // Define the exact orange color
  final Color orangeColor = Color(0xFFf06517);

  // Define the exact blue color
  final Color blueColor = Color(0xFF2D6DA8);

  // Add these variables to track filtered documents
  List<Map<String, dynamic>> _allDocuments = [];
  List<Map<String, dynamic>> _filteredDocuments = [];
  bool _isFilterApplied = false;

  // Add these variables to the _DashboardScreenState class
  final List<String> _semesters = [
    'First',
    'Second',
    'Third',
    'Fourth',
    'Fifth',
    'Sixth',
    'Seventh',
    'Eighth',
  ];

  String? _selectedSemester;
  String? _selectedDepartment;
  String? _selectedSubject;
  String? _selectedCourseCode;

  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();

  List<String> _departments = [];
  List<String> _subjects = [];
  List<String> _courseCodes = [];

  // Add these variables for dropdown state management
  bool _showDepartmentDropdown = false;
  bool _showSubjectDropdown = false;
  bool _showCourseCodeDropdown = false;
  bool _showSemesterDropdown = false;

  // Add focus nodes for better control of input fields
  final FocusNode _departmentFocusNode = FocusNode();
  final FocusNode _subjectFocusNode = FocusNode();
  final FocusNode _courseCodeFocusNode = FocusNode();
  final FocusNode _semesterFocusNode = FocusNode();

  // Flag variables to prevent multiple simultaneous operations
  bool _isAddingDepartment = false;
  bool _isAddingSubject = false;
  bool _isAddingCourseCode = false;

  // Search related variables
  final TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchActive = false;

  // Sorting related variables
  SortOption _currentSortOption = SortOption.newest;
  bool _isSortActive = false;

  // Display style related variables
  DisplayStyle _currentDisplayStyle = DisplayStyle.grid;
  bool _isDisplayStyleChanged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    developer.log('DashboardScreen initialized', name: 'Dashboard');

    // Debug check for user university
    _getUserUniversity().then((university) {
      developer.log(
        'User university is: ${university ?? "NULL"}',
        name: 'Dashboard',
      );
    });

    // Load user profile image
    _loadUserProfileImage();

    // Update user presence
    _updatePresence(true);

    // Check and show streak notification if needed
    // Delay slightly to ensure dashboard is fully loaded
    Future.delayed(Duration(milliseconds: 800), () {
      _checkAndShowStreakNotification();
    });

    // Initialize filter data
    _initializeFilterData();

    // Add listeners to focus nodes
    _departmentFocusNode.addListener(() {
      if (!_departmentFocusNode.hasFocus) {
        _addNewDepartmentIfNeeded();
      }
      setState(() {});
    });

    _subjectFocusNode.addListener(() {
      if (!_subjectFocusNode.hasFocus) {
        _addNewSubjectIfNeeded();
      }
      setState(() {});
    });

    _courseCodeFocusNode.addListener(() {
      if (!_courseCodeFocusNode.hasFocus) {
        _addNewCourseCodeIfNeeded();
      }
      setState(() {});
    });

    _semesterFocusNode.addListener(() {
      setState(() {});
    });

    // Add search controller listener
    _searchController.addListener(_handleSearchChanged);

    // Add search focus node listener
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  // Handle search changes
  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _isSearchActive = _searchQuery.isNotEmpty;

      // If search is active, perform search and filter
      if (_isSearchActive) {
        _performSearch();
      } else if (_isFilterApplied) {
        // If only filters are applied, reapply them
        _applyFilters();
      }
    });
  }

  // Perform search on documents
  void _performSearch() {
    if (_searchQuery.isEmpty) {
      // If search query is empty but filters are active
      if (_isFilterApplied) {
        _applyFilters();
      } else {
        // Reset to show all documents
        setState(() {
          _isSearchActive = false;
          _filteredDocuments = [];
        });
      }
      return;
    }

    // Start with the correct document set - either all documents or filtered ones
    List<Map<String, dynamic>> baseDocuments =
        _isFilterApplied ? _filteredDocuments : _allDocuments;

    // Search fields in priority order
    List<Map<String, dynamic>> searchResults =
        baseDocuments.where((doc) {
          // Convert search query to lowercase for case-insensitive matching
          final query = _searchQuery.toLowerCase();

          // Primary fields (exact match gives higher relevance)
          if (doc['fileName'].toString().toLowerCase().contains(query) ||
              doc['courseCode'].toString().toLowerCase().contains(query) ||
              doc['course'].toString().toLowerCase().contains(query)) {
            return true;
          }

          // Secondary fields
          if (doc['department'].toString().toLowerCase().contains(query) ||
              doc['documentType'].toString().toLowerCase().contains(query) ||
              doc['semester'].toString().toLowerCase().contains(query) ||
              doc['uploaderName'].toString().toLowerCase().contains(query)) {
            return true;
          }

          // No match
          return false;
        }).toList();

    // Update state with search results
    setState(() {
      _isSearchActive = true;
      _filteredDocuments = searchResults;
    });

    // Log search results
    developer.log(
      'Search performed: "$_searchQuery" found ${searchResults.length} results out of ${baseDocuments.length} documents',
      name: 'Dashboard',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePresence(false);

    // Dispose of controllers and focus nodes
    _departmentController.dispose();
    _subjectController.dispose();
    _courseCodeController.dispose();
    _searchController.dispose();

    _departmentFocusNode.dispose();
    _subjectFocusNode.dispose();
    _courseCodeFocusNode.dispose();
    _semesterFocusNode.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updatePresence(false);
    }
  }

  // Update user presence status
  Future<void> _updatePresence(bool isOnline) async {
    await _presenceService.updatePresence(
      isOnline: isOnline,
      screen: 'dashboard',
    );
  }

  Future<void> _loadUserProfileImage() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // First check if profile exists in the profiles collection
        final profileDoc =
            await FirebaseFirestore.instance
                .collection('profiles')
                .doc(user.uid)
                .get();

        if (profileDoc.exists) {
          final profileData = profileDoc.data() as Map<String, dynamic>;
          if (profileData.containsKey('secureUrl') &&
              profileData['secureUrl'] != null) {
            setState(() {
              _profileImageUrl = profileData['secureUrl'];
            });
            developer.log(
              'Loaded profile image from profiles collection',
              name: 'Dashboard',
            );
            return; // Exit early if found in profiles collection
          }
        }

        // Fall back to user document if not found in profiles collection
        final userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          if (data.containsKey('profileImageUrl') &&
              data['profileImageUrl'] != null) {
            setState(() {
              _profileImageUrl = data['profileImageUrl'];
            });
            developer.log(
              'Loaded profile image from users collection',
              name: 'Dashboard',
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error loading profile image: $e', name: 'Dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building DashboardScreen', name: 'Dashboard');

    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final height = screenSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    developer.log('Screen size: ${width} x ${height}', name: 'Dashboard');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFE6E8EB),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF2D6DA8), // Updated to match blue in reference
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child:
                        _profileImageUrl != null
                            ? ClipOval(
                              child: Image.network(
                                _profileImageUrl!,
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    color: Color(0xFF2D6DA8),
                                    size: 40,
                                  );
                                },
                              ),
                            )
                            : Icon(
                              Icons.person,
                              color: Color(0xFF2D6DA8),
                              size: 40,
                            ),
                  ),
                  SizedBox(height: height * 0.01),
                  Text(
                    "${_authService.currentUser?.email?.split('@').first ?? 'User'}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: height * 0.022,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${_authService.currentUser?.email ?? ''}",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: height * 0.016,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 0;
                });
              },
            ),
            _buildDrawerItem(
              icon: Icons.people_outline,
              title: 'Friends',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/friends');
              },
              showUnreadCount: true,
            ),
            // Add Friend Requests option
            _buildDrawerItem(
              icon: Icons.person_add_alt_1,
              title: 'Friend Requests',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/friend_requests');
              },
              showUnreadCount: true,
            ),
            ListTile(
              leading: Icon(Icons.file_copy),
              title: Text('My Uploads'),
              onTap: () {
                Navigator.pop(context);
                DashboardService.navigateToMyUploadsScreen(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await _authService.signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: width,
            margin: EdgeInsets.only(
              bottom: height * 0.015,
              left: 0,
              right: 0,
              top: 0,
            ),
            padding: EdgeInsets.only(
              bottom: height * 0.02,
              top: statusBarHeight,
            ),
            decoration: BoxDecoration(
              color: Color(0xFF2D6DA8),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(width * 0.15),
                bottomRight: Radius.circular(width * 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Bar Section
                Padding(
                  padding: EdgeInsets.only(
                    top: height * 0.02,
                    left: width * 0.02,
                    right: width * 0.02,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Custom hamburger menu icon
                      Padding(
                        padding: EdgeInsets.only(left: width * 0.03),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _scaffoldKey.currentState!.openDrawer();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(width * 0.02),
                              width: width * 0.1,
                              height: width * 0.1,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: width * 0.07,
                                    height: 3,
                                    margin: EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  Container(
                                    width: width * 0.05,
                                    height: 3,
                                    margin: EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  Container(
                                    width: width * 0.07,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Profile icon
                      Padding(
                        padding: EdgeInsets.only(right: width * 0.03),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                            // Refresh profile image when returning from profile screen
                            _loadUserProfileImage();
                          },
                          child: Container(
                            width: width * 0.1,
                            height: width * 0.1,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child:
                                _profileImageUrl != null
                                    ? ClipOval(
                                      child: Image.network(
                                        _profileImageUrl!,
                                        fit: BoxFit.cover,
                                        width: width * 0.1,
                                        height: width * 0.1,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          developer.log(
                                            'Error loading profile image: $error',
                                            name: 'Dashboard',
                                          );
                                          return Icon(
                                            Icons.person,
                                            color: Color(0xFF2D6DA8),
                                            size: width * 0.06,
                                          );
                                        },
                                      ),
                                    )
                                    : Center(
                                      child: Icon(
                                        Icons.person,
                                        color: Color(0xFF2D6DA8),
                                        size: width * 0.06,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.07,
                    vertical: height * 0.03,
                  ),
                  child: Container(
                    height: height * 0.06,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(height * 0.03),
                      border: Border.all(
                        color:
                            _searchFocusNode.hasFocus ? blueColor : orangeColor,
                        width: _searchFocusNode.hasFocus ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.only(left: width * 0.0),
                          width: height * 0.06,
                          height: height * 0.07,
                          decoration: BoxDecoration(
                            color:
                                _searchFocusNode.hasFocus
                                    ? blueColor
                                    : orangeColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.search,
                              color: Colors.white,
                              size: height * 0.035,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.02,
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Search for resources',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                suffixIcon:
                                    _searchQuery.isNotEmpty
                                        ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.grey[500],
                                            size: 20,
                                          ),
                                          onPressed: _clearSearch,
                                        )
                                        : null,
                              ),
                              onSubmitted: (value) {
                                // Perform search when user presses enter
                                if (value.isNotEmpty) {
                                  _performSearch();
                                }
                              },
                            ),
                          ),
                        ),

                        Container(
                          margin: EdgeInsets.only(right: width * 0.04),
                          child: IconButton(
                            icon: Icon(
                              Icons.tune,
                              color: _isFilterApplied ? blueColor : orangeColor,
                              size: width * 0.07,
                            ),
                            onPressed: _showFilterDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMenuButton(
                        title: "Friends",
                        icon: Icons.people,
                        color: orangeColor,
                        onTap: () => Navigator.pushNamed(context, '/friends'),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Bot",
                        icon: Icons.smart_toy,
                        color: orangeColor,
                        onTap:
                            () => DashboardService.navigateToChatbotScreen(
                              context,
                            ),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Upload",
                        icon: Icons.cloud_upload,
                        color: orangeColor,
                        onTap:
                            () => DashboardService.navigateToUploadScreen(
                              context,
                            ),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "ChatRoom",
                        icon: Icons.chat_bubble,
                        color: orangeColor,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomScreen(),
                              ),
                            ),
                        width: width,
                        height: height,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: height * 0.025),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                // Filter options row
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.04,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left display style toggle button
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              DisplayStyleHelper.getToggleIcon(
                                _currentDisplayStyle,
                              ),
                              color:
                                  _isDisplayStyleChanged
                                      ? orangeColor
                                      : Colors.grey[700],
                            ),
                            onPressed: _toggleDisplayStyle,
                          ),
                          if (_isDisplayStyleChanged)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: orangeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Refresh button in center
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.grey[700]),
                        onPressed: () {
                          _refreshDocuments();
                        },
                      ),

                      // Right sort button with active indicator
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.sort,
                              color:
                                  _isSortActive ? blueColor : Colors.grey[700],
                            ),
                            onPressed: () {
                              _showSortOptions(context);
                            },
                          ),
                          if (_isSortActive)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Active display style indicator
                if (_isDisplayStyleChanged &&
                    _currentDisplayStyle == DisplayStyle.grid)
                  DisplayStyleHelper.buildDisplayStyleIndicator(
                    currentStyle: _currentDisplayStyle,
                    indicatorColor: orangeColor,
                    onClear: () {
                      setState(() {
                        _currentDisplayStyle = DisplayStyle.grid;
                        _isDisplayStyleChanged = false;
                      });
                    },
                  ),

                // Active sort indicator
                if (_isSortActive)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: blueColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: blueColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, color: blueColor, size: 14),
                        SizedBox(width: 4),
                        Text(
                          _getSortDescription(),
                          style: TextStyle(
                            fontSize: 12,
                            color: blueColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentSortOption = SortOption.newest;
                              _isSortActive = false;
                              // Re-apply filters and search if active
                              if (_isFilterApplied || _isSearchActive) {
                                _applyFiltersAndSearch();
                              }
                            });
                          },
                          child: Icon(Icons.close, color: blueColor, size: 14),
                        ),
                      ],
                    ),
                  ),

                // Recent documents grid
                Expanded(
                  child: Column(
                    children: [
                      // Active search indicator
                      if (_isSearchActive)
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: blueColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: blueColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: blueColor, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Search: "$_searchQuery"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _clearSearch,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: blueColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: blueColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Active filter indicator
                      if (_isFilterApplied)
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: orangeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: orangeColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.filter_list,
                                color: orangeColor,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getActiveFilterDescription(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _resetFilters();
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: orangeColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: orangeColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Document count indicator when filtered or searched
                      if (_isFilterApplied || _isSearchActive)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Found ${_filteredDocuments.length} ${_filteredDocuments.length == 1 ? 'document' : 'documents'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Document grid
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getRecentDocuments(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: orangeColor,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red[300],
                                      size: 56,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Failed to load documents',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final documents = snapshot.data ?? [];

                            // Show empty state if no documents or no filtered results
                            if (documents.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isSearchActive
                                          ? Icons.search_off
                                          : _isFilterApplied
                                          ? Icons.filter_list_off
                                          : Icons.folder_open,
                                      color: Colors.grey[400],
                                      size: 64,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      _isSearchActive
                                          ? 'No results for "$_searchQuery"'
                                          : _isFilterApplied
                                          ? 'No documents match your filters'
                                          : 'No documents yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _isSearchActive
                                          ? 'Try different search terms or browse all documents'
                                          : _isFilterApplied
                                          ? 'Try different filter criteria'
                                          : 'Try uploading some files',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    SizedBox(height: 24),
                                    if (_isSearchActive)
                                      ElevatedButton.icon(
                                        onPressed: _clearSearch,
                                        icon: Icon(Icons.clear_all),
                                        label: Text('Clear Search'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (_isFilterApplied)
                                      ElevatedButton.icon(
                                        onPressed: _resetFilters,
                                        icon: Icon(Icons.filter_list_off),
                                        label: Text('Clear Filters'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed:
                                            () =>
                                                DashboardService.navigateToUploadScreen(
                                                  context,
                                                ),
                                        icon: Icon(Icons.cloud_upload),
                                        label: Text('Upload Now'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: orangeColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            // Return either grid or list view based on display style
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.02,
                              ),
                              child:
                                  _currentDisplayStyle == DisplayStyle.grid
                                      ? DisplayStyleHelper.buildGridView(
                                        documents: documents,
                                        width: width,
                                        itemBuilder:
                                            (doc) => _buildDocumentCard(doc),
                                      )
                                      : DisplayStyleHelper.buildListView(
                                        documents: documents,
                                        width: width,
                                        itemBuilder:
                                            (doc) =>
                                                DisplayStyleHelper.buildDocumentListItem(
                                                  document: doc,
                                                  primaryColor: orangeColor,
                                                  secondaryColor: blueColor,
                                                  onTap:
                                                      () =>
                                                          _showDocumentDetails(
                                                            doc,
                                                          ),
                                                ),
                                      ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width * 0.16,
            height: width * 0.16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(width * 0.04),
            ),
            child: Icon(icon, color: Colors.white, size: width * 0.08),
          ),
          SizedBox(height: height * 0.01),
          Text(
            title,
            style: TextStyle(
              fontSize: width * 0.035,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Method to fetch recent documents
  Future<List<Map<String, dynamic>>> _getRecentDocuments() async {
    try {
      // If we already have documents loaded and just need to apply sorting/filtering
      if (_allDocuments.isNotEmpty) {
        developer.log(
          'Using cached documents instead of fetching again, with ${_isSortActive ? _getSortDescription() : "default"} sorting',
          name: 'Dashboard',
        );

        // Apply current sort if active
        if (_isSortActive) {
          List<Map<String, dynamic>> sortedResult = List.from(_allDocuments);
          _applyCurrentSort(sortedResult);

          // Return the appropriate list
          return (_isSearchActive || _isFilterApplied)
              ? _filteredDocuments
              : sortedResult;
        }

        // Return the appropriate list
        return (_isSearchActive || _isFilterApplied)
            ? _filteredDocuments
            : _allDocuments;
      }

      // First time loading - fetch from Firestore
      // First, get the current user's university
      String? userUniversity = await _getUserUniversity();

      if (userUniversity == null) {
        developer.log('User university not found', name: 'Dashboard');
        return [];
      }

      developer.log(
        'Fetching new documents for university: $userUniversity',
        name: 'Dashboard',
      );

      // Get reference to Firestore collection
      final documentsRef = FirebaseFirestore.instance.collection('documents');

      // Query for documents from the user's university, ordered by upload timestamp (most recent first)
      final snapshot =
          await documentsRef
              .where('university', isEqualTo: userUniversity)
              .orderBy('uploadedAt', descending: true)
              .limit(
                100,
              ) // Increased limit to have more documents for filtering
              .get();

      if (snapshot.docs.isEmpty) {
        developer.log(
          'No documents found for university: $userUniversity',
          name: 'Dashboard',
        );
        return [];
      }

      // Process query results into the format needed by the UI
      List<Map<String, dynamic>> result = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Extract file extension from fileName or secureUrl
        String extension = '';
        final fileName = data['fileName'] as String? ?? '';
        if (fileName.contains('.')) {
          extension = fileName.split('.').last.toLowerCase();
        } else if (data['secureUrl'] != null) {
          final url = data['secureUrl'] as String;
          if (url.contains('.')) {
            extension = url.split('.').last.toLowerCase();
          }
        }

        // Format relative time
        String timeAgo = 'Recently';
        if (data['uploadedAt'] != null) {
          final uploadTime = (data['uploadedAt'] as Timestamp).toDate();
          final now = DateTime.now();
          final difference = now.difference(uploadTime);

          // Ensure timestamp is properly stored for sorting
          Timestamp timestamp = data['uploadedAt'] as Timestamp;

          if (difference.inMinutes < 1) {
            timeAgo = 'Just now';
          } else if (difference.inHours < 1) {
            final minutes = difference.inMinutes;
            timeAgo = '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
          } else if (difference.inDays < 1) {
            final hours = difference.inHours;
            timeAgo = '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
          } else if (difference.inDays < 30) {
            final days = difference.inDays;
            timeAgo = '$days ${days == 1 ? 'day' : 'days'} ago';
          } else {
            // Format as date for older documents
            timeAgo = DateFormat('MMM d, yyyy').format(uploadTime);
          }
        }

        result.add({
          'id': doc.id,
          'fileName':
              data['displayName'] ?? data['fileName'] ?? 'Unnamed Document',
          'extension': extension,
          'course': data['course'] ?? '',
          'courseCode': data['courseCode'] ?? '',
          'department': data['department'] ?? '',
          'documentType': data['documentType'] ?? '',
          'semester': data['semester'] ?? '',
          'timeAgo': timeAgo,
          'fileUrl': data['secureUrl'] ?? '',
          'bytes': data['bytes'] ?? 0,
          'uploaderName': data['uploaderName'] ?? 'Anonymous',
          'uploaderId': data['uploaderId'] ?? '',
          'timestamp':
              data['uploadedAt']
                  as Timestamp, // Store original timestamp for better sorting
        });
      }

      // Store all documents for later filtering
      _allDocuments = result;

      // Apply current sort if it's active
      if (_isSortActive) {
        // Create a copy to avoid modifying the state during sorting
        List<Map<String, dynamic>> sortedResult = List.from(result);
        _applyCurrentSort(sortedResult);
        result = sortedResult;
      }

      // If search or filter is active, return filtered documents, otherwise return all
      return (_isSearchActive || _isFilterApplied)
          ? _filteredDocuments
          : result;
    } catch (e) {
      developer.log('Error fetching documents: $e', name: 'Dashboard');
      return [];
    }
  }

  // Helper method to get current user's university
  Future<String?> _getUserUniversity() async {
    try {
      if (_authService.currentUser == null) {
        return null;
      }

      // Get the user document
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.currentUser!.uid)
              .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['university'] as String?;
    } catch (e) {
      developer.log('Error getting user university: $e', name: 'Dashboard');
      return null;
    }
  }

  // Method to show sort options with enhanced UI
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle indicator
                  Container(
                    margin: EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: blueColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.sort, color: blueColor),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Sort Documents',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: blueColor,
                          ),
                        ),
                        Spacer(),
                        if (_isSortActive)
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                _currentSortOption = SortOption.newest;
                                _isSortActive = false;
                              });
                              _applySortOption(SortOption.newest);
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.refresh, size: 18),
                            label: Text('Reset'),
                            style: TextButton.styleFrom(
                              foregroundColor: blueColor,
                            ),
                          ),
                      ],
                    ),
                  ),

                  Divider(height: 1),

                  // Sort options list
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSortOption(
                            context: context,
                            title: 'Newest First',
                            icon: Icons.calendar_today,
                            subtitle: 'Most recently uploaded at the top',
                            option: SortOption.newest,
                            setModalState: setModalState,
                          ),
                          _buildSortOption(
                            context: context,
                            title: 'Oldest First',
                            icon: Icons.history,
                            subtitle: 'Oldest uploads at the top',
                            option: SortOption.oldest,
                            setModalState: setModalState,
                          ),
                          _buildSortOption(
                            context: context,
                            title: 'Name (A-Z)',
                            icon: Icons.sort_by_alpha,
                            subtitle: 'Alphabetical order',
                            option: SortOption.nameAZ,
                            setModalState: setModalState,
                          ),
                          _buildSortOption(
                            context: context,
                            title: 'Name (Z-A)',
                            icon: Icons.sort_by_alpha,
                            subtitle: 'Reverse alphabetical order',
                            option: SortOption.nameZA,
                            setModalState: setModalState,
                          ),
                          _buildSortOption(
                            context: context,
                            title: 'File Size',
                            icon: Icons.data_usage,
                            subtitle: 'Largest files first',
                            option: SortOption.fileSize,
                            setModalState: setModalState,
                          ),
                          _buildSortOption(
                            context: context,
                            title: 'File Type',
                            icon: Icons.insert_drive_file,
                            subtitle: 'Grouped by document format',
                            option: SortOption.fileType,
                            setModalState: setModalState,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to build a sort option tile
  Widget _buildSortOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String subtitle,
    required SortOption option,
    required Function(Function()) setModalState,
  }) {
    final isSelected = _currentSortOption == option;

    return Material(
      color: isSelected ? blueColor.withOpacity(0.05) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setModalState(() {
            _currentSortOption = option;
            _isSortActive = option != SortOption.newest;
          });
          _applySortOption(option);
          Navigator.pop(context);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? blueColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? blueColor : Colors.grey[600],
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? blueColor : Colors.black87,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing:
                isSelected ? Icon(Icons.check_circle, color: blueColor) : null,
          ),
        ),
      ),
    );
  }

  // Document card widget
  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final fileName = document['fileName'] ?? 'Unnamed Document';
    final extension = document['extension']?.toLowerCase() ?? '';
    final course = document['course'] ?? '';
    final courseCode = document['courseCode'] ?? '';
    final department = document['department'] ?? '';
    final documentType = document['documentType'] ?? '';
    final timeAgo = document['timeAgo'] ?? '';
    final fileUrl = document['fileUrl'] ?? '';
    final bytes = document['bytes'] as int? ?? 0;
    final uploaderName = document['uploaderName'] ?? 'Anonymous';
    final uploaderId = document['uploaderId'] ?? '';

    // Format file size
    String fileSize = '';
    if (bytes > 0) {
      if (bytes < 1024) {
        fileSize = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        fileSize = '${(bytes / 1024).toStringAsFixed(0)} KB';
      } else {
        fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    // Determine file type color and image asset
    Color cardColor;
    String assetImage = '';
    String fileType;

    switch (extension) {
      case 'pdf':
        cardColor = Color(0xFFE94235); // Red for PDF
        assetImage = 'assets/pdf.png';
        fileType = 'PDF';
        break;
      case 'doc':
      case 'docx':
        cardColor = Color(0xFF2A5699); // Blue for Word
        assetImage = 'assets/doc.png';
        fileType = 'DOC';
        break;
      case 'ppt':
      case 'pptx':
        cardColor = Color(0xFFD24726); // Orange for PowerPoint
        assetImage = 'assets/ppt.png';
        fileType = 'PPT';
        break;
      default:
        // Fallback for any other supported format (should not occur with our filters)
        cardColor = Colors.grey;
        assetImage = '';
        fileType = extension.isEmpty ? 'DOC' : extension.toUpperCase();
    }

    return GestureDetector(
      onTap: () {
        // Show document details instead of opening the document
        _showDocumentDetails(document);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject name header with more space
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Course/subject name on left
                  Expanded(
                    child: Text(
                      course.isNotEmpty
                          ? course
                          : (courseCode.isNotEmpty
                              ? courseCode
                              : 'Subject Name'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            extension == 'pdf'
                                ? Colors.red[400]
                                : extension == 'doc' || extension == 'docx'
                                ? Colors.blue[600]
                                : extension == 'ppt' || extension == 'pptx'
                                ? Colors.orange[700]
                                : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Three-dot menu on right
                  GestureDetector(
                    onTap: () {
                      // Show document details directly
                      _showDocumentDetails(document);
                    },
                    child: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // File preview (centered with more space)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Document background or image
                      Container(
                        width: 85,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 0.5,
                          ),
                        ),
                        child:
                            assetImage.isNotEmpty
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    assetImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Show icon if asset fails to load
                                      return Center(
                                        child: Icon(
                                          DashboardService.getIconForFileType(
                                            extension,
                                          ),
                                          color: cardColor,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                )
                                : Center(
                                  child: Icon(
                                    DashboardService.getIconForFileType(
                                      extension,
                                    ),
                                    color: cardColor,
                                    size: 40,
                                  ),
                                ),
                      ),

                      // File type overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            fileType,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Filename
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                fileName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Time and download
            Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Time indicator with circle background
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: orangeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.access_time,
                          size: 10,
                          color: orangeColor,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Action buttons (comment and rating)
                  Row(
                    children: [
                      // Comment button
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: blueColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: () {
                            _showCommentDialog(document);
                          },
                          child: Icon(
                            Icons.comment,
                            size: 14,
                            color: blueColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),

                      // Rating button
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: orangeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: () {
                            _showRatingDialog(document);
                          },
                          child: Icon(Icons.star, size: 14, color: orangeColor),
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

  // Show document details bottom sheet
  void _showDocumentDetails(Map<String, dynamic> document) {
    final fileName = document['fileName'] ?? 'Unnamed Document';
    final extension = document['extension']?.toLowerCase() ?? '';
    final course = document['course'] ?? '';
    final courseCode = document['courseCode'] ?? '';
    final department = document['department'] ?? '';
    final documentType = document['documentType'] ?? '';
    final timeAgo = document['timeAgo'] ?? '';
    final fileUrl = document['fileUrl'] ?? '';
    final bytes = document['bytes'] as int? ?? 0;
    final uploaderName = document['uploaderName'] ?? 'Anonymous';
    final uploaderId = document['uploaderId'] ?? '';
    final currentUserId = _authService.currentUser?.uid;
    final isCurrentUserDocument = uploaderId == currentUserId;

    // Format file size
    String fileSize = '';
    if (bytes > 0) {
      if (bytes < 1024) {
        fileSize = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        fileSize = '${(bytes / 1024).toStringAsFixed(0)} KB';
      } else {
        fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    // Determine document color based on file extension
    Color documentColor =
        extension == 'pdf'
            ? Color(0xFFE94235) // Red for PDF
            : extension == 'doc' || extension == 'docx'
            ? Color(0xFF2A5699) // Blue for Word
            : extension == 'ppt' || extension == 'pptx'
            ? Color(0xFFD24726) // Orange for PowerPoint
            : Colors.grey; // Grey for other types

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 10,
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with document type color
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: documentColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Document Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  // Document details section
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Document icon and file name
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Document icon
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: documentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      extension == 'pdf'
                                          ? Icons.picture_as_pdf
                                          : extension == 'doc' ||
                                              extension == 'docx'
                                          ? Icons.description
                                          : extension == 'ppt' ||
                                              extension == 'pptx'
                                          ? Icons.slideshow
                                          : Icons.insert_drive_file,
                                      color: documentColor,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                // File name
                                Expanded(
                                  child: Text(
                                    fileName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // File details as a card
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRowStyled(
                                    'Type',
                                    extension.toUpperCase(),
                                    Icons.description,
                                  ),
                                  _buildDetailRowStyled(
                                    'Size',
                                    fileSize,
                                    Icons.data_usage,
                                  ),
                                  if (course.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Course',
                                      course,
                                      Icons.book,
                                    ),
                                  if (courseCode.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Code',
                                      courseCode,
                                      Icons.code,
                                    ),
                                  if (department.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Department',
                                      department,
                                      Icons.domain,
                                    ),
                                  if (documentType.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Type',
                                      documentType,
                                      Icons.category,
                                    ),
                                  _buildDetailRowStyled(
                                    'Uploaded',
                                    timeAgo,
                                    Icons.access_time,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 20),

                            // Uploader section
                            Text(
                              'Uploaded by',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: blueColor,
                              ),
                            ),
                            SizedBox(height: 10),

                            // Uploader card with profile
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FutureBuilder<Map<String, dynamic>?>(
                                future: _getUserProfileData(uploaderId),
                                builder: (context, snapshot) {
                                  // Get profile picture URL if available
                                  final profileImageUrl =
                                      snapshot.data?['profileImageUrl'] ??
                                      snapshot.data?['secureUrl'];

                                  return Row(
                                    children: [
                                      // Profile image
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: blueColor.withOpacity(0.1),
                                          border: Border.all(
                                            color: blueColor.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child:
                                            profileImageUrl != null
                                                ? ClipOval(
                                                  child: Image.network(
                                                    profileImageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons.person,
                                                        color: blueColor
                                                            .withOpacity(0.7),
                                                        size: 25,
                                                      );
                                                    },
                                                  ),
                                                )
                                                : Icon(
                                                  Icons.person,
                                                  color: blueColor.withOpacity(
                                                    0.7,
                                                  ),
                                                  size: 25,
                                                ),
                                      ),
                                      SizedBox(width: 12),

                                      // Uploader info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              uploaderName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 2),

                                            // Show university or role if available
                                            if (snapshot.data != null &&
                                                (snapshot.data!['university'] !=
                                                        null ||
                                                    snapshot.data!['role'] !=
                                                        null))
                                              Text(
                                                '${snapshot.data!['role'] ?? ''} ${snapshot.data!['role'] != null && snapshot.data!['university'] != null ? '• ' : ''}${snapshot.data!['university'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            else
                                              Text(
                                                'Uploaded $timeAgo',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Connect button (only for documents not uploaded by current user)
                                      if (!isCurrentUserDocument)
                                        Container(
                                          margin: EdgeInsets.only(left: 8),
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _sendFriendRequest(
                                                uploaderId,
                                                uploaderName,
                                              );
                                            },
                                            icon: Icon(
                                              Icons.person_add,
                                              size: 16,
                                            ),
                                            label: Text(
                                              'Connect',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: blueColor,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close button
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),

                        // Action buttons
                        Row(
                          children: [
                            // Comment button
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCommentDialog(document);
                              },
                              icon: Icon(Icons.comment, size: 16),
                              label: Text('Comment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),

                            // Rating button
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showRatingDialog(document);
                              },
                              icon: Icon(Icons.star, size: 16),
                              label: Text('Rate'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orangeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
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
          ),
    );
  }

  // Helper method to build styled detail rows
  Widget _buildDetailRowStyled(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: blueColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: blueColor),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label + ':',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Get user profile data
  Future<Map<String, dynamic>?> _getUserProfileData(String userId) async {
    try {
      if (userId.isEmpty) return null;

      // First check profiles collection
      final profileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(userId)
              .get();

      if (profileDoc.exists) {
        return profileDoc.data();
      }

      // Fall back to users collection
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists) {
        return userDoc.data();
      }

      return null;
    } catch (e) {
      developer.log('Error getting user profile data: $e', name: 'Dashboard');
      return null;
    }
  }

  // Send friend request
  Future<void> _sendFriendRequest(
    String recipientId,
    String recipientName,
  ) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You need to be logged in to send requests')),
        );
        return;
      }

      // Get current user data
      final currentUserDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUserName =
          currentUserData['name'] ?? currentUser.displayName ?? 'User';

      // Check if request already exists
      final existingRequestQuery =
          await FirebaseFirestore.instance
              .collection('friendRequests')
              .where('senderId', isEqualTo: currentUser.uid)
              .where('recipientId', isEqualTo: recipientId)
              .get();

      if (existingRequestQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You already sent a request to this user')),
        );
        return;
      }

      // Create friend request
      await FirebaseFirestore.instance.collection('friendRequests').add({
        'senderId': currentUser.uid,
        'senderName': currentUserName,
        'senderProfileUrl': currentUserData['profileImageUrl'],
        'recipientId': recipientId,
        'recipientName': recipientName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'message': 'I would like to connect regarding your shared document.',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request sent to $recipientName')));
    } catch (e) {
      developer.log('Error sending friend request: $e', name: 'Dashboard');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request')));
    }
  }

  // Show comment dialog
  void _showCommentDialog(Map<String, dynamic> document) async {
    final TextEditingController commentController = TextEditingController();
    final documentId = document['id'];
    final fileName = document['fileName'] ?? 'Unnamed Document';

    // Show loading dialog while fetching comments
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) =>
              Center(child: CircularProgressIndicator(color: blueColor)),
    );

    // Fetch existing comments
    List<Map<String, dynamic>> comments = [];
    try {
      final commentsSnapshot =
          await FirebaseFirestore.instance
              .collection('documents')
              .doc(documentId)
              .collection('comments')
              .orderBy('createdAt', descending: true)
              .get();

      for (var doc in commentsSnapshot.docs) {
        final data = doc.data();
        comments.add({
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'userName': data['userName'] ?? 'Anonymous',
          'userProfileUrl': data['userProfileUrl'],
          'comment': data['comment'] ?? '',
          'createdAt': data['createdAt'] as Timestamp?,
        });
      }

      // Close loading dialog
      Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      developer.log('Error fetching comments: $e', name: 'Dashboard');
    }

    // Show comments dialog
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 10,
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with document title
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: blueColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Comments - $fileName',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Comments list
                  Flexible(
                    child:
                        comments.isEmpty
                            ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.comment_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No comments yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Be the first to comment!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ListView.separated(
                              padding: EdgeInsets.all(16),
                              itemCount: comments.length,
                              separatorBuilder: (context, index) => Divider(),
                              itemBuilder: (context, index) {
                                final comment = comments[index];
                                final userName = comment['userName'];
                                final userComment = comment['comment'];
                                final profileUrl = comment['userProfileUrl'];
                                final createdAt = comment['createdAt'];

                                // Format timestamp
                                String timeAgo = 'Recently';
                                if (createdAt != null) {
                                  final now = DateTime.now();
                                  final difference = now.difference(
                                    createdAt.toDate(),
                                  );

                                  if (difference.inDays > 0) {
                                    timeAgo =
                                        '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
                                  } else if (difference.inHours > 0) {
                                    timeAgo =
                                        '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
                                  } else if (difference.inMinutes > 0) {
                                    timeAgo =
                                        '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
                                  } else {
                                    timeAgo = 'Just now';
                                  }
                                }

                                return Container(
                                  padding: EdgeInsets.all(12),
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // User info row
                                      Row(
                                        children: [
                                          // User avatar
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: blueColor.withOpacity(0.1),
                                              border: Border.all(
                                                color: blueColor.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child:
                                                profileUrl != null
                                                    ? ClipOval(
                                                      child: Image.network(
                                                        profileUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Icon(
                                                            Icons.person,
                                                            color: blueColor
                                                                .withOpacity(
                                                                  0.7,
                                                                ),
                                                            size: 20,
                                                          );
                                                        },
                                                      ),
                                                    )
                                                    : Icon(
                                                      Icons.person,
                                                      color: blueColor
                                                          .withOpacity(0.7),
                                                      size: 20,
                                                    ),
                                          ),
                                          SizedBox(width: 8),

                                          // Username and time
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  timeAgo,
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

                                      // Comment text
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: 44,
                                          top: 8,
                                        ),
                                        child: Text(
                                          userComment,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),

                  // Comment input section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          spreadRadius: -2,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Write your comment here...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: blueColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel'),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send, size: 16),
                                  SizedBox(width: 4),
                                  Text('Comment'),
                                ],
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
          ),
    );

    if (result == true && commentController.text.isNotEmpty) {
      try {
        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You need to be logged in to comment')),
          );
          return;
        }

        // Get current user data
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        // Add comment to Firestore
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(documentId)
            .collection('comments')
            .add({
              'userId': currentUser.uid,
              'userName':
                  userData?['name'] ?? currentUser.displayName ?? 'User',
              'userProfileUrl': userData?['profileImageUrl'],
              'comment': commentController.text,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Award points for commenting
        await ActivityPointsService().awardPoints(
          currentUser.uid,
          2,
          'Commented on a document',
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Comment added successfully')));
      } catch (e) {
        developer.log('Error adding comment: $e', name: 'Dashboard');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add comment')));
      }
    }
  }

  // Show rating dialog
  void _showRatingDialog(Map<String, dynamic> document) async {
    final documentId = document['id'];
    final fileName = document['fileName'] ?? 'Unnamed Document';
    double rating = 3.0; // Default rating
    double averageRating = 0.0;
    int ratingCount = 0;

    // Show loading dialog while fetching ratings
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) =>
              Center(child: CircularProgressIndicator(color: orangeColor)),
    );

    // Fetch document to get average rating
    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('documents')
              .doc(documentId)
              .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      }

      // Check if current user has already rated
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userRatingDoc =
            await FirebaseFirestore.instance
                .collection('documents')
                .doc(documentId)
                .collection('ratings')
                .doc(currentUser.uid)
                .get();

        if (userRatingDoc.exists) {
          final data = userRatingDoc.data() as Map<String, dynamic>;
          rating = (data['rating'] as num?)?.toDouble() ?? 3.0;
        }
      }

      // Close loading dialog
      Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      developer.log('Error fetching ratings: $e', name: 'Dashboard');
    }

    // Show rating dialog
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 10,
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with document title
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: orangeColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Rate Document',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Document info - make scrollable to handle overflow
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: 24),

                            // Current average rating
                            if (ratingCount > 0) ...[
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Average rating with stars
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Average Rating: ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          averageRating.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: orangeColor,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '/5',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 8),

                                    // Visual star representation
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(5, (index) {
                                        // Show full, half or empty star based on rating
                                        IconData iconData;
                                        if (index + 0.5 < averageRating) {
                                          iconData = Icons.star;
                                        } else if (index < averageRating) {
                                          iconData = Icons.star_half;
                                        } else {
                                          iconData = Icons.star_border;
                                        }

                                        return Icon(
                                          iconData,
                                          color: orangeColor,
                                          size: 20,
                                        );
                                      }),
                                    ),

                                    SizedBox(height: 8),

                                    // Total number of ratings
                                    Text(
                                      'Based on $ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                            ],

                            Text(
                              'How would you rate this document?',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[800],
                              ),
                            ),

                            // Show previous rating message if user has rated before
                            FutureBuilder<DocumentSnapshot>(
                              future:
                                  _authService.currentUser != null
                                      ? FirebaseFirestore.instance
                                          .collection('documents')
                                          .doc(documentId)
                                          .collection('ratings')
                                          .doc(_authService.currentUser!.uid)
                                          .get()
                                      : null,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final previousRating =
                                      (snapshot.data!.data()
                                              as Map<String, dynamic>)['rating']
                                          as double?;
                                  if (previousRating != null) {
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Your previous rating: ${previousRating.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return SizedBox(height: 8);
                              },
                            ),

                            SizedBox(height: 16),

                            // Rating stars - fix overflow with Wrap
                            StatefulBuilder(
                              builder: (context, setState) {
                                return Wrap(
                                  alignment: WrapAlignment.center,
                                  children: List.generate(5, (index) {
                                    return IconButton(
                                      icon: Icon(
                                        index < rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: orangeColor,
                                        size: 32,
                                      ),
                                      padding: EdgeInsets.all(4),
                                      constraints: BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          rating = index + 1.0;
                                        });
                                      },
                                    );
                                  }),
                                );
                              },
                            ),

                            SizedBox(height: 8),

                            // Rating description
                            StatefulBuilder(
                              builder: (context, setState) {
                                String ratingText = '';
                                if (rating <= 1) {
                                  ratingText = 'Poor';
                                } else if (rating <= 2) {
                                  ratingText = 'Fair';
                                } else if (rating <= 3) {
                                  ratingText = 'Good';
                                } else if (rating <= 4) {
                                  ratingText = 'Very Good';
                                } else {
                                  ratingText = 'Excellent';
                                }

                                return Text(
                                  ratingText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: orangeColor,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orangeColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 16),
                              SizedBox(width: 4),
                              Text('Submit'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    if (result == true) {
      try {
        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You need to be logged in to rate')),
          );
          return;
        }

        // Add rating to Firestore
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(documentId)
            .collection('ratings')
            .doc(currentUser.uid) // One rating per user
            .set({
              'userId': currentUser.uid,
              'rating': rating,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Update average rating in document
        final ratingsSnapshot =
            await FirebaseFirestore.instance
                .collection('documents')
                .doc(documentId)
                .collection('ratings')
                .get();

        if (ratingsSnapshot.docs.isNotEmpty) {
          double totalRating = 0;
          for (var doc in ratingsSnapshot.docs) {
            totalRating += doc.data()['rating'] as double;
          }
          double averageRating = totalRating / ratingsSnapshot.docs.length;

          await FirebaseFirestore.instance
              .collection('documents')
              .doc(documentId)
              .update({
                'averageRating': averageRating,
                'ratingCount': ratingsSnapshot.docs.length,
              });
        }

        // Award points for rating
        await ActivityPointsService().awardPoints(
          currentUser.uid,
          1,
          'Rated a document',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rating submitted successfully')),
        );
      } catch (e) {
        developer.log('Error adding rating: $e', name: 'Dashboard');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit rating')));
      }
    }
  }

  // Add this method to get total unread messages
  Future<int> _getTotalUnreadMessages() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return 0;

      // Get all chat rooms where user is a participant
      final chatRooms =
          await FirebaseFirestore.instance
              .collection('privateChats')
              .where('participants', arrayContains: currentUser.uid)
              .get();

      int totalUnread = 0;

      // For each chat room, count unread messages
      for (var chatRoom in chatRooms.docs) {
        final unreadMessages =
            await chatRoom.reference
                .collection('messages')
                .where('recipientId', isEqualTo: currentUser.uid)
                .where('isRead', isEqualTo: false)
                .get();

        totalUnread += unreadMessages.docs.length;
      }

      return totalUnread;
    } catch (e) {
      developer.log(
        'Error getting total unread messages: $e',
        name: 'Dashboard',
      );
      return 0;
    }
  }

  // Update the drawer item builder to include unread message count
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showUnreadCount = false,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          Icon(icon, color: blueColor),
          if (showUnreadCount)
            StreamBuilder<QuerySnapshot>(
              stream:
                  title == 'Friend Requests'
                      ? FirebaseFirestore.instance
                          .collection('friendRequests')
                          .where(
                            'recipientId',
                            isEqualTo: _authService.currentUser?.uid,
                          )
                          .where('status', isEqualTo: 'pending')
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('privateChats')
                          .where(
                            'participants',
                            arrayContains: _authService.currentUser?.uid,
                          )
                          .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox.shrink();

                int count = 0;

                if (title == 'Friend Requests') {
                  // Count pending friend requests
                  count = snapshot.data!.docs.length;
                } else {
                  // Count unread messages
                  int totalUnread = 0;
                  for (var chatRoom in snapshot.data!.docs) {
                    final unreadMessages =
                        chatRoom.reference
                            .collection('messages')
                            .where(
                              'recipientId',
                              isEqualTo: _authService.currentUser?.uid,
                            )
                            .where('isRead', isEqualTo: false)
                            .snapshots();

                    unreadMessages.listen((messages) {
                      totalUnread += messages.docs.length;
                    });
                  }
                  count = totalUnread;
                }

                if (count > 0) {
                  return Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            title == 'Friend Requests'
                                ? Colors.red
                                : orangeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  // Add this method to show the filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 12,
                child: Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F8F8), // Off-white background color
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: blueColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Filter Documents',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Filter Content
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            // Close all dropdowns when tapping outside
                            setDialogState(() {
                              _showDepartmentDropdown = false;
                              _showSubjectDropdown = false;
                              _showCourseCodeDropdown = false;
                              _showSemesterDropdown = false;
                            });
                          },
                          behavior: HitTestBehavior.translucent,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Semester Filter
                                Text(
                                  'Semester',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _semesterFocusNode.hasFocus
                                              ? orangeColor
                                              : Colors.grey[300]!,
                                      width:
                                          _semesterFocusNode.hasFocus ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Custom semester selection field with dropdown
                                      InkWell(
                                        focusNode: _semesterFocusNode,
                                        onTap: () {
                                          // Toggle dropdown when tapping on field
                                          _semesterFocusNode.requestFocus();
                                          setDialogState(() {
                                            _showSemesterDropdown =
                                                !_showSemesterDropdown;
                                            // Close other dropdowns
                                            _showDepartmentDropdown = false;
                                            _showSubjectDropdown = false;
                                            _showCourseCodeDropdown = false;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 15,
                                          ),
                                          child: Row(
                                            children: [
                                              // Icon for semester
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: orangeColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.calendar_today,
                                                  color: orangeColor,
                                                  size: 18,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              // Text for selected semester or placeholder
                                              Expanded(
                                                child: Text(
                                                  _selectedSemester ??
                                                      'Select Semester',
                                                  style: TextStyle(
                                                    color:
                                                        _selectedSemester !=
                                                                null
                                                            ? Colors.black
                                                            : Colors
                                                                .grey
                                                                .shade600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              // Dropdown arrow icon
                                              GestureDetector(
                                                onTap: () {
                                                  // Toggle dropdown when clicking on suffix icon
                                                  setDialogState(() {
                                                    _showSemesterDropdown =
                                                        !_showSemesterDropdown;
                                                    // Close other dropdowns
                                                    _showDepartmentDropdown =
                                                        false;
                                                    _showSubjectDropdown =
                                                        false;
                                                    _showCourseCodeDropdown =
                                                        false;
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: orangeColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.arrow_drop_down,
                                                    color: orangeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Semesters dropdown
                                      if (_showSemesterDropdown)
                                        Container(
                                          constraints: BoxConstraints(
                                            maxHeight: 156,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap:
                                                () {}, // Prevent taps inside dropdown from closing it
                                            behavior: HitTestBehavior.opaque,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount: _semesters.length,
                                              itemBuilder: (context, index) {
                                                final semester =
                                                    _semesters[index];
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                        vertical: 0,
                                                      ),
                                                  leading: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: orangeColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.calendar_today,
                                                      color: orangeColor,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  title: Text(semester),
                                                  onTap: () {
                                                    // Set semester and hide dropdown
                                                    setDialogState(() {
                                                      _selectedSemester =
                                                          semester;
                                                      _showSemesterDropdown =
                                                          false;
                                                    });
                                                    setState(() {
                                                      _selectedSemester =
                                                          semester;
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Department Filter
                                Text(
                                  'Department',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _departmentFocusNode.hasFocus
                                              ? orangeColor
                                              : Colors.grey[300]!,
                                      width:
                                          _departmentFocusNode.hasFocus ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Custom department field with dropdown
                                      TextField(
                                        controller: _departmentController,
                                        focusNode: _departmentFocusNode,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search or select department',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 15,
                                          ),
                                          prefixIcon: Container(
                                            margin: EdgeInsets.only(
                                              left: 10,
                                              right: 5,
                                            ),
                                            padding: EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: orangeColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.domain,
                                              color: orangeColor,
                                              size: 18,
                                            ),
                                          ),
                                          prefixIconConstraints: BoxConstraints(
                                            minWidth: 40,
                                            maxHeight: 30,
                                          ),
                                          suffixIcon: GestureDetector(
                                            onTap: () {
                                              // Toggle dropdown when clicking on suffix icon
                                              setDialogState(() {
                                                _showDepartmentDropdown =
                                                    !_showDepartmentDropdown;
                                                // Close other dropdowns
                                                _showSemesterDropdown = false;
                                                _showSubjectDropdown = false;
                                                _showCourseCodeDropdown = false;
                                              });
                                            },
                                            child: Container(
                                              margin: EdgeInsets.only(
                                                right: 10,
                                              ),
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: orangeColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.arrow_drop_down,
                                                color: orangeColor,
                                              ),
                                            ),
                                          ),
                                          suffixIconConstraints: BoxConstraints(
                                            minWidth: 40,
                                            maxHeight: 40,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          // Update UI when text changes
                                          setDialogState(() {
                                            _selectedDepartment = value;
                                            _showDepartmentDropdown = true;
                                          });
                                          setState(() {
                                            _selectedDepartment = value;
                                          });
                                        },
                                        onTap: () {
                                          // Show dropdown when tapping on field
                                          setDialogState(() {
                                            _showDepartmentDropdown = true;
                                            // Close other dropdowns
                                            _showSemesterDropdown = false;
                                            _showSubjectDropdown = false;
                                            _showCourseCodeDropdown = false;
                                          });
                                        },
                                        onSubmitted: (value) {
                                          _addNewDepartmentIfNeeded();
                                        },
                                      ),

                                      // Filtered departments dropdown
                                      if (_showDepartmentDropdown)
                                        Container(
                                          constraints: BoxConstraints(
                                            maxHeight: 156,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap:
                                                () {}, // Prevent taps inside dropdown from closing it
                                            behavior: HitTestBehavior.opaque,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount:
                                                  _getFilteredDepartments()
                                                      .length,
                                              itemBuilder: (context, index) {
                                                final dept =
                                                    _getFilteredDepartments()[index];
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                        vertical: 0,
                                                      ),
                                                  leading: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: orangeColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.domain,
                                                      color: orangeColor,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  title: Text(dept),
                                                  onTap: () {
                                                    // Set department and hide dropdown
                                                    setDialogState(() {
                                                      _departmentController
                                                          .text = dept;
                                                      _selectedDepartment =
                                                          dept;
                                                      _showDepartmentDropdown =
                                                          false;
                                                    });
                                                    setState(() {
                                                      _selectedDepartment =
                                                          dept;
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Subject Filter
                                Text(
                                  'Subject',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _subjectFocusNode.hasFocus
                                              ? orangeColor
                                              : Colors.grey[300]!,
                                      width: _subjectFocusNode.hasFocus ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Custom subject field with dropdown
                                      TextField(
                                        controller: _subjectController,
                                        focusNode: _subjectFocusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Search or select subject',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 15,
                                          ),
                                          prefixIcon: Container(
                                            margin: EdgeInsets.only(
                                              left: 10,
                                              right: 5,
                                            ),
                                            padding: EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: orangeColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.book,
                                              color: orangeColor,
                                              size: 18,
                                            ),
                                          ),
                                          prefixIconConstraints: BoxConstraints(
                                            minWidth: 40,
                                            maxHeight: 30,
                                          ),
                                          suffixIcon: GestureDetector(
                                            onTap: () {
                                              // Toggle dropdown when clicking on suffix icon
                                              setDialogState(() {
                                                _showSubjectDropdown =
                                                    !_showSubjectDropdown;
                                                // Close other dropdowns
                                                _showSemesterDropdown = false;
                                                _showDepartmentDropdown = false;
                                                _showCourseCodeDropdown = false;
                                              });
                                            },
                                            child: Container(
                                              margin: EdgeInsets.only(
                                                right: 10,
                                              ),
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: orangeColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.arrow_drop_down,
                                                color: orangeColor,
                                              ),
                                            ),
                                          ),
                                          suffixIconConstraints: BoxConstraints(
                                            minWidth: 40,
                                            maxHeight: 40,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          // Update UI when text changes
                                          setDialogState(() {
                                            _selectedSubject = value;
                                            _showSubjectDropdown = true;
                                          });
                                          setState(() {
                                            _selectedSubject = value;
                                          });
                                        },
                                        onTap: () {
                                          // Show dropdown when tapping on field
                                          setDialogState(() {
                                            _showSubjectDropdown = true;
                                            // Close other dropdowns
                                            _showSemesterDropdown = false;
                                            _showDepartmentDropdown = false;
                                            _showCourseCodeDropdown = false;
                                          });
                                        },
                                        onSubmitted: (value) {
                                          _addNewSubjectIfNeeded();
                                        },
                                      ),

                                      // Filtered subjects dropdown
                                      if (_showSubjectDropdown)
                                        Container(
                                          constraints: BoxConstraints(
                                            maxHeight: 156,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap:
                                                () {}, // Prevent taps inside dropdown from closing it
                                            behavior: HitTestBehavior.opaque,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount:
                                                  _getFilteredSubjects().length,
                                              itemBuilder: (context, index) {
                                                final subject =
                                                    _getFilteredSubjects()[index];
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                        vertical: 0,
                                                      ),
                                                  leading: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: orangeColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.book,
                                                      color: orangeColor,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  title: Text(subject),
                                                  onTap: () {
                                                    // Set subject and hide dropdown
                                                    setDialogState(() {
                                                      _subjectController.text =
                                                          subject;
                                                      _selectedSubject =
                                                          subject;
                                                      _showSubjectDropdown =
                                                          false;
                                                    });
                                                    setState(() {
                                                      _selectedSubject =
                                                          subject;
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Course Code Filter
                                Text(
                                  'Course Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _courseCodeFocusNode.hasFocus
                                              ? orangeColor
                                              : Colors.grey[300]!,
                                      width:
                                          _courseCodeFocusNode.hasFocus ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Custom course code field with dropdown
                                      TextField(
                                        controller: _courseCodeController,
                                        focusNode: _courseCodeFocusNode,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search or select course code',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 15,
                                          ),
                                          prefixIcon: Container(
                                            margin: EdgeInsets.only(
                                              left: 10,
                                              right: 5,
                                            ),
                                            padding: EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: orangeColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.code,
                                              color: orangeColor,
                                              size: 18,
                                            ),
                                          ),
                                          prefixIconConstraints: BoxConstraints(
                                            minWidth: 40,
                                            maxHeight: 30,
                                          ),
                                          suffixIcon: GestureDetector(
                                            onTap: () {
                                              // Toggle dropdown when clicking on suffix icon
                                              setDialogState(() {
                                                _showCourseCodeDropdown =
                                                    !_showCourseCodeDropdown;
                                                // Close other dropdowns
                                                _showSemesterDropdown = false;
                                                _showDepartmentDropdown = false;
                                                _showSubjectDropdown = false;
                                              });
                                            },
                                            child: Container(
                                              margin: EdgeInsets.only(
                                                right: 10,
                                              ),
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: orangeColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.arrow_drop_down,
                                                color: orangeColor,
                                              ),
                                            ),
                                          ),
                                          suffixIconConstraints: BoxConstraints(
                                            minWidth: 40,
                                            maxHeight: 40,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          // Update UI when text changes
                                          setDialogState(() {
                                            _selectedCourseCode = value;
                                            _showCourseCodeDropdown = true;
                                          });
                                          setState(() {
                                            _selectedCourseCode = value;
                                          });
                                        },
                                        onTap: () {
                                          // Show dropdown when tapping on field
                                          setDialogState(() {
                                            _showCourseCodeDropdown = true;
                                            // Close other dropdowns
                                            _showSemesterDropdown = false;
                                            _showDepartmentDropdown = false;
                                            _showSubjectDropdown = false;
                                          });
                                        },
                                        onSubmitted: (value) {
                                          _addNewCourseCodeIfNeeded();
                                        },
                                      ),

                                      // Filtered course codes dropdown
                                      if (_showCourseCodeDropdown)
                                        Container(
                                          constraints: BoxConstraints(
                                            maxHeight: 156,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap:
                                                () {}, // Prevent taps inside dropdown from closing it
                                            behavior: HitTestBehavior.opaque,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount:
                                                  _getFilteredCourseCodes()
                                                      .length,
                                              itemBuilder: (context, index) {
                                                final code =
                                                    _getFilteredCourseCodes()[index];
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                        vertical: 0,
                                                      ),
                                                  leading: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: orangeColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.code,
                                                      color: orangeColor,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  title: Text(code),
                                                  onTap: () {
                                                    // Set course code and hide dropdown
                                                    setDialogState(() {
                                                      _courseCodeController
                                                          .text = code;
                                                      _selectedCourseCode =
                                                          code;
                                                      _showCourseCodeDropdown =
                                                          false;
                                                    });
                                                    setState(() {
                                                      _selectedCourseCode =
                                                          code;
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Action Buttons
                                Padding(
                                  padding: EdgeInsets.only(top: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          _resetFilters();
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Reset',
                                          style: TextStyle(color: orangeColor),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          // Apply filters
                                          _applyFilters();
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: orangeColor,
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Apply Filters',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  // Method to apply filters
  void _applyFilters() {
    // Check if any filter is selected
    bool hasFilters =
        _selectedSemester != null ||
        (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) ||
        (_selectedSubject != null && _selectedSubject!.isNotEmpty) ||
        (_selectedCourseCode != null && _selectedCourseCode!.isNotEmpty);

    if (!hasFilters) {
      setState(() {
        _isFilterApplied = false;
        // If search is active, perform search on all documents
        if (_isSearchActive) {
          _performSearch();
        } else {
          _filteredDocuments = [];
        }
      });
      return;
    }

    // Determine base set of documents to filter
    // If search is active, filter from search results, otherwise filter from all documents
    List<Map<String, dynamic>> baseDocuments =
        _isSearchActive ? _filteredDocuments : _allDocuments;

    // Filter the documents based on selected criteria
    List<Map<String, dynamic>> filtered =
        baseDocuments.where((doc) {
          bool matches = true;

          // Match by semester
          if (_selectedSemester != null) {
            // Some documents might store semester as ordinal (First, Second)
            // and others might store as number (1, 2)
            bool semesterMatch = false;

            // Check for direct match
            if (doc['semester'].toString().toLowerCase() ==
                _selectedSemester!.toLowerCase()) {
              semesterMatch = true;
            }

            // Also check for numeric equivalent
            int? semesterNumber;
            switch (_selectedSemester!.toLowerCase()) {
              case 'first':
                semesterNumber = 1;
                break;
              case 'second':
                semesterNumber = 2;
                break;
              case 'third':
                semesterNumber = 3;
                break;
              case 'fourth':
                semesterNumber = 4;
                break;
              case 'fifth':
                semesterNumber = 5;
                break;
              case 'sixth':
                semesterNumber = 6;
                break;
              case 'seventh':
                semesterNumber = 7;
                break;
              case 'eighth':
                semesterNumber = 8;
                break;
            }

            // Check if document semester matches the number
            if (semesterNumber != null &&
                doc['semester'].toString() == semesterNumber.toString()) {
              semesterMatch = true;
            }

            matches = matches && semesterMatch;
          }

          // Match by department
          if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) {
            matches =
                matches &&
                doc['department'].toString().toLowerCase().contains(
                  _selectedDepartment!.toLowerCase(),
                );
          }

          // Match by subject/course
          if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
            matches =
                matches &&
                doc['course'].toString().toLowerCase().contains(
                  _selectedSubject!.toLowerCase(),
                );
          }

          // Match by course code
          if (_selectedCourseCode != null && _selectedCourseCode!.isNotEmpty) {
            matches =
                matches &&
                doc['courseCode'].toString().toLowerCase().contains(
                  _selectedCourseCode!.toLowerCase(),
                );
          }

          return matches;
        }).toList();

    // Update the filtered documents list and set filter applied flag
    setState(() {
      _filteredDocuments = filtered;
      _isFilterApplied = true;
    });

    // Debug log filter results
    developer.log(
      'Filter applied: Found ${_filteredDocuments.length} matching documents out of ${baseDocuments.length}',
      name: 'Dashboard',
    );
  }

  // Update resetFilters to work with search
  void _resetFilters() {
    setState(() {
      _selectedSemester = null;
      _selectedDepartment = null;
      _selectedSubject = null;
      _selectedCourseCode = null;
      _departmentController.clear();
      _subjectController.clear();
      _courseCodeController.clear();
      _isFilterApplied = false;

      // If search is active, reapply search without filters
      if (_isSearchActive) {
        _performSearch();
      } else {
        _filteredDocuments = [];
      }
    });
  }

  // Add method to clear search
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSearchActive = false;

      // If filters are applied, show filtered results
      if (_isFilterApplied) {
        _applyFilters();
      } else {
        _filteredDocuments = [];
      }
    });
  }

  // Initialize filter data from Firebase
  Future<void> _initializeFilterData() async {
    try {
      // Get departments
      final departmentsSnapshot =
          await FirebaseFirestore.instance.collection('departments').get();
      _departments =
          departmentsSnapshot.docs
              .map((doc) => doc['name'].toString())
              .toList();

      // Get subjects
      final subjectsSnapshot =
          await FirebaseFirestore.instance.collection('courses').get();
      _subjects =
          subjectsSnapshot.docs.map((doc) => doc['name'].toString()).toList();

      // Get course codes
      final courseCodesSnapshot =
          await FirebaseFirestore.instance.collection('course_codes').get();
      _courseCodes =
          courseCodesSnapshot.docs
              .map((doc) => doc['code'].toString())
              .toList();

      setState(() {
        // Update UI with loaded data
      });
    } catch (e) {
      developer.log('Error loading filter data: $e', name: 'Dashboard');
    }
  }

  // Check if there's a streak notification to show and display it
  Future<void> _checkAndShowStreakNotification() async {
    try {
      final user = _authService.currentUser;
      if (user == null || _isStreakMessageShown) return;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final lastStreakCheck =
          userData['lastStreakCheck'] as Map<String, dynamic>?;

      if (lastStreakCheck != null && lastStreakCheck['shown'] == false) {
        final currentStreak = lastStreakCheck['currentStreak'] as int;
        final pointsAwarded = lastStreakCheck['pointsAwarded'] as int;

        // Only show if we have a meaningful streak (more than 1 day)
        if (currentStreak > 1 && mounted && !_isStreakMessageShown) {
          setState(() => _isStreakMessageShown = true);

          // Show a subtle notification at the bottom
          final streakMessage =
              'Login streak: $currentStreak days! +$pointsAwarded point';

          // Use a less intrusive notification that appears at the bottom
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(streakMessage, style: TextStyle(fontSize: 13)),
                ],
              ),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: Colors.black87,
            ),
          );

          // Mark as shown in the database
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastStreakCheck.shown': true});

          developer.log(
            'Displayed streak notification: Streak=$currentStreak',
            name: 'Dashboard',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Error checking streak notification: $e',
        name: 'Dashboard',
      );
    }
  }

  // Get filtered departments based on the search text
  List<String> _getFilteredDepartments() {
    final searchText = _departmentController.text.toLowerCase();
    if (searchText.isEmpty) {
      // Return all departments if no search text
      return _departments;
    }

    // Filter departments that contain the search text
    return _departments
        .where((dept) => dept.toLowerCase().contains(searchText))
        .toList();
  }

  // Get filtered subjects based on the search text
  List<String> _getFilteredSubjects() {
    final searchText = _subjectController.text.toLowerCase();
    if (searchText.isEmpty) {
      // Return all subjects if no search text
      return _subjects;
    }

    // Filter subjects that contain the search text
    return _subjects
        .where((subject) => subject.toLowerCase().contains(searchText))
        .toList();
  }

  // Get filtered course codes based on the search text
  List<String> _getFilteredCourseCodes() {
    final searchText = _courseCodeController.text.toLowerCase();
    if (searchText.isEmpty) {
      // Return all course codes if no search text
      return _courseCodes;
    }

    // Filter course codes that contain the search text
    return _courseCodes
        .where((code) => code.toLowerCase().contains(searchText))
        .toList();
  }

  // Add method for adding a new department
  Future<void> _addNewDepartmentIfNeeded() async {
    // Prevent multiple simultaneous calls
    if (_isAddingDepartment) {
      return;
    }

    // Set flag to indicate we're in the process of adding
    _isAddingDepartment = true;

    try {
      // Get text from controller and trim whitespace
      final departmentText = _departmentController.text.trim();

      if (departmentText.isEmpty) {
        setState(() {
          _showDepartmentDropdown = false;
        });
        return;
      }

      // First refresh the departments list to get the latest data
      await _initializeFilterData();

      // Check if department is in the list
      if (!_departments.contains(departmentText)) {
        // This would be where you'd add a new department
        // For now, we'll just update the state
        setState(() {
          _selectedDepartment = departmentText;
        });
      } else {
        setState(() {
          _selectedDepartment = departmentText;
        });
      }

      // Hide dropdown
      setState(() {
        _showDepartmentDropdown = false;
      });
    } finally {
      // Reset flag when done, regardless of success or failure
      _isAddingDepartment = false;
    }
  }

  // Implementation for adding new subject
  Future<void> _addNewSubjectIfNeeded() async {
    if (_isAddingSubject) return;
    _isAddingSubject = true;

    try {
      final subjectText = _subjectController.text.trim();
      if (subjectText.isEmpty) {
        setState(() {
          _showSubjectDropdown = false;
        });
        return;
      }

      await _initializeFilterData();

      setState(() {
        _selectedSubject = subjectText;
        _showSubjectDropdown = false;
      });
    } finally {
      _isAddingSubject = false;
    }
  }

  // Implementation for adding new course code
  Future<void> _addNewCourseCodeIfNeeded() async {
    if (_isAddingCourseCode) return;
    _isAddingCourseCode = true;

    try {
      final codeText = _courseCodeController.text.trim();
      if (codeText.isEmpty) {
        setState(() {
          _showCourseCodeDropdown = false;
        });
        return;
      }

      await _initializeFilterData();

      setState(() {
        _selectedCourseCode = codeText;
        _showCourseCodeDropdown = false;
      });
    } finally {
      _isAddingCourseCode = false;
    }
  }

  // Replace the existing _showFilterOptions method
  void _showFilterOptions() {
    _showFilterDialog();
  }

  // Helper method to generate a description of active filters
  String _getActiveFilterDescription() {
    List<String> activeFilters = [];

    if (_selectedSemester != null) {
      activeFilters.add('Semester: $_selectedSemester');
    }

    if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) {
      activeFilters.add('Department: $_selectedDepartment');
    }

    if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
      activeFilters.add('Subject: $_selectedSubject');
    }

    if (_selectedCourseCode != null && _selectedCourseCode!.isNotEmpty) {
      activeFilters.add('Course Code: $_selectedCourseCode');
    }

    return activeFilters.join(' • ');
  }

  // Method to apply sort to documents
  void _applySortOption(SortOption option) {
    setState(() {
      _currentSortOption = option;
      _isSortActive = option != SortOption.newest; // Default sort is newest

      // Apply sort to the appropriate document list
      List<Map<String, dynamic>> docsToSort =
          (_isFilterApplied || _isSearchActive)
              ? _filteredDocuments
              : List.from(
                _allDocuments,
              ); // Use a copy to avoid modifying original

      // Log before sorting
      developer.log(
        'Before sorting: First document: ${docsToSort.isNotEmpty ? docsToSort.first['fileName'] : "None"}',
        name: 'Dashboard',
      );

      // Debug info about documents
      if (docsToSort.isNotEmpty) {
        developer.log(
          'Document keys available: ${docsToSort.first.keys.join(", ")}',
          name: 'Dashboard',
        );
        developer.log(
          'timestamp type: ${docsToSort.first['timestamp']?.runtimeType}',
          name: 'Dashboard',
        );
      }

      switch (option) {
        case SortOption.newest:
          // For newest first, we need to refresh sorting
          docsToSort.sort((a, b) {
            // First try to compare using timestamp if present in the map
            final aUploadTime = a['timestamp'] as Timestamp?;
            final bUploadTime = b['timestamp'] as Timestamp?;

            if (aUploadTime != null && bUploadTime != null) {
              // Sort by timestamp (newest first)
              return bUploadTime.compareTo(aUploadTime);
            }

            // Fallback to timeAgo string comparison if timestamps not available
            final timeA = a['timeAgo'] ?? '';
            final timeB = b['timeAgo'] ?? '';

            // Handle "Just now" case
            if (timeA == 'Just now') return -1; // a is newer
            if (timeB == 'Just now') return 1; // b is newer

            // Compare numerically for time-based strings
            final numA = _extractNumericValue(timeA);
            final numB = _extractNumericValue(timeB);

            return numA.compareTo(numB); // Smaller values are newer
          });
          break;

        case SortOption.oldest:
          docsToSort.sort((a, b) {
            // First try to compare using timestamp if present in the map
            final aUploadTime = a['timestamp'] as Timestamp?;
            final bUploadTime = b['timestamp'] as Timestamp?;

            if (aUploadTime != null && bUploadTime != null) {
              // Sort by timestamp (oldest first)
              return aUploadTime.compareTo(bUploadTime);
            }

            // Fallback to timeAgo string comparison if timestamps not available
            final timeA = a['timeAgo'] ?? '';
            final timeB = b['timeAgo'] ?? '';

            // Handle "Just now" case
            if (timeA == 'Just now') return 1; // a is newer, so comes later
            if (timeB == 'Just now') return -1; // b is newer, so comes later

            // Compare numerically for time-based strings
            final numA = _extractNumericValue(timeA);
            final numB = _extractNumericValue(timeB);

            return numB.compareTo(numA); // Larger values are older
          });
          break;

        case SortOption.nameAZ:
          docsToSort.sort((a, b) {
            final nameA = (a['fileName'] ?? '').toString().toLowerCase();
            final nameB = (b['fileName'] ?? '').toString().toLowerCase();
            return nameA.compareTo(nameB);
          });
          break;

        case SortOption.nameZA:
          docsToSort.sort((a, b) {
            final nameA = (a['fileName'] ?? '').toString().toLowerCase();
            final nameB = (b['fileName'] ?? '').toString().toLowerCase();
            return nameB.compareTo(nameA);
          });
          break;

        case SortOption.fileSize:
          docsToSort.sort((a, b) {
            final sizeA = a['bytes'] as int? ?? 0;
            final sizeB = b['bytes'] as int? ?? 0;
            return sizeB.compareTo(sizeA); // Largest first
          });
          break;

        case SortOption.fileType:
          docsToSort.sort((a, b) {
            final typeA = (a['extension'] ?? '').toString().toLowerCase();
            final typeB = (b['extension'] ?? '').toString().toLowerCase();
            return typeA.compareTo(typeB);
          });
          break;
      }

      // Update the appropriate list with sorted results
      if (_isFilterApplied || _isSearchActive) {
        _filteredDocuments = docsToSort;
      } else {
        // This is the key change - we're replacing the in-memory list
        // with our sorted version, but not triggering a database reload
        _allDocuments = docsToSort;
      }

      // Log sorting results
      developer.log(
        'Applied sort: ${_getSortDescription()}, documents count: ${docsToSort.length}',
        name: 'Dashboard',
      );

      // Debug log after sorting
      if (docsToSort.isNotEmpty) {
        developer.log(
          'After sorting: First 3 documents: ${docsToSort.take(3).map((doc) => doc['fileName']).join(", ")}',
          name: 'Dashboard',
        );
      }
    });
  }

  // Helper method to extract numeric value from timeAgo string for sorting
  int _extractNumericValue(String timeAgo) {
    // Extract numeric part from strings like "2 days ago", "5 hours ago"
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(timeAgo);
    if (match != null) {
      final value = int.tryParse(match.group(1) ?? '0') ?? 0;

      // Convert to comparable values (all in minutes)
      if (timeAgo.contains('day')) {
        return value * 24 * 60; // days to minutes
      } else if (timeAgo.contains('hour')) {
        return value * 60; // hours to minutes
      } else if (timeAgo.contains('minute')) {
        return value;
      }
    }
    return 0;
  }

  // Helper method to apply both filters and search
  void _applyFiltersAndSearch() {
    // If search is active, start with search results on all documents
    if (_isSearchActive) {
      _performSearch();

      // Then apply filters if needed
      if (_isFilterApplied) {
        _applyFilters();
      }
    }
    // Otherwise just apply filters if needed
    else if (_isFilterApplied) {
      _applyFilters();
    }
  }

  // Helper method to get the sort description
  String _getSortDescription() {
    switch (_currentSortOption) {
      case SortOption.newest:
        return 'Newest First';
      case SortOption.oldest:
        return 'Oldest First';
      case SortOption.nameAZ:
        return 'Name (A-Z)';
      case SortOption.nameZA:
        return 'Name (Z-A)';
      case SortOption.fileSize:
        return 'File Size';
      case SortOption.fileType:
        return 'File Type';
    }
  }

  // Toggle display style between grid and list
  void _toggleDisplayStyle() {
    setState(() {
      _currentDisplayStyle =
          _currentDisplayStyle == DisplayStyle.grid
              ? DisplayStyle.list
              : DisplayStyle.grid;
      _isDisplayStyleChanged = _currentDisplayStyle != DisplayStyle.grid;
    });
  }

  // Apply sort to a list of documents without updating state
  void _applyCurrentSort(List<Map<String, dynamic>> documents) {
    switch (_currentSortOption) {
      case SortOption.newest:
        // For newest first, sort by timestamp or timeAgo
        documents.sort((a, b) {
          // First try to compare using 'uploadedAt' timestamp if present
          final aUploadTime = a['timestamp'] as Timestamp?;
          final bUploadTime = b['timestamp'] as Timestamp?;

          if (aUploadTime != null && bUploadTime != null) {
            // Sort by timestamp (newest first)
            return bUploadTime.compareTo(aUploadTime);
          }

          // Fallback to timeAgo string comparison
          final timeA = a['timeAgo'] ?? '';
          final timeB = b['timeAgo'] ?? '';

          // Handle "Just now" case
          if (timeA == 'Just now') return -1; // a is newer
          if (timeB == 'Just now') return 1; // b is newer

          // Compare numerically for time-based strings
          final numA = _extractNumericValue(timeA);
          final numB = _extractNumericValue(timeB);

          return numA.compareTo(numB); // Smaller values are newer
        });
        break;

      case SortOption.oldest:
        documents.sort((a, b) {
          // First try to compare using timestamp if present
          final aUploadTime = a['timestamp'] as Timestamp?;
          final bUploadTime = b['timestamp'] as Timestamp?;

          if (aUploadTime != null && bUploadTime != null) {
            // Sort by timestamp (oldest first)
            return aUploadTime.compareTo(bUploadTime);
          }

          // Fallback to timeAgo string comparison
          final timeA = a['timeAgo'] ?? '';
          final timeB = b['timeAgo'] ?? '';

          // Handle "Just now" case
          if (timeA == 'Just now') return 1; // a is newer, so comes later
          if (timeB == 'Just now') return -1; // b is newer, so comes later

          // Compare numerically for time-based strings
          final numA = _extractNumericValue(timeA);
          final numB = _extractNumericValue(timeB);

          return numB.compareTo(numA); // Larger values are older
        });
        break;

      case SortOption.nameAZ:
        documents.sort((a, b) {
          final nameA = (a['fileName'] ?? '').toString().toLowerCase();
          final nameB = (b['fileName'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;

      case SortOption.nameZA:
        documents.sort((a, b) {
          final nameA = (a['fileName'] ?? '').toString().toLowerCase();
          final nameB = (b['fileName'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;

      case SortOption.fileSize:
        documents.sort((a, b) {
          final sizeA = a['bytes'] as int? ?? 0;
          final sizeB = b['bytes'] as int? ?? 0;
          return sizeB.compareTo(sizeA); // Largest first
        });
        break;

      case SortOption.fileType:
        documents.sort((a, b) {
          final typeA = (a['extension'] ?? '').toString().toLowerCase();
          final typeB = (b['extension'] ?? '').toString().toLowerCase();
          return typeA.compareTo(typeB);
        });
        break;
    }
  }

  // Method to manually refresh documents with current sorting applied
  void _refreshDocuments() {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator(color: orangeColor));
      },
    );

    // Apply current sort to existing documents without reloading from database
    if (_allDocuments.isNotEmpty && _isSortActive) {
      developer.log(
        'Reapplying sort ${_getSortDescription()} to existing documents without database reload',
        name: 'Dashboard',
      );

      // Apply the current sort option to the documents in memory
      _applySortOption(_currentSortOption);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documents sorted by ${_getSortDescription()}'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // For first load or if we need fresh data
      setState(() {
        _allDocuments = [];
        _filteredDocuments = [];
      });

      // Slight delay to ensure UI updates
      Future.delayed(Duration(milliseconds: 300), () {
        // Close loading dialog when done
        Navigator.of(context).pop();

        // Force state update to trigger document reload
        setState(() {});

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Documents refreshed with ${_getSortDescription()} sorting',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }
}
