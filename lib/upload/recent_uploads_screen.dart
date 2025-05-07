import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'upload_service.dart';

class RecentUploadsScreen extends StatefulWidget {
  @override
  _RecentUploadsScreenState createState() => _RecentUploadsScreenState();
}

class _RecentUploadsScreenState extends State<RecentUploadsScreen> {
  final UploadService _uploadService = UploadService();
  final Color blueColor = Color(0xFF2D6DA8);
  final Color orangeColor = Color(0xFFf06517);

  bool _isLoading = true;
  bool _isRefreshing = false;
  List<DocumentSnapshot> _documents = [];
  List<DocumentSnapshot> _filteredDocuments = [];
  String? _errorMessage;

  // Controller for refresh indicator
  final ScrollController _scrollController = ScrollController();

  // Search text controller
  final TextEditingController _searchController = TextEditingController();

  // Flag for search mode
  bool _isSearchMode = false;

  // Enhanced state variables for filtering
  String _selectedDocumentType = 'All';
  String _selectedCourse = 'All';
  bool _isFilterActive = false;
  List<String> _documentTypes = ['All'];
  List<String> _courses = ['All'];

  @override
  void initState() {
    super.initState();
    _loadRecentDocuments();

    // Add listener to search controller
    _searchController.addListener(() {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentDocuments() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      print('Loading user\'s uploaded documents...');
      final documents = await _uploadService.getRecentDocuments();
      print('Loaded ${documents.length} user documents');
      
      setState(() {
        _documents = documents;
        _isLoading = false;
        _isRefreshing = false;
      });

      // Extract filter categories and apply filters
      _extractFilterCategories();
      _applyFilters();
    } catch (e) {
      print('Error loading user documents: $e');
      setState(() {
        _errorMessage = 'Failed to load documents: $e';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // Apply all filters and search criteria
  void _applyFilters() {
    setState(() {
      if (_documents.isEmpty) {
        _filteredDocuments = [];
        return;
      }

      // Start with all documents
      List<DocumentSnapshot> filtered = List.from(_documents);

      // Apply document type filter if not "All"
      if (_selectedDocumentType != 'All') {
        filtered =
            filtered.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final docType =
                  data['documentType'] ?? data['format']?.toString() ?? '';
              return docType.toLowerCase() ==
                  _selectedDocumentType.toLowerCase();
            }).toList();
      }

      // Apply course filter if not "All"
      if (_selectedCourse != 'All') {
        filtered =
            filtered.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final courseCode = data['courseCode'] ?? '';
              return courseCode == _selectedCourse;
            }).toList();
      }

      // Apply search text filter
      final searchText = _searchController.text;
      if (searchText.isNotEmpty) {
        filtered =
            filtered.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // Search in different fields
              final fileName = data['fileName'] ?? data['displayName'] ?? '';
              final courseCode = data['courseCode'] ?? '';
              final department = data['department'] ?? '';
              final course = data['course'] ?? '';
              final docType =
                  data['documentType'] ?? data['format']?.toString() ?? '';

              // Combine all searchable fields
              final searchableText =
                  '$fileName $courseCode $department $course $docType'
                      .toLowerCase();

              // Check if any part of the searchableText contains the query
              return searchableText.contains(searchText.toLowerCase());
            }).toList();
      }

      _filteredDocuments = filtered;
    });
  }

  // Extract unique document types and courses from documents
  void _extractFilterCategories() {
    Set<String> docTypes = {'All'};
    Set<String> courses = {'All'};

    for (var doc in _documents) {
      final data = doc.data() as Map<String, dynamic>;

      // Extract document type
      final docType = data['documentType'] ?? data['format']?.toString() ?? '';
      if (docType.isNotEmpty) {
        docTypes.add(docType);
      }

      // Extract course code
      final courseCode = data['courseCode'] ?? '';
      if (courseCode.isNotEmpty) {
        courses.add(courseCode);
      }
    }

    setState(() {
      _documentTypes = docTypes.toList()..sort();
      _courses = courses.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title:
            _isSearchMode
                ? TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search uploads...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _isSearchMode = false;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                  autofocus: true,
                )
                : Text(
                  'My Uploads',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        backgroundColor: blueColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Search button
          if (!_isSearchMode)
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearchMode = true;
                });
              },
            ),

          // Filter button
          if (!_isSearchMode)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showFilterOptions,
                ),
                if (_isFilterActive)
                  Positioned(
                    top: 8,
                    right: 8,
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

          // Refresh button
          if (!_isSearchMode)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _isRefreshing ? null : _loadRecentDocuments,
            ),

          // Sort button
          if (!_isSearchMode)
            IconButton(
              icon: Icon(Icons.sort, color: Colors.white),
              onPressed: _showSortOptions,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(blueColor),
            ),
            SizedBox(height: 16),
            Text(
              'Loading documents...',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 48,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRecentDocuments,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: blueColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file, color: blueColor, size: 64),
            ),
            SizedBox(height: 24),
            Text(
              'You haven\'t uploaded any documents yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Documents you upload will appear here for easy management',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.add),
              label: Text('Upload Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: orangeColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Check if search has no results
    if (_filteredDocuments.isEmpty && _isSearchMode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, color: Colors.grey[600], size: 40),
            ),
            SizedBox(height: 24),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Try using different keywords or filters',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadRecentDocuments();
      },
      color: blueColor,
      backgroundColor: Colors.white,
      displacement: 40,
      child: CustomScrollView(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          // Optional header with document count
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_filteredDocuments.length} ${_filteredDocuments.length == 1 ? 'Document' : 'Documents'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Spacer(),
                      if (_isRefreshing)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              blueColor,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Show active filters
                  if (_isFilterActive) ...[
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_selectedDocumentType != 'All')
                            Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(_selectedDocumentType),
                                backgroundColor: blueColor.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: blueColor,
                                  fontSize: 12,
                                ),
                                deleteIcon: Icon(Icons.close, size: 16),
                                deleteIconColor: blueColor,
                                onDeleted: () {
                                  setState(() {
                                    _selectedDocumentType = 'All';
                                    _isFilterActive = _selectedCourse != 'All';
                                  });
                                  _applyFilters();
                                },
                              ),
                            ),
                          if (_selectedCourse != 'All')
                            Chip(
                              label: Text(_selectedCourse),
                              backgroundColor: blueColor.withOpacity(0.1),
                              labelStyle: TextStyle(
                                color: blueColor,
                                fontSize: 12,
                              ),
                              deleteIcon: Icon(Icons.close, size: 16),
                              deleteIconColor: blueColor,
                              onDeleted: () {
                                setState(() {
                                  _selectedCourse = 'All';
                                  _isFilterActive =
                                      _selectedDocumentType != 'All';
                                });
                                _applyFilters();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // List of documents
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final doc = _filteredDocuments[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildDocumentCard(data, doc.id);
            }, childCount: _filteredDocuments.length),
          ),

          // Bottom padding
          SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> data, String documentId) {
    // Extract data with fallbacks
    final String fileName =
        data['fileName'] ?? data['displayName'] ?? 'Unnamed Document';
    final String courseCode = data['courseCode'] ?? 'Unknown Course';
    final int bytes = (data['bytes'] as num?)?.toInt() ?? 0;

    // Handle different timestamp formats
    Timestamp? timestamp;
    if (data['uploadedAt'] != null) {
      if (data['uploadedAt'] is Timestamp) {
        timestamp = data['uploadedAt'] as Timestamp;
      } else if (data['uploadedAt'] is int) {
        // Convert milliseconds timestamp to Timestamp
        timestamp = Timestamp.fromMillisecondsSinceEpoch(data['uploadedAt']);
      } else if (data['uploadedAt'] is String) {
        try {
          // Try parsing ISO date string
          final dateTime = DateTime.parse(data['uploadedAt']);
          timestamp = Timestamp.fromDate(dateTime);
        } catch (e) {
          print('Error parsing date string: ${data['uploadedAt']}');
        }
      }
    }

    // If uploadedAt is not available, try createdAt
    if (timestamp == null && data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        timestamp = data['createdAt'] as Timestamp;
      } else if (data['createdAt'] is int) {
        timestamp = Timestamp.fromMillisecondsSinceEpoch(data['createdAt']);
      } else if (data['createdAt'] is String) {
        try {
          final dateTime = DateTime.parse(data['createdAt']);
          timestamp = Timestamp.fromDate(dateTime);
        } catch (e) {
          print('Error parsing createdAt date: ${data['createdAt']}');
        }
      }
    }

    final String fileUrl = data['secureUrl'] ?? '';
    final String extension = data['format']?.toString().toLowerCase() ?? '';

    // Format size
    String formattedSize;
    if (bytes < 1024) {
      formattedSize = '${bytes}b';
    } else if (bytes < 1024 * 1024) {
      formattedSize = '${(bytes / 1024).toStringAsFixed(0)}kb';
    } else {
      formattedSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }

    // Format date
    String formattedDate = 'Unknown date';
    if (timestamp != null) {
      formattedDate = DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }

    // Course information (department + course)
    String courseInfo = "";
    if (data['department'] != null) {
      courseInfo = data['department'];
      if (data['course'] != null) {
        courseInfo += " • ${data['course']}";
      }
    } else if (data['course'] != null) {
      courseInfo = data['course'];
    }

    // Document type
    String docType = data['documentType'] ?? extension.toUpperCase();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Open document
              _openDocument(fileUrl);
            },
            splashColor: blueColor.withOpacity(0.1),
            highlightColor: blueColor.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section with file type and options
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: blueColor.withOpacity(0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Document Type icon
                      _getDocumentTypeIcon(extension),
                      SizedBox(width: 10),

                      // File type text
                      Text(
                        docType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: blueColor,
                        ),
                      ),

                      Spacer(),

                      // Course code
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: blueColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          courseCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: blueColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document name
                      Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),

                      // Course information
                      if (courseInfo.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.school,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                courseInfo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                      ],

                      // File metadata row (size and date)
                      Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            formattedSize,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions row
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Edit button instead of View
                      TextButton.icon(
                        onPressed: () => _editDocument(data, documentId),
                        icon: Icon(Icons.edit, size: 18),
                        label: Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: blueColor,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      // Vertical divider
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),

                      // Download button
                      TextButton.icon(
                        onPressed: () {
                          // Always use the secureUrl for downloads when available
                          final downloadUrl = data['secureUrl'] ?? data['url'] ?? '';
                          _downloadDocument(downloadUrl, fileName);
                        },
                        icon: Icon(Icons.download, size: 18),
                        label: Text('Download'),
                        style: TextButton.styleFrom(
                          foregroundColor: blueColor,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      // Vertical divider
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),

                      // Delete button
                      TextButton.icon(
                        onPressed:
                            () => _deleteDocument(data['publicId'], documentId),
                        icon: Icon(Icons.delete_outline, size: 18),
                        label: Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          visualDensity: VisualDensity.compact,
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
    );
  }

  Widget _getDocumentTypeIcon(String extension) {
    Color iconColor;
    Color bgColor;
    String displayText;
    IconData iconData;

    switch (extension.toLowerCase()) {
      case 'pdf':
        iconColor = Colors.white;
        bgColor = Color(0xFFE94235); // Google red
        displayText = 'PDF';
        iconData = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        iconColor = Colors.white;
        bgColor = Color(0xFF2A5699); // Microsoft blue
        displayText = extension.toUpperCase();
        iconData = Icons.description;
        break;
      case 'ppt':
      case 'pptx':
        iconColor = Colors.white;
        bgColor = Color(0xFFD24726); // PowerPoint orange
        displayText = extension.toUpperCase();
        iconData = Icons.slideshow;
        break;
      case 'xls':
      case 'xlsx':
        iconColor = Colors.white;
        bgColor = Color(0xFF217346); // Excel green
        displayText = extension.toUpperCase();
        iconData = Icons.table_chart;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconColor = Colors.white;
        bgColor = Color(0xFF9C27B0); // Purple
        displayText = 'IMG';
        iconData = Icons.image;
        break;
      case 'txt':
        iconColor = Colors.white;
        bgColor = Color(0xFF607D8B); // Blue grey
        displayText = 'TXT';
        iconData = Icons.text_snippet;
        break;
      case 'zip':
      case 'rar':
        iconColor = Colors.white;
        bgColor = Color(0xFF795548); // Brown
        displayText = extension.toUpperCase();
        iconData = Icons.folder_zip;
        break;
      default:
        iconColor = Colors.white;
        bgColor = Color(0xFF9E9E9E); // Grey
        displayText = extension.isEmpty ? 'DOC' : extension.toUpperCase();
        iconData = Icons.insert_drive_file;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: Icon(iconData, color: iconColor, size: 18)),
    );
  }

  void _showDocumentOptions(
    BuildContext context,
    Map<String, dynamic> document,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.download, color: blueColor),
                title: Text('Download'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadDocument(
                    document['secureUrl'],
                    document['fileName'],
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: blueColor),
                title: Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement share functionality
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteDocument(document['publicId'], document['id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: blueColor),
                    SizedBox(width: 16),
                    Text(
                      'Sort Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              _buildSortOption(
                title: 'Date (Newest First)',
                icon: Icons.calendar_today,
                onTap: () {
                  _sortDocuments('date', true);
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Date (Oldest First)',
                icon: Icons.calendar_today,
                onTap: () {
                  _sortDocuments('date', false);
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Name (A-Z)',
                icon: Icons.sort_by_alpha,
                onTap: () {
                  _sortDocuments('name', true);
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Name (Z-A)',
                icon: Icons.sort_by_alpha,
                onTap: () {
                  _sortDocuments('name', false);
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Size (Largest First)',
                icon: Icons.data_usage,
                onTap: () {
                  _sortDocuments('size', true);
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Size (Smallest First)',
                icon: Icons.data_usage,
                onTap: () {
                  _sortDocuments('size', false);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: blueColor),
      title: Text(title),
      onTap: onTap,
      dense: true,
    );
  }

  void _sortDocuments(String criteria, bool ascending) {
    setState(() {
      switch (criteria) {
        case 'date':
          _filteredDocuments.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTimestamp = _getTimestamp(aData);
            final bTimestamp = _getTimestamp(bData);

            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return ascending ? 1 : -1;
            if (bTimestamp == null) return ascending ? -1 : 1;

            return ascending
                ? bTimestamp.compareTo(aTimestamp)
                : aTimestamp.compareTo(bTimestamp);
          });
          break;

        case 'name':
          _filteredDocuments.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aName = aData['fileName'] ?? aData['displayName'] ?? '';
            final bName = bData['fileName'] ?? bData['displayName'] ?? '';

            return ascending
                ? aName.toString().toLowerCase().compareTo(
                  bName.toString().toLowerCase(),
                )
                : bName.toString().toLowerCase().compareTo(
                  aName.toString().toLowerCase(),
                );
          });
          break;

        case 'size':
          _filteredDocuments.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aSize = (aData['bytes'] as num?)?.toInt() ?? 0;
            final bSize = (bData['bytes'] as num?)?.toInt() ?? 0;

            return ascending ? bSize.compareTo(aSize) : aSize.compareTo(bSize);
          });
          break;
      }
    });
  }

  // Helper method to get timestamp from document data
  Timestamp? _getTimestamp(Map<String, dynamic> data) {
    if (data['uploadedAt'] is Timestamp) {
      return data['uploadedAt'] as Timestamp;
    } else if (data['createdAt'] is Timestamp) {
      return data['createdAt'] as Timestamp;
    }
    return null;
  }

  void _downloadDocument(String url, String fileName) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download URL not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show improved download options dialog with modern UI
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15.0,
                  offset: Offset(0.0, 5.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and title side by side
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: blueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: blueColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Document',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: blueColor,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Save this file to your device',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // File info card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      // Document type icon - extract extension from filename
                      _getDocumentTypeIcon(
                        fileName.contains('.') ? fileName.split('.').last : '',
                      ),
                      SizedBox(width: 12),
                      // Filename with truncation
                      Expanded(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28),

                // Save to Device Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _startDownloadToDevice(url, fileName);
                  },
                  icon: Icon(Icons.save_alt, size: 18),
                  label: Text('Save to Device'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
                SizedBox(height: 12),

                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    minimumSize: Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Start the actual download process with progress tracking
  void _startDownloadToDevice(String url, String fileName) async {
    // Create a controller for the progress indicator
    final progressController = StreamController<double>();
    double progress = 0;

    // Show download progress dialog with updated UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent closing with back button
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15.0,
                    offset: Offset(0.0, 5.0),
                  ),
                ],
              ),
              child: StreamBuilder<double>(
                stream: progressController.stream,
                initialData: 0.0,
                builder: (context, snapshot) {
                  final progressPercent = (snapshot.data! * 100).toInt();
                  final isComplete = progressPercent >= 100;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress indicator
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circular progress indicator
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: CircularProgressIndicator(
                              value: snapshot.data,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isComplete ? Colors.green : blueColor,
                              ),
                            ),
                          ),
                          // Percentage text
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isComplete ? Colors.green : blueColor,
                                ),
                              ),
                              if (isComplete)
                                Icon(Icons.check, color: Colors.green),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Status text
                      Text(
                        isComplete ? 'Download Complete!' : 'Downloading...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 6),

                      // Filename
                      Text(
                        fileName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 24),

                      // Action button based on download state
                      ElevatedButton(
                        onPressed:
                            isComplete
                                ? () => Navigator.of(context).pop()
                                : null,
                        child: Text(isComplete ? 'Done' : 'Downloading...'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isComplete ? Colors.green : blueColor,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: blueColor.withOpacity(0.5),
                          disabledForegroundColor: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // On mobile, download the file
        await _downloadToDevice(url, fileName, (newProgress) {
          progress = newProgress;
          progressController.add(newProgress);

          // Auto close dialog when download completes
          if (newProgress >= 1.0) {
            Future.delayed(Duration(seconds: 2), () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(); // Close the progress dialog
              }
            });
          }
        });
      } else {
        // On web, just open the URL in a new tab and close the progress dialog
        await _openInBrowser(url);
        progressController.add(1.0);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Close the progress dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message with option to open in browser instead
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed. Try opening document in browser instead.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open in Browser',
            textColor: Colors.white,
            onPressed: () async {
              _openInBrowser(url);
            },
          ),
        ),
      );
    } finally {
      // Clean up the stream controller
      await progressController.close();
    }
  }

  void _deleteDocument(String publicId, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Delete icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outlined,
                    color: Colors.red[400],
                    size: 32,
                  ),
                ),
                SizedBox(height: 16),

                // Title
                Text(
                  'Delete Document',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),

                // Message
                Text(
                  'Are you sure you want to delete this document? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);

                        // Find the index of the document to be deleted
                        int documentIndex = _filteredDocuments.indexWhere(
                          (doc) => doc.id == docId,
                        );

                        if (documentIndex != -1) {
                          // Store a reference to the document for potential undo
                          final documentToDelete =
                              _filteredDocuments[documentIndex];

                          // Remove from UI first (optimistic update)
                          setState(() {
                            _filteredDocuments.removeAt(documentIndex);
                            // Also remove from main documents list if it exists there
                            int mainIndex = _documents.indexWhere(
                              (doc) => doc.id == docId,
                            );
                            if (mainIndex != -1) {
                              _documents.removeAt(mainIndex);
                            }
                          });

                          // Show a snackbar with deletion status and countdown timer
                          final int undoTimeSeconds =
                              5; // Set undo time window to 5 seconds

                          // Create a controller to dismiss the snackbar after the time expires
                          ScaffoldFeatureController<
                            SnackBar,
                            SnackBarClosedReason
                          >?
                          snackBarController;

                          // Track whether undo was used
                          bool undoUsed = false;

                          // Create a countdown stream
                          Stream<int> countdownStream = Stream.periodic(
                            Duration(seconds: 1),
                            (i) => undoTimeSeconds - i - 1,
                          ).take(undoTimeSeconds);

                          // Show the initial snackbar
                          snackBarController = ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: StreamBuilder<int>(
                                stream: countdownStream,
                                initialData: undoTimeSeconds,
                                builder: (context, snapshot) {
                                  return Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.white),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('Document deleted')),
                                      Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${snapshot.data}s',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              duration: Duration(seconds: undoTimeSeconds),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red[400],
                              action: SnackBarAction(
                                label: 'UNDO',
                                textColor: Colors.white,
                                onPressed: () {
                                  // Mark undo as used
                                  undoUsed = true;

                                  // Cancel the delete operation if it's still in progress
                                  // and restore the document to the list
                                  setState(() {
                                    if (documentIndex <
                                        _filteredDocuments.length) {
                                      _filteredDocuments.insert(
                                        documentIndex,
                                        documentToDelete,
                                      );
                                    } else {
                                      _filteredDocuments.add(documentToDelete);
                                    }

                                    // Also restore to main documents list
                                    int mainIndex = _documents.indexWhere(
                                      (doc) => doc.id == docId,
                                    );
                                    if (mainIndex != -1) {
                                      // Already exists (unlikely)
                                    } else {
                                      _documents.add(documentToDelete);
                                    }
                                  });

                                  // Show confirmation that the document was restored
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Document restored'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );

                          // Wait for the undo period to expire before actually deleting
                          Future.delayed(
                            Duration(seconds: undoTimeSeconds + 1),
                            () async {
                              // Only proceed with actual deletion if undo wasn't used
                              if (!undoUsed) {
                                try {
                                  // Actually perform the delete in the background
                                  await _uploadService.deleteDocument(
                                    publicId,
                                    docId,
                                  );

                                  // No need to show another message as the deletion was already indicated
                                } catch (e) {
                                  // If deletion failed, restore the document to the list
                                  if (documentIndex != -1) {
                                    setState(() {
                                      if (documentIndex <
                                          _filteredDocuments.length) {
                                        _filteredDocuments.insert(
                                          documentIndex,
                                          documentToDelete,
                                        );
                                      } else {
                                        _filteredDocuments.add(
                                          documentToDelete,
                                        );
                                      }

                                      // Also restore to main documents list if needed
                                      int mainIndex = _documents.indexWhere(
                                        (doc) => doc.id == docId,
                                      );
                                      if (mainIndex == -1) {
                                        _documents.add(documentToDelete);
                                      }
                                    });

                                    // Show error message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to delete document: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          );
                        }
                      },
                      icon: Icon(Icons.delete),
                      label: Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to open document in browser or viewer
  void _openDocument(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document URL not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _openInBrowser(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to edit document metadata
  void _editDocument(Map<String, dynamic> data, String documentId) {
    // Document data to edit
    final String fileName = data['fileName'] ?? data['displayName'] ?? '';
    final String courseCode = data['courseCode'] ?? '';
    final String department = data['department'] ?? '';
    final String course = data['course'] ?? '';
    final String docType = data['documentType'] ?? '';

    // Controllers for editing fields
    final TextEditingController fileNameController = TextEditingController(
      text: fileName,
    );
    final TextEditingController courseCodeController = TextEditingController(
      text: courseCode,
    );
    final TextEditingController departmentController = TextEditingController(
      text: department,
    );
    final TextEditingController courseController = TextEditingController(
      text: course,
    );
    final TextEditingController docTypeController = TextEditingController(
      text: docType,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: blueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit, color: blueColor, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit Document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: blueColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(height: 24),

                // Form fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditField(
                          controller: fileNameController,
                          label: 'File Name',
                          icon: Icons.insert_drive_file,
                        ),
                        SizedBox(height: 16),
                        _buildEditField(
                          controller: courseCodeController,
                          label: 'Course Code',
                          icon: Icons.code,
                        ),
                        SizedBox(height: 16),
                        _buildEditField(
                          controller: departmentController,
                          label: 'Department',
                          icon: Icons.business,
                        ),
                        SizedBox(height: 16),
                        _buildEditField(
                          controller: courseController,
                          label: 'Course',
                          icon: Icons.school,
                        ),
                        SizedBox(height: 16),
                        _buildEditField(
                          controller: docTypeController,
                          label: 'Document Type',
                          icon: Icons.description,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Updating document...'),
                              ],
                            ),
                            duration: Duration(seconds: 10),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        try {
                          // Create updated document data
                          Map<String, dynamic> updatedData = {
                            'fileName': fileNameController.text,
                            'courseCode': courseCodeController.text,
                            'department': departmentController.text,
                            'course': courseController.text,
                            'documentType': docTypeController.text,
                          };

                          // Update document in Firestore
                          await FirebaseFirestore.instance
                              .collection('documents')
                              .doc(documentId)
                              .update(updatedData);

                          // Dismiss the loading snackbar
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();

                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Document updated successfully'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Refresh the list
                          _loadRecentDocuments();
                        } catch (e) {
                          // Dismiss the loading snackbar
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();

                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update document: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orangeColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build styled text field for edit dialog
  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: blueColor, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(fontSize: 15, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  // Filter button in app bar
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, color: blueColor),
                      SizedBox(width: 12),
                      Text(
                        'Filter Documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: blueColor,
                        ),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedDocumentType = 'All';
                            _selectedCourse = 'All';
                          });
                        },
                        child: Text('Reset'),
                      ),
                    ],
                  ),
                  Divider(),
                  SizedBox(height: 8),

                  // Document type filter
                  Text(
                    'Document Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children:
                          _documentTypes.map((type) {
                            final isSelected = type == _selectedDocumentType;
                            return Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(() {
                                      _selectedDocumentType = type;
                                    });
                                  }
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: blueColor.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? blueColor : Colors.grey[800],
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Course filter
                  Text(
                    'Course',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children:
                          _courses.map((course) {
                            final isSelected = course == _selectedCourse;
                            return Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(course),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(() {
                                      _selectedCourse = course;
                                    });
                                  }
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: blueColor.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? blueColor : Colors.grey[800],
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Apply button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _isFilterActive =
                              _selectedDocumentType != 'All' ||
                              _selectedCourse != 'All';
                        });
                        _applyFilters();
                      },
                      child: Text('Apply Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(200, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
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

  // Method to open a URL in browser
  Future<void> _openInBrowser(String url) async {
    try {
      // Clean up URL for browser viewing (remove download parameters)
      if (url.contains('fl_attachment=true')) {
        url = url.replaceAll('fl_attachment=true', '');
        // Clean up leftover characters
        url = url.replaceAll('?&', '?').replaceAll('&&', '&');
        if (url.endsWith('?') || url.endsWith('&')) {
          url = url.substring(0, url.length - 1);
        }
      }
      
      // Launch URL in browser
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening in browser: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to download a file to device with progress tracking
  Future<void> _downloadToDevice(
    String url,
    String fileName,
    Function(double) onProgress,
  ) async {
    try {
      // Create dio instance
      final dio = Dio();
      
      // For Cloudinary, simplify our approach - no validation or HEAD requests
      if (url.contains('cloudinary.com')) {
        // Ensure we're using https
        if (url.startsWith('http:')) {
          url = url.replaceFirst('http:', 'https:');
        }
        
        // Strip any existing parameters
        if (url.contains('?')) {
          url = url.split('?')[0];
        }
        
        // For direct downloads, don't add any parameters
        print('Using direct Cloudinary URL: $url');
      }

      // Fix file name to ensure it has extension
      if (!fileName.contains('.')) {
        final urlExtension = url.split('.').last.split('?').first;
        if (urlExtension.length <= 4) {
          fileName = '$fileName.$urlExtension';
        }
      }

      // Set minimal headers for Cloudinary
      dio.options.headers = {
        'Accept': '*/*',
      };

      // Determine where to save the file
      String filePath;

      if (Platform.isAndroid) {
        try {
          // Get the best possible directory for downloads - skip permission request
          final downloadsDir = await getDownloadsDirectory();
          filePath = '${downloadsDir.path}/$fileName';

          // Notify user where file will be saved
          if (mounted &&
              !downloadsDir.path.contains('/storage/emulated/0/Download')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saving to app storage folder'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Error getting downloads directory: $e');
          // If permission fails, use app's internal storage
          final tempDir = await getTemporaryDirectory();
          filePath = '${tempDir.path}/$fileName';
        }
      } else if (Platform.isIOS) {
        // For iOS: Use Documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        filePath = '${appDocDir.path}/$fileName';
      } else {
        // Fallback for other platforms
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/$fileName';
      }

      // Make the filename unique if it already exists
      String uniqueFilePath = filePath;
      int counter = 1;

      while (await File(uniqueFilePath).exists()) {
        final lastDotIndex = fileName.lastIndexOf('.');
        String nameWithoutExtension = fileName;
        String extension = '';

        if (lastDotIndex != -1) {
          nameWithoutExtension = fileName.substring(0, lastDotIndex);
          extension = fileName.substring(lastDotIndex);
        }

        final directory = File(filePath).parent.path;
        uniqueFilePath =
            '$directory/${nameWithoutExtension}_$counter$extension';
        counter++;
      }

      // Ensure the directory exists
      final directory = Directory(File(uniqueFilePath).parent.path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Download the file with progress tracking
      await dio.download(
        url,
        uniqueFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress); // Call progress callback
            print('Download progress: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
        options: Options(
          receiveTimeout: Duration(minutes: 5),
          sendTimeout: Duration(minutes: 5),
        ),
      );
      
      // Verify the downloaded file exists and has content
      final savedFile = File(uniqueFilePath);
      if (await savedFile.exists()) {
        final fileSize = await savedFile.length();
        print('File saved: $uniqueFilePath (${fileSize} bytes)');
        
        // If the file size is zero, the download failed silently
        if (fileSize == 0) {
          throw Exception('Downloaded file is empty (0 bytes). Download likely failed.');
        }
      } else {
        throw Exception('File was not created at $uniqueFilePath');
      }

      // Show success notification with file location
      final savedFileName = uniqueFilePath.split('/').last;
      String location;

      if (Platform.isAndroid) {
        if (uniqueFilePath.contains('/storage/emulated/0/Download')) {
          location = 'Downloads folder';

          // Refresh media store to show the file in gallery/files app
          try {
            // Use MediaScannerConnection to make the file visible
            if (await File(uniqueFilePath).exists()) {
              final fileSize = await File(uniqueFilePath).length();
              print('File saved: $uniqueFilePath (${fileSize} bytes)');
            }
          } catch (e) {
            print('Media scanner error: $e');
          }
        } else if (uniqueFilePath.contains('/Android/data/')) {
          location = 'App storage (permission limited)';
        } else {
          location = 'App storage';
        }
      } else if (Platform.isIOS) {
        location = 'Documents folder';
      } else {
        location = 'Device storage';
      }

      // Set progress to 100% when complete
      onProgress(1.0);

      // Wait a brief moment to ensure the progress dialog updates
      await Future.delayed(Duration(milliseconds: 300));

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $location as $savedFileName'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  // Try to get the MIME type based on extension
                  String? mimeType;
                  final extension = savedFileName.split('.').last.toLowerCase();
                  switch (extension) {
                    case 'pdf':
                      mimeType = 'application/pdf';
                      break;
                    case 'doc':
                      mimeType = 'application/msword';
                      break;
                    case 'docx':
                      mimeType =
                          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                      break;
                    case 'xls':
                      mimeType = 'application/vnd.ms-excel';
                      break;
                    case 'xlsx':
                      mimeType =
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
                      break;
                    case 'ppt':
                      mimeType = 'application/vnd.ms-powerpoint';
                      break;
                    case 'pptx':
                      mimeType =
                          'application/vnd.openxmlformats-officedocument.presentationml.presentation';
                      break;
                    case 'jpg':
                    case 'jpeg':
                      mimeType = 'image/jpeg';
                      break;
                    case 'png':
                      mimeType = 'image/png';
                      break;
                    case 'txt':
                      mimeType = 'text/plain';
                      break;
                  }

                  // Open the file - the OpenFile package handles the rest
                  final result = await OpenFile.open(
                    uniqueFilePath,
                    type: mimeType,
                  );

                  if (result.type != ResultType.done) {
                    throw Exception('Could not open file: ${result.message}');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open file: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Download error: $e');
      
      // If we were showing a progress dialog, close it
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message with option to open in browser instead
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed. Try opening document in browser instead.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open in Browser',
            textColor: Colors.white,
            onPressed: () async {
              _openInBrowser(url);
            },
          ),
        ),
      );
    }
  }

  // Helper method to get the best possible downloads directory
  Future<Directory> getDownloadsDirectory() async {
    // Try standard path for Downloads directory - no permission check needed
    Directory downloadsDir = Directory('/storage/emulated/0/Download');

    // Check if directory exists and is accessible (don't write test file)
    if (await downloadsDir.exists()) {
      try {
        // Just list the directory to see if we can access it
        await downloadsDir.list().first;
        print('Using public Downloads directory');
        return downloadsDir;
      } catch (e) {
        print('Downloads directory exists but not accessible: $e');
      }
    }

    // Second option: external storage directory for app
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        print('Using app external storage: ${extDir.path}');
        return extDir;
      }
    } catch (e) {
      print('Error getting external directory: $e');
    }

    // Last resort: internal app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    print('Using internal app storage: ${appDir.path}');
    return appDir;
  }

  // Add helper method to get Android version
  Future<String> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        return Platform.operatingSystemVersion.split(' ').last;
      }
    } catch (e) {
      print('Error getting Android version: $e');
    }
    return '0';
  }
}

// Custom clipper for file icon shape
class FilePathClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width - 10, 0); // Top edge minus corner
    path.lineTo(size.width, 10); // Corner fold
    path.lineTo(size.width, size.height); // Right edge
    path.lineTo(0, size.height); // Bottom edge
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
 