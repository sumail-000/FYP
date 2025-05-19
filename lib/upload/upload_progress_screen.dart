import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'cloudinary_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../services/activity_points_service.dart';

class UploadProgressScreen extends StatefulWidget {
  final List<UploadTask> uploadTasks;

  const UploadProgressScreen({
    Key? key,
    required this.uploadTasks,
  }) : super(key: key);

  @override
  _UploadProgressScreenState createState() => _UploadProgressScreenState();
}

class _UploadProgressScreenState extends State<UploadProgressScreen> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  Timer? _progressUpdateTimer;
  
  @override
  void initState() {
    super.initState();
    // Start all uploads when screen loads
    _startUploads();
    
    // Set up a timer to regularly update the UI
    _progressUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _progressUpdateTimer?.cancel();
    super.dispose();
  }

  void _startUploads() {
    for (var task in widget.uploadTasks) {
      _startUpload(task);
    }
  }

  Future<void> _startUpload(UploadTask task) async {
    if (task.status == UploadStatus.pending || 
        task.status == UploadStatus.paused) {
      setState(() {
        task.status = UploadStatus.uploading;
      });
      
      // Set up progress callback to update UI
      task.progressCallback = () {
        if (mounted) setState(() {});
      };
      
      // Start actual upload
      task.startUpload(_cloudinaryService, () {
        if (mounted) setState(() {});
      });
    }
  }

  void _pauseUpload(UploadTask task) {
    if (task.status == UploadStatus.uploading) {
      setState(() {
        task.status = UploadStatus.paused;
        task.pauseUpload();
      });
    }
  }

  void _cancelUpload(UploadTask task) {
    setState(() {
      task.status = UploadStatus.cancelled;
      task.cancelUpload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);
    
    // Count completed uploads
    final completedUploads = widget.uploadTasks
        .where((task) => task.status == UploadStatus.completed)
        .length;
    
    // Count failed uploads
    final failedUploads = widget.uploadTasks
        .where((task) => task.status == UploadStatus.failed)
        .length;
    
    // Count cancelled uploads
    final cancelledUploads = widget.uploadTasks
        .where((task) => task.status == UploadStatus.cancelled)
        .length;
    
    // Calculate overall progress
    final int totalTasks = widget.uploadTasks.length;
    final int activeTasks = totalTasks - cancelledUploads;
    final double overallProgress = activeTasks > 0 
        ? widget.uploadTasks
            .where((task) => task.status != UploadStatus.cancelled)
            .map((task) => task.progress)
            .reduce((a, b) => a + b) / activeTasks
        : 0.0;
    
    // Check if all uploads are finished
    final bool allFinished = widget.uploadTasks.every((task) => 
        task.status == UploadStatus.completed || 
        task.status == UploadStatus.failed ||
        task.status == UploadStatus.cancelled);
    
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog if uploads are in progress
        if (!allFinished) {
          bool? result = await _showExitConfirmationDialog();
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFE6E8EB),
        appBar: AppBar(
          title: Text('Uploading Documents'),
          backgroundColor: blueColor,
          centerTitle: true,
          actions: [
            // Done button (only enabled when all uploads are finished)
            TextButton(
              onPressed: allFinished 
                  ? () => Navigator.of(context).pop(true) 
                  : null,
              child: Text(
                'Done',
                style: TextStyle(
                  color: allFinished ? Colors.white : Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Overall progress section
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(overallProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: orangeColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: overallProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(orangeColor),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed: $completedUploads of $totalTasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (failedUploads > 0)
                        Text(
                          'Failed: $failedUploads',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Upload tasks list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: widget.uploadTasks.length,
                itemBuilder: (context, index) {
                  final task = widget.uploadTasks[index];
                  return _buildUploadTaskItem(task, orangeColor, blueColor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUploadTaskItem(UploadTask task, Color orangeColor, Color blueColor) {
    // Get file extension for icon styling
    final extension = task.fileName.split('.').last.toLowerCase();
    
    // Get progress percentage as int
    final progressPercent = (task.progress * 100).toInt();
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // File type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getFileTypeColor(extension),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: _getFileTypeIcon(extension),
                  ),
                ),
                
                SizedBox(width: 12),
                
                // Filename and progress info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      // Progress bar
                      if (task.status == UploadStatus.uploading || task.status == UploadStatus.paused)
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  // Background
                                  Container(
                                    height: 5,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  // Progress
                                  FractionallySizedBox(
                                    widthFactor: task.progress,
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: orangeColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            // Percentage text
                            Text(
                              '$progressPercent%',
                              style: TextStyle(
                                color: orangeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      if (task.status == UploadStatus.uploading)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            task.uploadSpeed != '0' 
                                ? '${task.uploadSpeed} KB/s · ${task.timeRemaining} remaining' 
                                : 'Starting upload...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      if (task.status == UploadStatus.completed)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Upload completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      if (task.status == UploadStatus.failed)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Upload failed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      if (task.status == UploadStatus.paused)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Upload paused',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[700],
                            ),
                          ),
                        ),
                      if (task.status == UploadStatus.cancelled)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Upload cancelled',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Control buttons for running uploads
                if (task.status == UploadStatus.uploading || task.status == UploadStatus.paused)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pause/Resume button
                      IconButton(
                        icon: Icon(
                          task.status == UploadStatus.paused ? Icons.play_arrow : Icons.pause,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                        onPressed: () {
                          if (task.status == UploadStatus.paused) {
                            _startUpload(task);
                          } else {
                            _pauseUpload(task);
                          }
                        },
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      // Cancel button
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                        onPressed: () => _cancelUpload(task),
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                
                // Status icon for completed uploads
                if (task.status == UploadStatus.completed)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                
                // Status icon for failed uploads
                if (task.status == UploadStatus.failed)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.error,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                
                // Status icon for cancelled uploads
                if (task.status == UploadStatus.cancelled)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.cancel,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
          
          // Error message for failed uploads
          if (task.status == UploadStatus.failed && task.errorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
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
  
  // Helper method to get file type icon
  Widget _getFileTypeIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: Colors.white, size: 20);
      case 'doc':
      case 'docx':
        return Icon(Icons.description, color: Colors.white, size: 20);
      case 'ppt':
      case 'pptx':
        return Icon(Icons.slideshow, color: Colors.white, size: 20);
      case 'xls':
      case 'xlsx':
        return Icon(Icons.table_chart, color: Colors.white, size: 20);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icon(Icons.image, color: Colors.white, size: 20);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.white, size: 20);
    }
  }
  
  // Helper method to get file type color
  Color _getFileTypeColor(String extension) {
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  Future<bool?> _showExitConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Uploads?'),
          content: Text('If you leave now, all pending uploads will be cancelled. Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Stay'),
            ),
            TextButton(
              onPressed: () {
                // Cancel all uploading/pending tasks
                for (var task in widget.uploadTasks) {
                  if (task.status == UploadStatus.uploading || 
                      task.status == UploadStatus.pending ||
                      task.status == UploadStatus.paused) {
                    task.cancelUpload();
                  }
                }
                Navigator.of(context).pop(true);
              },
              child: Text('Exit'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }
}

// Upload task status
enum UploadStatus {
  pending,
  uploading,
  paused,
  completed,
  failed,
  cancelled,
}

// Upload task model
class UploadTask {
  final String fileName;
  final String filePath;
  final Map<String, dynamic> metadata;
  double progress;
  UploadStatus status;
  String? errorMessage;
  String? uploadedUrl;
  
  // For UI display
  String uploadSpeed = '0';
  String timeRemaining = '0s';
  bool isUploading = false;
  Function? progressCallback;
  
  // For real upload
  Completer<void>? _uploadCompleter;
  Timer? _uploadSpeedTimer;
  int _bytesUploaded = 0;
  int _lastBytesUploaded = 0;
  int _fileSize = 0;
  DateTime? _startTime;
  
  // Add reference to auth service
  final AuthService _authService = AuthService();
  
  UploadTask({
    required this.fileName,
    required this.filePath,
    required this.metadata,
    this.progress = 0.0,
    this.status = UploadStatus.pending,
    this.errorMessage,
    this.uploadedUrl,
  }) {
    // Get file size
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        _fileSize = file.lengthSync();
      }
    } catch (e) {
      print('Error getting file size: $e');
    }
  }
  
  void startUpload(CloudinaryService cloudinaryService, Function stateCallback) {
    if (isUploading) return;
    isUploading = true;
    status = UploadStatus.uploading;
    _startTime = DateTime.now();
    
    // Start monitoring upload speed
    _startSpeedMonitoring();
    
    // Perform actual upload to Cloudinary
    _performRealUpload(cloudinaryService, stateCallback);
  }
  
  void pauseUpload() {
    isUploading = false;
    status = UploadStatus.paused;
    _cancelSpeedMonitoring();
  }
  
  void cancelUpload() {
    isUploading = false;
    status = UploadStatus.cancelled;
    _cancelSpeedMonitoring();
    
    // Cancel upload if in progress
    if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
      _uploadCompleter!.completeError('Upload cancelled by user');
    }
  }
  
  void _startSpeedMonitoring() {
    // Cancel existing timer if any
    _cancelSpeedMonitoring();
    
    // Start a timer to update upload speed every second
    _uploadSpeedTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isUploading) {
        _cancelSpeedMonitoring();
        return;
      }
      
      // For Cloudinary upload, we don't have real progress data
      // So let's simulate progress for better UX
      if (_fileSize > 0) {
        // Calculate progress based on time since start
        final elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;
        if (elapsedSeconds > 0) {
          final estimatedTotalSeconds = elapsedSeconds / progress;
          final remainingSeconds = estimatedTotalSeconds - elapsedSeconds;
          
          // Update speed display
          final estimatedBytesPerSecond = (_fileSize * progress) / elapsedSeconds;
          uploadSpeed = (estimatedBytesPerSecond / 1024).toStringAsFixed(1);
          
          // Update time remaining
          if (remainingSeconds > 60) {
            timeRemaining = '${(remainingSeconds / 60).toStringAsFixed(1)}m';
          } else {
            timeRemaining = '${remainingSeconds.toStringAsFixed(0)}s';
          }
        }
      }
      
      // Update UI
      if (progressCallback != null) {
        progressCallback!();
      }
    });
  }
  
  void _cancelSpeedMonitoring() {
    if (_uploadSpeedTimer != null) {
      _uploadSpeedTimer!.cancel();
      _uploadSpeedTimer = null;
    }
  }
  
  // Perform actual upload to Cloudinary
  Future<void> _performRealUpload(CloudinaryService cloudinaryService, Function stateCallback) async {
    // Create a completer to handle the upload
    _uploadCompleter = Completer<void>();
    
    try {
      // Check if Cloudinary is configured
      if (!cloudinaryService.isConfigured) {
        throw Exception('Cloudinary is not properly configured. Please check your credentials.');
      }
      
      // Use a simple folder name without nested paths
      String folder = 'academia_hub';
      
      // Create CloudinaryFile from path
      final file = File(filePath);
      
      if (!file.existsSync()) {
        throw Exception('File does not exist at path: $filePath');
      }
      
      // Get file size
      _fileSize = file.lengthSync();
      final fileSizeMB = (_fileSize / (1024 * 1024)).toStringAsFixed(2);
      print('Uploading file: $fileName, size: $fileSizeMB MB');
      
      // Check file size limits for Cloudinary
      if (_fileSize > 100 * 1024 * 1024) { // > 100MB
        throw Exception('File size exceeds the maximum limit (100MB). Please reduce the file size and try again.');
      }
      
      // Simulate progress since Cloudinary doesn't provide real-time progress
      // Start a timer to increment progress every 100ms for better UX
      final progressTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        if (!isUploading || progress >= 0.99) {
          timer.cancel();
          return;
        }
        
        // Adaptive progress increment based on file size
        double progressIncrement;
        
        if (_fileSize < 1024 * 1024) { // < 1MB
          progressIncrement = 0.05; // Fast for tiny files
        } else if (_fileSize < 5 * 1024 * 1024) { // < 5MB
          progressIncrement = 0.02; // Medium speed for small files
        } else if (_fileSize < 20 * 1024 * 1024) { // < 20MB
          progressIncrement = 0.005; // Slower for medium files
        } else if (_fileSize < 50 * 1024 * 1024) { // < 50MB
          progressIncrement = 0.002; // Very slow for large files
        } else { // ≥ 50MB
          progressIncrement = 0.001; // Extremely slow for huge files
        }
        
        // Don't exceed 99% until we get confirmation from server
        progress = (progress + progressIncrement).clamp(0.0, 0.99);
        
        // Update UI
        if (progressCallback != null) {
          progressCallback!();
        }
      });
      
      try {
        // Upload to Cloudinary with progress tracking
        final response = await cloudinaryService.uploadFile(
          filePath, 
          folder: folder,
          progressCallback: (realProgress) {
            // This may not be called if the Cloudinary package doesn't properly
            // implement progress updates for larger files
            if (isUploading) {
              // Make sure progress doesn't go backwards (which can happen with Cloudinary)
              if (realProgress > progress) {
                progress = realProgress;
                
                // Update UI
                if (progressCallback != null) {
                  progressCallback!();
                }
              }
            }
          }
        );
        
        // Cancel progress timer
        progressTimer.cancel();
        
        // Update task with response
        uploadedUrl = response.secureUrl;
        status = UploadStatus.completed;
        progress = 1.0;
        
        // Store document metadata and Cloudinary response in Firestore
        await _saveToFirestore(response);
        
        // If department, course, and courseCode are provided, save the mapping
        if (metadata['department'] != null && 
            metadata['course'] != null && 
            metadata['courseCode'] != null) {
          await _saveMapping();
        }
      } catch (e) {
        // Cancel progress timer
        progressTimer.cancel();
        
        // Handle specific errors
        String errorMsg = e.toString();
        
        // Look for common Cloudinary error patterns
        if (errorMsg.contains('400') || errorMsg.contains('bad request')) {
          if (_fileSize > 25 * 1024 * 1024) { // > 25MB
            errorMsg = 'The file is too large for upload. Files larger than 25MB may require special handling or upgrading your Cloudinary plan.';
          } else if (errorMsg.contains('resource_type')) {
            errorMsg = 'Invalid file format. Please try a different file format.';
          } else {
            errorMsg = 'The server rejected the upload. Please try a different file or check your network connection.';
          }
        } else if (errorMsg.contains('401') || errorMsg.contains('unauthorized')) {
          errorMsg = 'Upload authorization failed. Please check your Cloudinary credentials.';
        } else if (errorMsg.contains('403') || errorMsg.contains('forbidden')) {
          errorMsg = 'Access to Cloudinary is restricted. Please check your account permissions.';
        } else if (errorMsg.contains('413') || errorMsg.contains('too large')) {
          errorMsg = 'The file is too large. Please try uploading a smaller file (under 25MB).';
        } else if (errorMsg.contains('429') || errorMsg.contains('rate limit')) {
          errorMsg = 'Too many upload requests. Please wait a moment and try again.';
        } else if (errorMsg.contains('timeout')) {
          errorMsg = 'The upload timed out. Please check your internet connection and try again with a smaller file.';
        } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
          errorMsg = 'Network error. Please check your internet connection and try again.';
        }
        
        status = UploadStatus.failed;
        errorMessage = errorMsg;
        print('Error uploading to Cloudinary: $e');
      }
    } catch (e) {
      status = UploadStatus.failed;
      errorMessage = 'Upload failed: $e';
      print('Error in _performRealUpload: $e');
    } finally {
      isUploading = false;
      _cancelSpeedMonitoring();
      
      // Complete the completer
      if (!(_uploadCompleter?.isCompleted ?? true)) {
        _uploadCompleter!.complete();
      }
      
      // Update UI
      stateCallback();
    }
  }
  
  // Save document to Firestore after Cloudinary upload
  Future<void> _saveToFirestore(CloudinaryResponse response) async {
    try {
      // Firebase collection for uploaded documents
      final documentsCollection = FirebaseFirestore.instance.collection('documents');
      
      // Extract file extension from the original file path
      final extension = path.extension(filePath).replaceAll('.', '').toLowerCase();
      
      // Get current user data
      final userData = await _authService.getUserData();
      
      // Create document data for Firestore
      final documentData = {
        ...metadata,
        'publicId': response.publicId,
        'secureUrl': response.secureUrl,
        'url': response.url,
        'format': extension,
        'resourceType': 'document',
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'bytes': _fileSize,
        // Add user information
        'uploaderId': _authService.currentUser?.uid,
        'uploaderName': userData?.name ?? _authService.currentUser?.displayName ?? 'Anonymous',
        'uploaderEmail': userData?.email ?? _authService.currentUser?.email,
        'university': userData?.university,
      };
      
      // Save to Firestore
      await documentsCollection.add(documentData);
      
      // Award activity points for document upload
      final activityPointsService = ActivityPointsService();
      await activityPointsService.awardResourceUploadPoints();
      
      print('Document metadata saved to Firestore for: ${metadata['displayName'] ?? fileName}');
    } catch (e) {
      print('Error saving document metadata to Firestore: $e');
      // We don't want to fail the upload if just the Firestore save fails
    }
  }
  
  // Save course-department-courseCode mapping
  Future<void> _saveMapping() async {
    try {
      final department = metadata['department'];
      final course = metadata['course'];
      final courseCode = metadata['courseCode'];
      
      if (department == null || course == null || courseCode == null) return;
      
      // Collection for course code mappings
      final courseMappingsCollection = FirebaseFirestore.instance.collection('course_mappings');
      
      // Check if mapping already exists
      final snapshot = await courseMappingsCollection
          .where('department', isEqualTo: department)
          .where('course', isEqualTo: course)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        // Update existing mapping
        await snapshot.docs.first.reference.update({
          'courseCode': courseCode,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Create new mapping
        await courseMappingsCollection.add({
          'department': department,
          'course': course,
          'courseCode': courseCode,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      print('Course mapping saved: $department/$course -> $courseCode');
    } catch (e) {
      print('Error saving course mapping: $e');
    }
  }
} 