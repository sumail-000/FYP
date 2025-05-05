import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'upload_service.dart';

class RecentUploadsScreen extends StatefulWidget {
  @override
  _RecentUploadsScreenState createState() => _RecentUploadsScreenState();
}

class _RecentUploadsScreenState extends State<RecentUploadsScreen> {
  final UploadService _uploadService = UploadService();
  final Color blueColor = Color(0xFF2D6DA8);
  bool _isLoading = true;
  List<DocumentSnapshot> _documents = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecentDocuments();
  }

  Future<void> _loadRecentDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final documents = await _uploadService.getRecentDocuments();
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load documents: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blueColor,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recently Uploaded',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.sort, color: Colors.white),
              onPressed: () {
                // Show sort options
              },
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
        backgroundColor: blueColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(blueColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecentDocuments,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                foregroundColor: Colors.white,
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
            Icon(Icons.upload_file, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text(
              'No documents uploaded yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final data = doc.data() as Map<String, dynamic>;
        
        return _buildDocumentCard(data, doc.id);
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> data, String documentId) {
    // Extract data with fallbacks
    final String fileName = data['fileName'] ?? data['displayName'] ?? 'Unnamed Document';
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
      formattedDate = DateFormat('MMM dd,yyyy').format(timestamp.toDate());
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Document Icon based on type
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _getDocumentTypeIcon(extension),
          ),
          
          // Document info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: blueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Size : $formattedSize',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Course code : $courseCode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Uploaded : $formattedDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Actions
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Options menu
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () {
                  _showDocumentOptions(context, data);
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              // Download button
              IconButton(
                icon: Icon(Icons.download, color: blueColor),
                onPressed: () {
                  _downloadDocument(fileUrl, fileName);
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                onPressed: () {
                  _deleteDocument(data['publicId'], documentId);
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(width: 8), // Add some padding at the end
        ],
      ),
    );
  }

  Widget _getDocumentTypeIcon(String extension) {
    Color bgColor;
    Widget iconWidget;
    
    switch (extension.toLowerCase()) {
      case 'pdf':
        bgColor = Colors.red;
        iconWidget = Container(
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'PDF',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        break;
      case 'doc':
      case 'docx':
        bgColor = Colors.blue;
        iconWidget = Container(
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'DOC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        break;
      case 'ppt':
      case 'pptx':
        bgColor = Colors.orange;
        iconWidget = Container(
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'PPT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        break;
      default:
        bgColor = Colors.grey;
        iconWidget = Icon(
          Icons.insert_drive_file,
          color: Colors.white,
          size: 12,
        );
    }
    
    return Stack(
      children: [
        // File icon background (page with folded corner)
        Container(
          width: 48,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              // Main paper
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ClipPath(
                    clipper: FilePathClipper(),
                    child: Container(
                      color: Colors.grey.shade100,
                    ),
                  ),
                ),
              ),
              
              // Top-right corner fold
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.grey.shade300, Colors.grey.shade100],
                    ),
                  ),
                ),
              ),
              
              // File type icon in center
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: iconWidget,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDocumentOptions(BuildContext context, Map<String, dynamic> document) {
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
                  _downloadDocument(document['secureUrl'], document['fileName']);
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

  void _downloadDocument(String url, String fileName) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download URL not available'), backgroundColor: Colors.red)
      );
      return;
    }

    // Show download starting notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $fileName...'))
    );

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // On mobile, download the file
        await _downloadToDevice(url, fileName);
      } else {
        // On web, just open the URL in a new tab
        await _openInBrowser(url);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _downloadToDevice(String url, String fileName) async {
    try {
      // Create dio instance
      final dio = Dio();
      
      // Determine where to save the file
      String filePath;
      
      if (Platform.isAndroid) {
        // For Android: first check permissions
        try {
          // Request storage permission - simplified approach
          await Permission.storage.request();
          
          // Try to use the Downloads folder
          Directory? downloadsDir;
          try {
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = await getExternalStorageDirectory();
            }
          } catch (e) {
            print('Could not access external storage: $e');
            // Fallback to app's documents directory
            final appDir = await getApplicationDocumentsDirectory();
            downloadsDir = Directory('${appDir.path}/Downloads');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
          }
          
          filePath = '${downloadsDir!.path}/$fileName';
        } catch (e) {
          print('Permission error: $e');
          // If permission fails, use app's internal storage
          final tempDir = await getTemporaryDirectory();
          filePath = '${tempDir.path}/$fileName';
        }
      } 
      else if (Platform.isIOS) {
        // For iOS: Use Documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        filePath = '${appDocDir.path}/$fileName';
      } 
      else {
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
        uniqueFilePath = '$directory/${nameWithoutExtension}_$counter$extension';
        counter++;
      }
      
      // Download the file
      await dio.download(
        url,
        uniqueFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('Download progress: $progress%');
          }
        },
      );
      
      // Show success notification with file location
      final savedFileName = uniqueFilePath.split('/').last;
      String location;
      
      if (Platform.isAndroid) {
        if (uniqueFilePath.contains('/storage/emulated/0/Download')) {
          location = 'Downloads folder';
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $location as $savedFileName'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () async {
              final fileUri = Uri.file(uniqueFilePath);
              if (!await launchUrl(fileUri)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open file'))
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      print('Download error: $e');
      throw Exception('Failed to download file: $e');
    }
  }

  void _deleteDocument(String publicId, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Document'),
          content: Text('Are you sure you want to delete this document? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleting document...')),
                );
                
                try {
                  await _uploadService.deleteDocument(publicId, docId);
                  
                  // Refresh the list
                  _loadRecentDocuments();
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Document deleted successfully')),
                  );
                } catch (e) {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete document: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
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