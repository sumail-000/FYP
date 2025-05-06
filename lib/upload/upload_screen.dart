import 'package:flutter/material.dart';
import 'upload_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'recent_uploads_screen.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isUploading = false;
  List<DocumentItem> _selectedFiles = [];
  final UploadService _uploadService = UploadService();
  final Color orangeColor = Color(0xFFf06517);
  final Color blueColor = Color(0xFF2D6DA8);
  bool _showDetailsScreen = false;

  // Single flag for applying metadata to all documents
  bool _applyToAllDocuments = false;

  // Currently selected document index for editing
  int _activeDocumentIndex = 0;

  // Dropdown options
  final List<String> _documentTypes = ['PDF', 'PPT', 'PPTX', 'DOC', 'DOCX'];
  final List<String> _categories = [
    'Lecture',
    'Presentation',
    'Notes',
    'Handwritten Notes',
  ];
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
  List<String> _departments = [
    'IT (Arfa Karim)',
  ]; // Will be populated dynamically
  List<String> _courseCodes = [
    'CS-101',
    'IT-102',
  ]; // Will be populated dynamically
  List<String> _courses = [
    'SNA',
    'OOP',
    'DSA',
  ]; // Will be populated dynamically

  // Text controller for department input
  final TextEditingController _departmentController = TextEditingController();
  // Focus node to detect when user is done typing
  final FocusNode _departmentFocusNode = FocusNode();
  // Flag to show dropdown
  bool _showDepartmentDropdown = false;

  // Text controller and focus node for course
  final TextEditingController _courseController = TextEditingController();
  final FocusNode _courseFocusNode = FocusNode();
  bool _showCourseDropdown = false;

  // Text controller and focus node for course code
  final TextEditingController _courseCodeController = TextEditingController();
  final FocusNode _courseCodeFocusNode = FocusNode();
  bool _showCourseCodeDropdown = false;

  // Additional focus nodes for other fields
  final FocusNode _typeFieldFocusNode = FocusNode();
  final FocusNode _categoryFieldFocusNode = FocusNode();
  final FocusNode _semesterFieldFocusNode = FocusNode();
  final FocusNode _documentSelectionFocusNode = FocusNode();
  final FocusNode _documentNameFocusNode = FocusNode();

  // Flags for Type, Category, Semester, and Document selection dropdowns
  bool _showTypeDropdown = false;
  bool _showCategoryDropdown = false;
  bool _showSemesterDropdown = false;
  bool _showDocumentSelectionDropdown = false;

  // Add flag to prevent multiple calls
  bool _isAddingDepartment = false;
  bool _isAddingCourse = false;
  bool _isAddingCourseCode = false;

  @override
  void initState() {
    super.initState();
    // Load departments and course codes when the screen initializes with forced refresh
    _loadDepartments(forceRefresh: true);
    _loadCourses(forceRefresh: true);
    _loadCourseCodes(forceRefresh: true);

    // Add listener to department focus node
    _departmentFocusNode.addListener(() {
      if (!_departmentFocusNode.hasFocus) {
        // When field loses focus, add the new department if needed
        _addNewDepartmentIfNeeded();
      }
      // Force rebuild to update border color
      setState(() {});
    });

    // Add listener to course focus node
    _courseFocusNode.addListener(() {
      if (!_courseFocusNode.hasFocus) {
        // When field loses focus, add the new course if needed
        _addNewCourseIfNeeded();
      }
      // Force rebuild to update border color
      setState(() {});
    });

    // Add listener to course code focus node
    _courseCodeFocusNode.addListener(() {
      if (!_courseCodeFocusNode.hasFocus) {
        // When field loses focus, add the new course code if needed
        _addNewCourseCodeIfNeeded();
      }
      // Force rebuild to update border color
      setState(() {});
    });

    // Add listeners to additional focus nodes to force rebuild when focus changes
    _typeFieldFocusNode.addListener(() {
      setState(() {});
    });

    _categoryFieldFocusNode.addListener(() {
      setState(() {});
    });

    _semesterFieldFocusNode.addListener(() {
      setState(() {});
    });

    _documentSelectionFocusNode.addListener(() {
      setState(() {});
    });

    _documentNameFocusNode.addListener(() {
      setState(() {});
    });
  }

  // Load saved departments from UploadService
  Future<void> _loadDepartments({bool forceRefresh = false}) async {
    try {
      final departments =
          forceRefresh
              ? await _uploadService.refreshDepartments()
              : await _uploadService.getDepartments();

      setState(() {
        _departments = departments;
      });
    } catch (e) {
      print('Error loading departments: $e'); // Debug print
    }
  }

  // Load saved courses from UploadService
  Future<void> _loadCourses({bool forceRefresh = false}) async {
    try {
      final courses =
          forceRefresh
              ? await _uploadService.refreshCourses()
              : await _uploadService.getCourses();

      setState(() {
        _courses = courses;
      });
    } catch (e) {
      print('Error loading courses: $e'); // Debug print
    }
  }

  // Load saved course codes from UploadService
  Future<void> _loadCourseCodes({bool forceRefresh = false}) async {
    try {
      final courseCodes =
          forceRefresh
              ? await _uploadService.refreshCourseCodes()
              : await _uploadService.getCourseCodes();

      setState(() {
        _courseCodes = courseCodes;
      });
    } catch (e) {
      print('Error loading course codes: $e'); // Debug print
    }
  }

  @override
  void dispose() {
    // Dispose of text controllers and focus nodes
    _departmentController.dispose();
    _departmentFocusNode.dispose();
    _courseController.dispose();
    _courseFocusNode.dispose();
    _courseCodeController.dispose();
    _courseCodeFocusNode.dispose();

    // Dispose of additional focus nodes
    _typeFieldFocusNode.dispose();
    _categoryFieldFocusNode.dispose();
    _semesterFieldFocusNode.dispose();
    _documentSelectionFocusNode.dispose();
    _documentNameFocusNode.dispose();

    for (var doc in _selectedFiles) {
      doc.nameController.dispose();
      doc.courseCodeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final height = screenSize.height;

    // Create a custom dropdown button theme to ensure dropdowns appear below fields
    final customDropdownButtonTheme = Theme.of(context).copyWith(
      buttonTheme: ButtonThemeData(
        alignedDropdown: true, // This helps align the dropdown with the button
      ),
    );

    return Scaffold(
      backgroundColor: Color(0xFFE6E8EB),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _showDetailsScreen ? 'Document Details' : 'Upload Documents',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: blueColor,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_showDetailsScreen) {
              setState(() {
                _showDetailsScreen = false;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          // Document history icon
          IconButton(
            icon: Icon(Icons.history, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecentUploadsScreen()),
              );
            },
          ),
        ],
      ),
      // Wrap body with GestureDetector to close dropdowns when tapping outside
      body: GestureDetector(
        onTap: () {
          // Close all dropdowns when tapping outside
          setState(() {
            _showDepartmentDropdown = false;
            _showCourseDropdown = false;
            _showCourseCodeDropdown = false;
            _showTypeDropdown = false;
            _showCategoryDropdown = false;
            _showSemesterDropdown = false;
            _showDocumentSelectionDropdown = false;
          });
        },
        // Use behavior to ensure gesture detector captures all taps
        behavior: HitTestBehavior.translucent,
        child:
            _showDetailsScreen
                ? _buildDetailsScreen()
                : _buildSelectionScreen(height),
      ),
    );
  }

  // Document Selection Screen
  Widget _buildSelectionScreen(double height) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: height * 0.7,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cloud upload icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_upload, size: 60, color: blueColor),
                ),

                SizedBox(height: 20),

                // Upload a Document Text
                Text(
                  'Upload Documents',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                Column(
                  children: [
                    Text(
                      'Supported formats: PDF, DOC, DOCX, PPT, PPTX',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Maximum file size: 10MB per file (Cloudinary limit)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You can select up to 10 documents',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),

                SizedBox(height: 40),

                // Select Document button
                ElevatedButton.icon(
                  onPressed: _selectFiles,
                  icon: Icon(Icons.file_open),
                  label: Text(
                    'Select Documents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Document Details Screen
  Widget _buildDetailsScreen() {
    // Apply the custom dropdown theme to ensure dropdowns appear below fields
    return Theme(
      data: Theme.of(context).copyWith(
        buttonTheme: ButtonThemeData(
          alignedDropdown:
              true, // This forces dropdowns to align with their buttons
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Selected Documents Section with fixed height and scrolling
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Documents (${_selectedFiles.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  SizedBox(height: 10),

                  // Fixed height scrollable container for selected documents
                  Container(
                    height: 150, // Fixed height
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _selectedFiles.length,
                      itemBuilder:
                          (context, index) =>
                              _buildDocumentItem(_selectedFiles[index], index),
                    ),
                  ),
                ],
              ),
            ),

            // Resource Details Container
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: blueColor,
                          ),
                        ),
                      ),
                      // Global option to apply to all documents
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Apply to all',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            Checkbox(
                              value: _applyToAllDocuments,
                              activeColor: orangeColor,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (bool? value) {
                                setState(() {
                                  _applyToAllDocuments = value ?? false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  // Dropdown to select which document to edit
                  if (!_applyToAllDocuments && _selectedFiles.length > 1)
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      margin: EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black),
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
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: blueColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.edit_document,
                                  color: blueColor,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Select Document to Edit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    _documentSelectionFocusNode.hasFocus
                                        ? orangeColor
                                        : Colors.black,
                                width:
                                    _documentSelectionFocusNode.hasFocus
                                        ? 2
                                        : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Custom document selection field with dropdown
                                InkWell(
                                  focusNode: _documentSelectionFocusNode,
                                  onTap: () {
                                    // Toggle dropdown when tapping on field
                                    _documentSelectionFocusNode.requestFocus();
                                    setState(() {
                                      _showDocumentSelectionDropdown =
                                          !_showDocumentSelectionDropdown;

                                      // Close other dropdowns
                                      _showDepartmentDropdown = false;
                                      _showCourseDropdown = false;
                                      _showCourseCodeDropdown = false;
                                      _showTypeDropdown = false;
                                      _showCategoryDropdown = false;
                                      _showSemesterDropdown = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        // Icon for selected document
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: orangeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            _getIconForType(
                                              _selectedFiles[_activeDocumentIndex]
                                                  .fileName,
                                            ),
                                            color: orangeColor,
                                            size: 18,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        // Text for selected document
                                        Expanded(
                                          child: Text(
                                            _selectedFiles[_activeDocumentIndex]
                                                .nameController
                                                .text,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        // Dropdown arrow icon
                                        GestureDetector(
                                          onTap: () {
                                            // Toggle dropdown when clicking on suffix icon
                                            setState(() {
                                              _showDocumentSelectionDropdown =
                                                  !_showDocumentSelectionDropdown;

                                              // Close other dropdowns
                                              _showDepartmentDropdown = false;
                                              _showCourseDropdown = false;
                                              _showCourseCodeDropdown = false;
                                              _showTypeDropdown = false;
                                              _showCategoryDropdown = false;
                                              _showSemesterDropdown = false;
                                            });
                                          },
                                          child: Container(
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
                                      ],
                                    ),
                                  ),
                                ),

                                // Document selection dropdown
                                if (_showDocumentSelectionDropdown)
                                  Container(
                                    constraints: BoxConstraints(
                                      maxHeight: 156, // Show about 3 items
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        top: BorderSide(color: Colors.black),
                                      ),
                                    ),
                                    child: GestureDetector(
                                      // Prevent taps inside dropdown from closing it
                                      onTap: () {},
                                      behavior: HitTestBehavior.opaque,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _selectedFiles.length,
                                        itemBuilder: (context, index) {
                                          final fileName =
                                              _selectedFiles[index]
                                                  .nameController
                                                  .text;
                                          return ListTile(
                                            dense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 15,
                                                  vertical: 0,
                                                ),
                                            selected:
                                                _activeDocumentIndex == index,
                                            selectedTileColor: blueColor
                                                .withOpacity(0.1),
                                            leading: Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color:
                                                    _activeDocumentIndex ==
                                                            index
                                                        ? blueColor.withOpacity(
                                                          0.15,
                                                        )
                                                        : orangeColor
                                                            .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                boxShadow:
                                                    _activeDocumentIndex ==
                                                            index
                                                        ? [
                                                          BoxShadow(
                                                            color: blueColor
                                                                .withOpacity(
                                                                  0.15,
                                                                ),
                                                            blurRadius: 4,
                                                            offset: Offset(
                                                              0,
                                                              2,
                                                            ),
                                                          ),
                                                        ]
                                                        : [],
                                              ),
                                              child: Icon(
                                                _getIconForType(
                                                  _selectedFiles[index]
                                                      .fileName,
                                                ),
                                                color:
                                                    _activeDocumentIndex ==
                                                            index
                                                        ? blueColor
                                                        : orangeColor,
                                                size: 18,
                                              ),
                                            ),
                                            title: Text(
                                              fileName,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight:
                                                    _activeDocumentIndex ==
                                                            index
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 15,
                                                color:
                                                    _activeDocumentIndex ==
                                                            index
                                                        ? blueColor
                                                        : Colors.black87,
                                              ),
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _activeDocumentIndex = index;

                                                // Sync department controller with active document
                                                if (_selectedFiles.isNotEmpty) {
                                                  _departmentController.text =
                                                      _selectedFiles[_activeDocumentIndex]
                                                          .department ??
                                                      '';

                                                  // Also sync course controller
                                                  _courseController.text =
                                                      _selectedFiles[_activeDocumentIndex]
                                                          .course ??
                                                      '';

                                                  // Also sync course code controller
                                                  _courseCodeController.text =
                                                      _selectedFiles[_activeDocumentIndex]
                                                          .courseCodeController
                                                          .text;
                                                }

                                                _showDocumentSelectionDropdown =
                                                    false;
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
                        ],
                      ),
                    ),

                  SizedBox(height: 10),
                  Divider(),
                  SizedBox(height: 10),

                  // Document Information Part
                  Text(
                    'Document Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  SizedBox(height: 15),

                  // Document Name field - only show when not applying to all
                  if (!_applyToAllDocuments) ...[
                    Text(
                      'Document Name:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    TextField(
                      controller:
                          _selectedFiles.isNotEmpty
                              ? _selectedFiles[_activeDocumentIndex]
                                  .nameController
                              : TextEditingController(),
                      focusNode: _documentNameFocusNode,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: orangeColor, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        hintText: 'Enter document name',
                      ),
                    ),
                    SizedBox(height: 15),
                  ],

                  // Document Type
                  Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _typeFieldFocusNode.hasFocus
                                ? orangeColor
                                : Colors.black,
                        width: _typeFieldFocusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Custom type selection field with dropdown
                        InkWell(
                          focusNode: _typeFieldFocusNode,
                          onTap: () {
                            // Toggle dropdown when tapping on field
                            _typeFieldFocusNode.requestFocus();
                            setState(() {
                              _showTypeDropdown = !_showTypeDropdown;

                              // Close other dropdowns
                              _showDepartmentDropdown = false;
                              _showCourseDropdown = false;
                              _showCourseCodeDropdown = false;
                              _showCategoryDropdown = false;
                              _showSemesterDropdown = false;
                              _showDocumentSelectionDropdown = false;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                // Icon for selected type or placeholder
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: orangeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    _selectedFiles.isNotEmpty &&
                                            _selectedFiles[_activeDocumentIndex]
                                                    .type !=
                                                null
                                        ? _getIconForDocType(
                                          _selectedFiles[_activeDocumentIndex]
                                              .type,
                                        )
                                        : Icons.insert_drive_file,
                                    color: orangeColor,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 12),
                                // Text for selected type or placeholder
                                Expanded(
                                  child: Text(
                                    _selectedFiles.isNotEmpty &&
                                            _selectedFiles[_activeDocumentIndex]
                                                    .type !=
                                                null
                                        ? _selectedFiles[_activeDocumentIndex]
                                            .type!
                                        : 'Select Type',
                                    style: TextStyle(
                                      color:
                                          _selectedFiles.isNotEmpty &&
                                                  _selectedFiles[_activeDocumentIndex]
                                                          .type !=
                                                      null
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                // Dropdown arrow icon
                                GestureDetector(
                                  onTap: () {
                                    // Toggle dropdown when clicking on suffix icon
                                    setState(() {
                                      _showTypeDropdown = !_showTypeDropdown;

                                      // Close other dropdowns
                                      _showDepartmentDropdown = false;
                                      _showCourseDropdown = false;
                                      _showCourseCodeDropdown = false;
                                      _showCategoryDropdown = false;
                                      _showSemesterDropdown = false;
                                      _showDocumentSelectionDropdown = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: orangeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
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

                        // Document types dropdown
                        if (_showTypeDropdown)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 156, // Show about 3 items
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: GestureDetector(
                              // Prevent taps inside dropdown from closing it
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _documentTypes.length,
                                itemBuilder: (context, index) {
                                  final type = _documentTypes[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 0,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: orangeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        _getIconForDocType(type),
                                        color: orangeColor,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(type),
                                    onTap: () {
                                      // Set type and hide dropdown
                                      setState(() {
                                        if (_applyToAllDocuments) {
                                          // Apply to all documents
                                          for (var doc in _selectedFiles) {
                                            doc.type = type;
                                          }
                                        } else {
                                          // Apply only to active document
                                          _selectedFiles[_activeDocumentIndex]
                                              .type = type;
                                        }
                                        _showTypeDropdown = false;
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
                  SizedBox(height: 15),

                  // Category
                  Text(
                    'Category:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _categoryFieldFocusNode.hasFocus
                                ? orangeColor
                                : Colors.black,
                        width: _categoryFieldFocusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Custom category selection field with dropdown
                        InkWell(
                          focusNode: _categoryFieldFocusNode,
                          onTap: () {
                            // Toggle dropdown when tapping on field
                            _categoryFieldFocusNode.requestFocus();
                            setState(() {
                              _showCategoryDropdown = !_showCategoryDropdown;

                              // Close other dropdowns
                              _showDepartmentDropdown = false;
                              _showCourseDropdown = false;
                              _showCourseCodeDropdown = false;
                              _showTypeDropdown = false;
                              _showSemesterDropdown = false;
                              _showDocumentSelectionDropdown = false;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                // Icon for selected category or placeholder
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: orangeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(
                                      _selectedFiles.isNotEmpty
                                          ? _selectedFiles[_activeDocumentIndex]
                                              .category
                                          : null,
                                    ),
                                    color: orangeColor,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 12),
                                // Text for selected category or placeholder
                                Expanded(
                                  child: Text(
                                    _selectedFiles.isNotEmpty &&
                                            _selectedFiles[_activeDocumentIndex]
                                                    .category !=
                                                null
                                        ? _selectedFiles[_activeDocumentIndex]
                                            .category!
                                        : 'Select Category',
                                    style: TextStyle(
                                      color:
                                          _selectedFiles.isNotEmpty &&
                                                  _selectedFiles[_activeDocumentIndex]
                                                          .category !=
                                                      null
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                // Dropdown arrow icon
                                GestureDetector(
                                  onTap: () {
                                    // Toggle dropdown when clicking on suffix icon
                                    setState(() {
                                      _showCategoryDropdown =
                                          !_showCategoryDropdown;

                                      // Close other dropdowns
                                      _showDepartmentDropdown = false;
                                      _showCourseDropdown = false;
                                      _showCourseCodeDropdown = false;
                                      _showTypeDropdown = false;
                                      _showSemesterDropdown = false;
                                      _showDocumentSelectionDropdown = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: orangeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
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

                        // Categories dropdown
                        if (_showCategoryDropdown)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 156, // Show about 3 items
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: GestureDetector(
                              // Prevent taps inside dropdown from closing it
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 0,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: orangeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        _getCategoryIcon(category),
                                        color: orangeColor,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(category),
                                    onTap: () {
                                      // Set category and hide dropdown
                                      setState(() {
                                        if (_applyToAllDocuments) {
                                          // Apply to all documents
                                          for (var doc in _selectedFiles) {
                                            doc.category = category;
                                          }
                                        } else {
                                          // Apply only to active document
                                          _selectedFiles[_activeDocumentIndex]
                                              .category = category;
                                        }
                                        _showCategoryDropdown = false;
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
                  Divider(),
                  SizedBox(height: 10),

                  // Educational Information Part
                  Text(
                    'Educational Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  SizedBox(height: 15),

                  // Semester
                  Text(
                    'Semester:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _semesterFieldFocusNode.hasFocus
                                ? orangeColor
                                : Colors.black,
                        width: _semesterFieldFocusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Custom semester selection field with dropdown
                        InkWell(
                          focusNode: _semesterFieldFocusNode,
                          onTap: () {
                            // Toggle dropdown when tapping on field
                            _semesterFieldFocusNode.requestFocus();
                            setState(() {
                              _showSemesterDropdown = !_showSemesterDropdown;

                              // Close other dropdowns
                              _showDepartmentDropdown = false;
                              _showCourseDropdown = false;
                              _showCourseCodeDropdown = false;
                              _showTypeDropdown = false;
                              _showCategoryDropdown = false;
                              _showDocumentSelectionDropdown = false;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                // Icon for selected semester or placeholder
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: orangeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
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
                                    _selectedFiles.isNotEmpty &&
                                            _selectedFiles[_activeDocumentIndex]
                                                    .semester !=
                                                null
                                        ? _selectedFiles[_activeDocumentIndex]
                                            .semester!
                                        : 'Select Semester',
                                    style: TextStyle(
                                      color:
                                          _selectedFiles.isNotEmpty &&
                                                  _selectedFiles[_activeDocumentIndex]
                                                          .semester !=
                                                      null
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                // Dropdown arrow icon
                                GestureDetector(
                                  onTap: () {
                                    // Toggle dropdown when clicking on suffix icon
                                    setState(() {
                                      _showSemesterDropdown =
                                          !_showSemesterDropdown;

                                      // Close other dropdowns
                                      _showDepartmentDropdown = false;
                                      _showCourseDropdown = false;
                                      _showCourseCodeDropdown = false;
                                      _showTypeDropdown = false;
                                      _showCategoryDropdown = false;
                                      _showDocumentSelectionDropdown = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: orangeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
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
                              maxHeight: 156, // Show about 3 items
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: GestureDetector(
                              // Prevent taps inside dropdown from closing it
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _semesters.length,
                                itemBuilder: (context, index) {
                                  final semester = _semesters[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 0,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: orangeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
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
                                      setState(() {
                                        if (_applyToAllDocuments) {
                                          // Apply to all documents
                                          for (var doc in _selectedFiles) {
                                            doc.semester = semester;
                                          }
                                        } else {
                                          // Apply only to active document
                                          _selectedFiles[_activeDocumentIndex]
                                              .semester = semester;
                                        }
                                        _showSemesterDropdown = false;
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
                  SizedBox(height: 15),

                  // Department
                  Text(
                    'Department:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _departmentFocusNode.hasFocus
                                ? orangeColor
                                : Colors.black,
                        width: _departmentFocusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Custom department field with dropdown
                        TextField(
                          controller: _departmentController,
                          focusNode: _departmentFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search or add department',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                // Toggle dropdown when clicking on suffix icon
                                setState(() {
                                  _showDepartmentDropdown =
                                      !_showDepartmentDropdown;

                                  // Close other dropdowns
                                  _showCourseDropdown = false;
                                  _showCourseCodeDropdown = false;
                                });
                              },
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: orangeColor,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            // Update UI when text changes
                            setState(() {
                              // Update department for active document while typing
                              if (_selectedFiles.isNotEmpty) {
                                _selectedFiles[_activeDocumentIndex]
                                    .department = value;
                              }
                            });
                          },
                          // Show dropdown when clicked/focused
                          onTap: () {
                            // Refresh departments list to get latest data
                            _loadDepartments(forceRefresh: true);
                            // Toggle dropdown when tapping on field
                            setState(() {
                              _showDepartmentDropdown =
                                  !_showDepartmentDropdown;

                              // Close other dropdowns
                              _showCourseDropdown = false;
                              _showCourseCodeDropdown = false;
                            });
                          },
                          // Remove onEditingComplete to prevent double calls
                          // when Enter is pressed
                          onSubmitted: (value) {
                            _addNewDepartmentIfNeeded();
                          },
                        ),

                        // Filtered departments dropdown
                        if (_showDepartmentDropdown)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 156, // Show about 3 items
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: GestureDetector(
                              // Prevent taps inside dropdown from closing it
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _getFilteredDepartments().length,
                                itemBuilder: (context, index) {
                                  final dept = _getFilteredDepartments()[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 0,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: orangeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.school,
                                        color: orangeColor,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(dept),
                                    onTap: () {
                                      // Set department and hide dropdown
                                      setState(() {
                                        _departmentController.text = dept;
                                        if (_selectedFiles.isNotEmpty) {
                                          _selectedFiles[_activeDocumentIndex]
                                              .department = dept;
                                        }
                                        _showDepartmentDropdown = false;
                                      });
                                      _setDepartment(dept);
                                      _departmentFocusNode.unfocus();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Add helper text below the field, just like Course Code
                  Padding(
                    padding: EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      'Example: IT (Arfa Karim)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  SizedBox(height: 15),

                  // Course
                  Text(
                    'Course:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _courseFocusNode.hasFocus
                                ? orangeColor
                                : Colors.black,
                        width: _courseFocusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Course input field with dropdown
                        TextField(
                          controller: _courseController,
                          focusNode: _courseFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search or add course',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                // Toggle dropdown when clicking on suffix icon
                                setState(() {
                                  _showCourseDropdown = !_showCourseDropdown;

                                  // Close other dropdowns
                                  _showDepartmentDropdown = false;
                                  _showCourseCodeDropdown = false;
                                });
                              },
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: orangeColor,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            // Update UI when text changes
                            setState(() {
                              // Update course for active document while typing
                              if (_selectedFiles.isNotEmpty) {
                                _selectedFiles[_activeDocumentIndex].course =
                                    value;

                                // Apply to all documents if flag is set
                                if (_applyToAllDocuments) {
                                  for (var doc in _selectedFiles) {
                                    doc.course = value;
                                  }
                                }
                              }
                            });
                          },
                          // Show dropdown when clicked/focused
                          onTap: () {
                            // Refresh courses list to get latest data
                            _loadCourses(forceRefresh: true);
                            // Toggle dropdown when tapping on field
                            setState(() {
                              _showCourseDropdown = !_showCourseDropdown;

                              // Close other dropdowns
                              _showDepartmentDropdown = false;
                              _showCourseCodeDropdown = false;
                            });
                          },
                          onSubmitted: (value) {
                            _addNewCourseIfNeeded();
                          },
                        ),

                        // Filtered courses dropdown
                        if (_showCourseDropdown)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 156, // Show about 3 items
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: GestureDetector(
                              // Prevent taps inside dropdown from closing it
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _getFilteredCourses().length,
                                itemBuilder: (context, index) {
                                  final course = _getFilteredCourses()[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 0,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: orangeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.book,
                                        color: orangeColor,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(course),
                                    onTap: () {
                                      // Set course and hide dropdown
                                      setState(() {
                                        _courseController.text = course;
                                        if (_selectedFiles.isNotEmpty) {
                                          _selectedFiles[_activeDocumentIndex]
                                              .course = course;

                                          // Apply to all documents if flag is set
                                          if (_applyToAllDocuments) {
                                            for (var doc in _selectedFiles) {
                                              doc.course = course;
                                            }
                                          }
                                        }
                                        _showCourseDropdown = false;
                                      });
                                      _setCourse(course);
                                      _courseFocusNode.unfocus();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Add helper text below the field
                  Padding(
                    padding: EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      'Examples: SNA, OOP, DSA',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  SizedBox(height: 15),

                  // Course Code
                  Text(
                    'Course Code:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _courseCodeFocusNode.hasFocus
                                ? orangeColor
                                : Colors.black,
                        width: _courseCodeFocusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Course code input field with dropdown
                        TextField(
                          controller: _courseCodeController,
                          focusNode: _courseCodeFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search or add course code',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                // Toggle dropdown when clicking on suffix icon
                                setState(() {
                                  _showCourseCodeDropdown =
                                      !_showCourseCodeDropdown;

                                  // Close other dropdowns
                                  _showDepartmentDropdown = false;
                                  _showCourseDropdown = false;
                                });
                              },
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: orangeColor,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            // Update UI when text changes
                            setState(() {
                              // Update course code for active document while typing
                              if (_selectedFiles.isNotEmpty) {
                                _selectedFiles[_activeDocumentIndex]
                                    .courseCodeController
                                    .text = value;

                                // Apply to all documents if flag is set
                                if (_applyToAllDocuments) {
                                  for (var doc in _selectedFiles) {
                                    doc.courseCodeController.text = value;
                                  }
                                }
                              }
                            });
                          },
                          // Show dropdown when clicked/focused
                          onTap: () {
                            // Refresh course codes list to get latest data
                            _loadCourseCodes(forceRefresh: true);
                            // Toggle dropdown when tapping on field
                            setState(() {
                              _showCourseCodeDropdown =
                                  !_showCourseCodeDropdown;

                              // Close other dropdowns
                              _showDepartmentDropdown = false;
                              _showCourseDropdown = false;
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
                              maxHeight: 156, // Show about 3 items
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.black),
                              ),
                            ),
                            child: GestureDetector(
                              // Prevent taps inside dropdown from closing it
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _getFilteredCourseCodes().length,
                                itemBuilder: (context, index) {
                                  final code = _getFilteredCourseCodes()[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 0,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: orangeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.class_,
                                        color: orangeColor,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(code),
                                    onTap: () {
                                      // Set course code and hide dropdown
                                      setState(() {
                                        _courseCodeController.text = code;
                                        if (_selectedFiles.isNotEmpty) {
                                          _selectedFiles[_activeDocumentIndex]
                                              .courseCodeController
                                              .text = code;

                                          // Apply to all documents if flag is set
                                          if (_applyToAllDocuments) {
                                            for (var doc in _selectedFiles) {
                                              doc.courseCodeController.text =
                                                  code;
                                            }
                                          }
                                        }
                                        _showCourseCodeDropdown = false;
                                      });
                                      _courseCodeFocusNode.unfocus();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Add helper text below the field
                  Padding(
                    padding: EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      'Examples: CS-101, IT-102',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // Upload button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : () => _uploadFiles(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isUploading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                            'Upload Documents',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Build a single document item in the list
  Widget _buildDocumentItem(DocumentItem doc, int index) {
    // Format file size to human-readable format
    String fileSize = '';
    if (doc.size != null) {
      if (doc.size! < 1024) {
        fileSize = '${doc.size} B';
      } else if (doc.size! < 1024 * 1024) {
        fileSize = '${(doc.size! / 1024).toStringAsFixed(1)} KB';
      } else {
        fileSize = '${(doc.size! / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            _activeDocumentIndex == index
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _activeDocumentIndex == index ? blueColor : Colors.black,
        ),
      ),
      child: Row(
        children: [
          // Document icon based on type
          Icon(_getIconForType(doc.fileName), color: orangeColor, size: 24),
          SizedBox(width: 12),

          // Document name field (editable) and size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: doc.nameController,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    hintText: 'Document name',
                  ),
                ),
                if (fileSize.isNotEmpty)
                  Text(
                    fileSize,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),

          // Select button for editing this document's metadata
          if (!_applyToAllDocuments && _selectedFiles.length > 1)
            TextButton(
              onPressed: () {
                setState(() {
                  _activeDocumentIndex = index;
                });
              },
              child: Text(
                _activeDocumentIndex == index ? 'Editing' : 'Edit',
                style: TextStyle(
                  color:
                      _activeDocumentIndex == index
                          ? blueColor
                          : Colors.grey[700],
                  fontWeight:
                      _activeDocumentIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),

          // Remove button
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
              setState(() {
                _selectedFiles.remove(doc);
                if (_selectedFiles.isEmpty) {
                  // If all files removed, go back to selection screen
                  _showDetailsScreen = false;
                } else if (_activeDocumentIndex >= _selectedFiles.length) {
                  // Adjust active index if needed
                  _activeDocumentIndex = _selectedFiles.length - 1;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // Get appropriate icon for file type
  IconData _getIconForType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.description;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow;
    } else {
      return Icons.insert_drive_file;
    }
  }

  // Automatic file type detection
  String? _detectFileType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      return 'PDF';
    } else if (extension == 'doc') {
      return 'DOC';
    } else if (extension == 'docx') {
      return 'DOCX';
    } else if (extension == 'ppt') {
      return 'PPT';
    } else if (extension == 'pptx') {
      return 'PPTX';
    }

    return null;
  }

  void _selectFiles() async {
    try {
      // Use file_picker to select multiple files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type:
            FileType
                .any, // Change to allow any file type, we'll handle validation ourselves
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Validate all files before proceeding
        List<PlatformFile> validFiles = [];
        List<String> errorMessages = [];

        // Maximum file size (10MB in bytes) - Cloudinary free tier limit
        const int maxFileSize = 10 * 1024 * 1024;

        // Valid extensions
        final List<String> validExtensions = [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
        ];

        // Check each file for validity
        for (var file in result.files) {
          // Check file extension
          final String extension = file.extension?.toLowerCase() ?? '';
          bool isValidExtension = validExtensions.contains(extension);

          // Check file size
          bool isValidSize = file.size <= maxFileSize;

          if (!isValidExtension) {
            errorMessages.add(
              '${file.name}: Unsupported file format. Only PDF, DOC, DOCX, PPT, PPTX are supported.',
            );
          } else if (!isValidSize) {
            errorMessages.add(
              '${file.name}: File exceeds 10MB Cloudinary limit (${(file.size / (1024 * 1024)).toStringAsFixed(1)}MB).',
            );
          } else {
            validFiles.add(file);
          }
        }

        // Check if we have too many files
        if (validFiles.length > 10) {
          errorMessages.add(
            'Too many files selected. Only the first 10 valid files will be processed.',
          );
          // Only process the first 10 files
          validFiles = validFiles.sublist(0, 10);
        }

        // Show error messages if any
        if (errorMessages.isNotEmpty) {
          // Process error messages to consolidate file format errors
          List<String> processedErrorMessages = [];
          bool hasFormatError = false;

          // Check for format errors
          for (String message in errorMessages) {
            if (message.contains('Unsupported file format')) {
              hasFormatError = true;
            } else {
              processedErrorMessages.add(message);
            }
          }

          // Use a dialog for better error presentation with multiple file errors
          showDialog(
            context: context,
            builder: (BuildContext context) {
              // Get screen size to calculate dynamic constraints
              final screenSize = MediaQuery.of(context).size;
              final double maxDialogHeight =
                  screenSize.height * 0.4; // 40% of screen height
              final double maxDialogWidth = min(
                500.0,
                screenSize.width * 0.9,
              ); // Either 500 or 90% of width

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
                backgroundColor: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxDialogHeight,
                    maxWidth: maxDialogWidth,
                  ),
                  child: Container(
                    width: maxDialogWidth,
                    // Remove fixed height constraint to prevent overflow
                    padding: EdgeInsets.all(
                      16,
                    ), // Reduced padding for smaller screens
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min, // Important to prevent full-screen dialog
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  6,
                                ), // Smaller padding for smaller screens
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20, // Smaller icon for smaller screens
                                ),
                              ),
                              SizedBox(width: 8), // Reduced spacing
                              Expanded(
                                child: Text(
                                  'File Selection Issues',
                                  style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        16, // Smaller font for smaller screens
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12), // Reduced spacing
                          Divider(height: 1, color: Colors.grey[300]),
                          SizedBox(height: 12), // Reduced spacing
                          // Format reminder if needed
                          if (hasFormatError)
                            Container(
                              padding: EdgeInsets.all(8), // Reduced padding
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: blueColor,
                                    size: 16,
                                  ), // Smaller icon
                                  SizedBox(width: 6), // Reduced spacing
                                  Expanded(
                                    child: Text(
                                      'Only PDF, DOC, DOCX, PPT, and PPTX files are supported.',
                                      style: TextStyle(
                                        fontSize: 12, // Smaller font
                                        color: blueColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (hasFormatError)
                            SizedBox(height: 12), // Reduced spacing
                          // Instruction text
                          Text(
                            processedErrorMessages.isNotEmpty
                                ? 'The following issues were found:'
                                : 'Some files were skipped due to unsupported formats.',
                            style: TextStyle(
                              fontSize: 13, // Smaller font
                              color: Colors.grey[700],
                            ),
                          ),

                          // Error messages list in scrollable container
                          if (processedErrorMessages.isNotEmpty) ...[
                            SizedBox(height: 8), // Reduced spacing
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children:
                                      processedErrorMessages
                                          .map(
                                            (message) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8.0,
                                              ), // Reduced spacing
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                      top: 3,
                                                    ),
                                                    height: 5, // Smaller bullet
                                                    width: 5, // Smaller bullet
                                                    decoration: BoxDecoration(
                                                      color: orangeColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 6,
                                                  ), // Reduced spacing
                                                  Expanded(
                                                    child: Text(
                                                      message,
                                                      style: TextStyle(
                                                        fontSize:
                                                            13, // Smaller font
                                                        color: Colors.grey[800],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: 12), // Reduced spacing
                          Divider(height: 1, color: Colors.grey[300]),
                          SizedBox(height: 12), // Reduced spacing
                          // OK button
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orangeColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ), // Reduced padding
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'OK',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, // Smaller font
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Only proceed if we have valid files
        if (validFiles.isNotEmpty) {
          // Convert file picker results to DocumentItem objects
          List<DocumentItem> newFiles =
              validFiles.map((file) {
                final docItem = DocumentItem.fromPlatformFile(file);

                // Auto-detect document type from file extension
                docItem.type = _detectFileType(file.name);

                return docItem;
              }).toList();

          setState(() {
            _selectedFiles = newFiles;
            _showDetailsScreen = true;
            _activeDocumentIndex = 0;

            // Initialize controllers with active document values
            if (_selectedFiles.isNotEmpty) {
              _departmentController.text =
                  _selectedFiles[_activeDocumentIndex].department ?? '';
              _courseController.text =
                  _selectedFiles[_activeDocumentIndex].course ?? '';
              _courseCodeController.text =
                  _selectedFiles[_activeDocumentIndex]
                      .courseCodeController
                      .text;
            }
          });
        } else {
          // No valid files to proceed with
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No valid files to upload. Please select valid documents.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // User canceled the picker
        print('File selection canceled by user');
      }
    } catch (e) {
      // Handle errors
      print('Error selecting files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Set department and update related fields
  void _setDepartment(String department) {
    setState(() {
      _departmentController.text = department;

      if (_selectedFiles.isNotEmpty) {
        final previousDepartment =
            _selectedFiles[_activeDocumentIndex].department;
        _selectedFiles[_activeDocumentIndex].department = department;

        // Apply to all documents if flag is set
        if (_applyToAllDocuments) {
          for (var doc in _selectedFiles) {
            doc.department = department;
          }
        }

        // If department changed, check if we need to update course code
        if (previousDepartment != department &&
            _selectedFiles[_activeDocumentIndex].course != null) {
          _updateCourseCodeForDepartmentAndCourse(
            department,
            _selectedFiles[_activeDocumentIndex].course!,
          );
        }
      }
    });
  }

  // Set course and update related fields
  void _setCourse(String course) {
    setState(() {
      _courseController.text = course;

      if (_selectedFiles.isNotEmpty) {
        _selectedFiles[_activeDocumentIndex].course = course;

        // Apply to all documents if flag is set
        if (_applyToAllDocuments) {
          for (var doc in _selectedFiles) {
            doc.course = course;
          }
        }

        // Try to find and set course code automatically
        if (_selectedFiles[_activeDocumentIndex].department != null) {
          _updateCourseCodeForDepartmentAndCourse(
            _selectedFiles[_activeDocumentIndex].department!,
            course,
          );
        }
      }
    });
  }

  // Auto-update course code based on department and course
  Future<void> _updateCourseCodeForDepartmentAndCourse(
    String department,
    String course,
  ) async {
    try {
      final courseCode = await _uploadService
          .getCourseCodeForDepartmentAndCourse(department, course);

      if (courseCode != null && courseCode.isNotEmpty) {
        setState(() {
          _courseCodeController.text = courseCode;

          if (_selectedFiles.isNotEmpty) {
            _selectedFiles[_activeDocumentIndex].courseCodeController.text =
                courseCode;

            // Apply to all documents with same department and course
            if (_applyToAllDocuments) {
              for (var doc in _selectedFiles) {
                if (doc.department == department && doc.course == course) {
                  doc.courseCodeController.text = courseCode;
                }
              }
            }
          }
        });

        // Show feedback to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course code automatically set to $courseCode'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error getting course code for $department/$course: $e');
    }
  }

  // Upload button
  void _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    // Validate required fields before upload
    List<String> missingFields = [];
    bool hasValidationErrors = false;

    // Check if all documents have required metadata
    for (int i = 0; i < _selectedFiles.length; i++) {
      final doc = _selectedFiles[i];

      // Required fields validation
      if (doc.nameController.text.trim().isEmpty) {
        missingFields.add('Document name for ${i + 1}');
        hasValidationErrors = true;
      }

      if (doc.type == null) {
        missingFields.add('Document type for ${doc.nameController.text}');
        hasValidationErrors = true;
      }

      if (doc.category == null) {
        missingFields.add('Category for ${doc.nameController.text}');
        hasValidationErrors = true;
      }

      if (doc.semester == null) {
        missingFields.add('Semester for ${doc.nameController.text}');
        hasValidationErrors = true;
      }

      if (doc.department == null || doc.department!.isEmpty) {
        missingFields.add('Department for ${doc.nameController.text}');
        hasValidationErrors = true;
      }

      if (doc.course == null || doc.course!.isEmpty) {
        missingFields.add('Course for ${doc.nameController.text}');
        hasValidationErrors = true;
      }

      if (doc.courseCodeController.text.trim().isEmpty) {
        missingFields.add('Course code for ${doc.nameController.text}');
        hasValidationErrors = true;
      }
    }

    // Show validation errors if any
    if (hasValidationErrors) {
      // Display a dialog with missing fields
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Missing Information'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Please fill in the following required fields:'),
                    SizedBox(height: 10),
                    Container(
                      height: min(200, missingFields.length * 24.0),
                      child: ListView(
                        shrinkWrap: true,
                        children:
                            missingFields
                                .map(
                                  (field) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(child: Text(field)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                  style: TextButton.styleFrom(foregroundColor: blueColor),
                ),
              ],
            ),
      );
      return;
    }

    // Prepare uploads data for the progress screen
    final uploads =
        _selectedFiles.map((doc) {
          return {
            'filePath': doc.path!,
            'displayName': doc.nameController.text.trim(),
            'documentType': doc.type,
            'category': doc.category,
            'semester': doc.semester,
            'department': doc.department,
            'course': doc.course,
            'courseCode': doc.courseCodeController.text.trim(),
          };
        }).toList();

    // Show upload progress screen and handle uploads
    try {
      final success = await _uploadService.uploadFiles(context, uploads);

      if (success) {
        // After successful upload, navigate back to dashboard
        Navigator.pop(context);
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get file extension from filename
  String _getFileExtension(String fileName) {
    return fileName.split('.').last;
  }

  // Get icon based on document type (from dropdown selection)
  IconData _getIconForDocType(String? docType) {
    if (docType == null) return Icons.insert_drive_file;

    switch (docType.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Get icon based on category
  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.article;

    switch (category) {
      case 'Lecture':
        return Icons.mic;
      case 'Presentation':
        return Icons.slideshow;
      case 'Notes':
        return Icons.note;
      case 'Handwritten Notes':
        return Icons.edit_note;
      default:
        return Icons.article;
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

  // Get filtered courses based on the search text
  List<String> _getFilteredCourses() {
    final searchText = _courseController.text.toLowerCase();
    if (searchText.isEmpty) {
      // Return all courses if no search text
      return _courses;
    }

    // Filter courses that contain the search text
    return _courses
        .where((course) => course.toLowerCase().contains(searchText))
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
      print(
        'Already adding department, ignoring duplicate call',
      ); // Debug print
      return;
    }

    // Set flag to indicate we're in the process of adding
    _isAddingDepartment = true;

    try {
      // Get text from controller and trim whitespace
      final departmentText = _departmentController.text.trim();
      print('Department text submitted: "$departmentText"'); // Debug print

      if (departmentText.isEmpty) {
        setState(() {
          _showDepartmentDropdown = false;
        });
        return;
      }

      // First refresh the departments list to get the latest data
      await _loadDepartments(forceRefresh: true);

      // Check if department is in the list
      if (!_departments.contains(departmentText)) {
        print('Adding new department: $departmentText'); // Debug print
        // Add department to Firebase
        final success = await _uploadService.addDepartment(departmentText);

        if (success) {
          print('Department added successfully, reloading list'); // Debug print
          // Reload departments list with forced refresh
          await _loadDepartments(forceRefresh: true);

          // Update department for active document
          if (_selectedFiles.isNotEmpty) {
            setState(() {
              _selectedFiles[_activeDocumentIndex].department = departmentText;
            });
          }
        } else {
          print('Failed to add department'); // Debug print
        }
      } else {
        print('Department already in list: $departmentText'); // Debug print
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

  // Add method for adding a new course code
  Future<void> _addNewCourseCodeIfNeeded() async {
    // Prevent multiple simultaneous calls
    if (_isAddingCourseCode) {
      print(
        'Already adding course code, ignoring duplicate call',
      ); // Debug print
      return;
    }

    // Set flag to indicate we're in the process of adding
    _isAddingCourseCode = true;

    try {
      // Get text from controller and trim whitespace
      final courseCodeText = _courseCodeController.text.trim();
      print('Course code text submitted: "$courseCodeText"'); // Debug print

      if (courseCodeText.isEmpty) {
        setState(() {
          _showCourseCodeDropdown = false;
        });
        return;
      }

      // First refresh the course codes list to get the latest data
      await _loadCourseCodes(forceRefresh: true);

      // Check if course code is in the list
      if (!_courseCodes.contains(courseCodeText)) {
        print('Adding new course code: $courseCodeText'); // Debug print
        // Add course code to Firebase
        final success = await _uploadService.addCourseCode(courseCodeText);

        if (success) {
          print(
            'Course code added successfully, reloading list',
          ); // Debug print
          // Reload course codes list with forced refresh
          await _loadCourseCodes(forceRefresh: true);

          // Update course code for active document
          if (_selectedFiles.isNotEmpty) {
            setState(() {
              _selectedFiles[_activeDocumentIndex].courseCodeController.text =
                  courseCodeText;

              // Apply to all documents if flag is set
              if (_applyToAllDocuments) {
                for (var doc in _selectedFiles) {
                  doc.courseCodeController.text = courseCodeText;
                }
              }
            });
          }
        } else {
          print('Failed to add course code'); // Debug print
        }
      } else {
        print('Course code already in list: $courseCodeText'); // Debug print
      }

      // Hide dropdown
      setState(() {
        _showCourseCodeDropdown = false;
      });
    } finally {
      // Reset flag when done, regardless of success or failure
      _isAddingCourseCode = false;
    }
  }

  // Add method for adding a new course
  Future<void> _addNewCourseIfNeeded() async {
    // Prevent multiple simultaneous calls
    if (_isAddingCourse) {
      print('Already adding course, ignoring duplicate call'); // Debug print
      return;
    }

    // Set flag to indicate we're in the process of adding
    _isAddingCourse = true;

    try {
      // Get text from controller and trim whitespace
      final courseText = _courseController.text.trim();
      print('Course text submitted: "$courseText"'); // Debug print

      if (courseText.isEmpty) {
        setState(() {
          _showCourseDropdown = false;
        });
        return;
      }

      // First refresh the courses list to get the latest data
      await _loadCourses(forceRefresh: true);

      // Check if course is in the list
      if (!_courses.contains(courseText)) {
        print('Adding new course: $courseText'); // Debug print
        // Add course to Firebase
        final success = await _uploadService.addCourse(courseText);

        if (success) {
          print('Course added successfully, reloading list'); // Debug print
          // Reload courses list with forced refresh
          await _loadCourses(forceRefresh: true);

          // Update course for active document
          if (_selectedFiles.isNotEmpty) {
            setState(() {
              _selectedFiles[_activeDocumentIndex].course = courseText;

              // Apply to all documents if flag is set
              if (_applyToAllDocuments) {
                for (var doc in _selectedFiles) {
                  doc.course = courseText;
                }
              }
            });
          }
        } else {
          print('Failed to add course'); // Debug print
        }
      } else {
        print('Course already in list: $courseText'); // Debug print
      }

      // Hide dropdown
      setState(() {
        _showCourseDropdown = false;
      });
    } finally {
      // Reset flag when done, regardless of success or failure
      _isAddingCourse = false;
    }
  }
}

// Document item class to hold all data for a single document
class DocumentItem {
  String fileName;
  TextEditingController nameController;
  TextEditingController courseCodeController;
  String? type;
  String? category;
  String? semester;
  String? department;
  String? course;

  // New fields for actual file
  PlatformFile? platformFile;
  File? file;
  String? path;
  int? size;

  DocumentItem({
    required this.fileName,
    required this.nameController,
    required this.courseCodeController,
    this.type,
    this.category,
    this.semester,
    this.department = 'IT (Arfa Karim)',
    this.course,
    this.platformFile,
    this.file,
    this.path,
    this.size,
  });

  // Factory constructor to create from PlatformFile
  factory DocumentItem.fromPlatformFile(PlatformFile platformFile) {
    String fileName = platformFile.name;
    String nameWithoutExtension = fileName.split('.').first;

    return DocumentItem(
      fileName: fileName,
      nameController: TextEditingController(text: nameWithoutExtension),
      courseCodeController: TextEditingController(),
      platformFile: platformFile,
      path: platformFile.path,
      size: platformFile.size,
      file: platformFile.path != null ? File(platformFile.path!) : null,
    );
  }
}
