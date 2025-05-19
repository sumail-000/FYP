import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'cloudinary_service.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'upload_progress_screen.dart';
import '../auth/auth_service.dart';
import '../services/activity_points_service.dart';

class UploadService {
  // Firebase collection for departments
  final CollectionReference _departmentsCollection = FirebaseFirestore.instance
      .collection('departments');

  // Firebase collection for course codes
  final CollectionReference _courseCodesCollection = FirebaseFirestore.instance
      .collection('course_codes');

  // Firebase collection for courses
  final CollectionReference _coursesCollection = FirebaseFirestore.instance
      .collection('courses');

  // Collection for uploaded documents
  final CollectionReference _documentsCollection = FirebaseFirestore.instance
      .collection('documents');

  // Collection for course code mappings
  final CollectionReference _courseMappingsCollection = FirebaseFirestore
      .instance
      .collection('course_mappings');

  // Cloudinary service for file uploads
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Auth service to get user information
  final AuthService _authService = AuthService();
  
  // Activity points service
  final ActivityPointsService _activityPointsService = ActivityPointsService();

  // Default departments list (used as fallback if Firebase fails)
  static final List<String> _defaultDepartments = ['IT (Arfa Karim)'];

  // Default course codes (used as fallback if Firebase fails)
  static final List<String> _defaultCourseCodes = ['CS-101', 'IT-102'];

  // Default courses (used as fallback if Firebase fails)
  static final List<String> _defaultCourses = ['SNA', 'OOP', 'DSA'];

  // Minimum similarity score to consider departments as duplicates (0.0 to 1.0)
  // Lowering threshold to be more lenient with similarly formatted departments
  static const double _similarityThreshold = 0.6;

  // Method to get the list of departments from Firebase
  Future<List<String>> getDepartments({bool forceRefresh = false}) async {
    try {
      // Get departments from Firestore with cache control
      print(
        'Fetching departments from Firestore with forceRefresh=$forceRefresh',
      ); // Debug print

      // Use Source.server to bypass cache when forceRefresh is true
      final source = forceRefresh ? Source.server : Source.serverAndCache;
      final snapshot = await _departmentsCollection.get(
        GetOptions(source: source),
      );

      if (snapshot.docs.isNotEmpty) {
        // Convert Firestore documents to list of department names
        final departments =
            snapshot.docs.map((doc) => doc['name'].toString()).toList();

        // Sort alphabetically
        departments.sort();
        print('Loaded departments: $departments'); // Debug print
        return departments;
      } else {
        // If no departments found, add default ones and return
        for (var dept in _defaultDepartments) {
          await _departmentsCollection.add({'name': dept});
        }
        print(
          'No departments found, using defaults: $_defaultDepartments',
        ); // Debug print
        return _defaultDepartments;
      }
    } catch (e) {
      print('Error loading departments: $e');
      // Return default departments in case of error
      return _defaultDepartments;
    }
  }

  // Method to refresh departments, forcing a server fetch
  Future<List<String>> refreshDepartments() async {
    return getDepartments(forceRefresh: true);
  }

  // Method to add a new department with semantic similarity check
  Future<bool> addDepartment(String department) async {
    try {
      if (department.isEmpty) {
        print('Department is empty, not adding'); // Debug print
        return false;
      }

      // Get current departments
      final departments = await getDepartments();

      print('Trying to add department: "$department"'); // Debug print

      // Check for exact match
      if (departments.contains(department)) {
        print('Exact department match found, not adding'); // Debug print
        return false;
      }

      // Check for similarity
      if (_hasSimilarDepartment(departments, department)) {
        print('Similar department found, not adding'); // Debug print
        return false;
      }

      // Add new department to Firestore
      print('Adding department to Firestore: "$department"'); // Debug print
      await _departmentsCollection.add({
        'name': department,
        // Use server timestamp without FieldValue (which is causing issues)
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('Department added successfully'); // Debug print
      return true;
    } catch (e) {
      print('Error adding department: $e'); // Debug print
      return false;
    }
  }

  // Check if a similar department already exists using semantic similarity
  bool _hasSimilarDepartment(
    List<String> existingDepartments,
    String newDepartment,
  ) {
    // Convert to lowercase for comparison
    final newDeptLower = newDepartment.toLowerCase();
    final newDeptNormalized = _normalizeForComparison(newDeptLower);

    // Extract department code (if it follows the pattern "XX (YYY)" format)
    final newDeptCode = _extractDepartmentCode(newDeptLower);

    print(
      'Checking similarity for: "$newDepartment" (normalized: "$newDeptNormalized", code: "$newDeptCode")',
    ); // Debug print

    for (var existing in existingDepartments) {
      final existingLower = existing.toLowerCase();
      final existingNormalized = _normalizeForComparison(existingLower);
      final existingDeptCode = _extractDepartmentCode(existingLower);

      print(
        'Comparing with: "$existing" (normalized: "$existingNormalized", code: "$existingDeptCode")',
      ); // Debug print

      // If both follow the standard format with department codes, compare the codes separately
      if (newDeptCode.isNotEmpty && existingDeptCode.isNotEmpty) {
        // If they follow the pattern but have different department codes, they're different departments
        if (newDeptCode != existingDeptCode) {
          print('Different department codes, not a duplicate'); // Debug print
          continue; // Skip similarity check for different department codes
        }
      }

      // Skip if completely different lengths (optimization)
      if ((existingLower.length - newDeptLower.length).abs() > 10) {
        print('Skipping comparison due to length difference'); // Debug print
        continue;
      }

      // For departments with special format patterns like "CS (Arfa Karim)"
      // check if they're exactly the same before comparing with Levenshtein
      if (existingNormalized == newDeptNormalized) {
        print(
          'Normalized forms match, considering as duplicate',
        ); // Debug print
        return true;
      }

      // Calculate similarity score for regular comparison
      final similarity = _calculateSimilarity(existingLower, newDeptLower);
      print('Similarity score: $similarity'); // Debug print

      // If similarity exceeds threshold, consider as duplicate
      if (similarity >= _similarityThreshold) {
        print(
          'Similarity threshold exceeded, considering as duplicate',
        ); // Debug print
        return true;
      }
    }

    print('No similar departments found'); // Debug print
    return false;
  }

  // Extract department code from standard format, e.g., "CS" from "CS (Arfa Karim)"
  String _extractDepartmentCode(String department) {
    // Check for the standard pattern: start with letters/numbers, then space and open parenthesis
    final match = RegExp(r'^([a-z0-9]+)\s*\(').firstMatch(department);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    return '';
  }

  // Normalize department name for comparison
  // This helps with departments that have a standard format like "X (Y)"
  String _normalizeForComparison(String department) {
    // Remove spaces, parentheses, and other special characters
    return department
        .replaceAll(' ', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('-', '')
        .replaceAll(',', '')
        .replaceAll('\'', '') // Remove apostrophes
        .replaceAll('"', '') // Remove quotation marks
        .toLowerCase(); // Ensure lowercase
  }

  // Calculate similarity between two strings (0.0 to 1.0)
  double _calculateSimilarity(String s1, String s2) {
    // If strings are identical, return 1.0
    if (s1 == s2) return 1.0;

    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);

    // Convert to similarity score (0.0 to 1.0)
    final maxLength = max(s1.length, s2.length);
    if (maxLength == 0) return 1.0; // Both empty strings

    return 1.0 - (distance / maxLength);
  }

  // Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Create matrix
    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= s1.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= s2.length; j++) matrix[0][j] = j;

    // Fill matrix
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[s1.length][s2.length];
  }

  // Method to get the list of course codes from Firebase
  Future<List<String>> getCourseCodes({bool forceRefresh = false}) async {
    try {
      // Get course codes from Firestore with cache control
      print(
        'Fetching course codes from Firestore with forceRefresh=$forceRefresh',
      ); // Debug print

      // Use Source.server to bypass cache when forceRefresh is true
      final source = forceRefresh ? Source.server : Source.serverAndCache;
      final snapshot = await _courseCodesCollection.get(
        GetOptions(source: source),
      );

      if (snapshot.docs.isNotEmpty) {
        // Convert Firestore documents to list of course codes
        final courseCodes =
            snapshot.docs.map((doc) => doc['code'].toString()).toList();

        // Sort alphabetically
        courseCodes.sort();
        print('Loaded course codes: $courseCodes'); // Debug print
        return courseCodes;
      } else {
        // If no course codes found, add default ones and return
        for (var code in _defaultCourseCodes) {
          await _courseCodesCollection.add({'code': code});
        }
        print(
          'No course codes found, using defaults: $_defaultCourseCodes',
        ); // Debug print
        return _defaultCourseCodes;
      }
    } catch (e) {
      print('Error loading course codes: $e');
      // Return default course codes in case of error
      return _defaultCourseCodes;
    }
  }

  // Method to refresh course codes, forcing a server fetch
  Future<List<String>> refreshCourseCodes() async {
    return getCourseCodes(forceRefresh: true);
  }

  // Method to add a new course code
  Future<bool> addCourseCode(String code) async {
    try {
      if (code.isEmpty) {
        print('Course code is empty, not adding'); // Debug print
        return false;
      }

      // Get current course codes
      final courseCodes = await getCourseCodes();

      print('Trying to add course code: "$code"'); // Debug print

      // Check if course code already exists
      if (courseCodes.contains(code)) {
        print('Course code already exists, not adding'); // Debug print
        return false;
      }

      // Add new course code to Firestore
      print('Adding course code to Firestore: "$code"'); // Debug print
      await _courseCodesCollection.add({
        'code': code,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('Course code added successfully'); // Debug print
      return true;
    } catch (e) {
      print('Error adding course code: $e'); // Debug print
      return false;
    }
  }

  // Method to get the list of courses from Firebase
  Future<List<String>> getCourses({bool forceRefresh = false}) async {
    try {
      // Get courses from Firestore with cache control
      print(
        'Fetching courses from Firestore with forceRefresh=$forceRefresh',
      ); // Debug print

      // Use Source.server to bypass cache when forceRefresh is true
      final source = forceRefresh ? Source.server : Source.serverAndCache;
      final snapshot = await _coursesCollection.get(GetOptions(source: source));

      if (snapshot.docs.isNotEmpty) {
        // Convert Firestore documents to list of course names
        final courses =
            snapshot.docs.map((doc) => doc['name'].toString()).toList();

        // Sort alphabetically
        courses.sort();
        print('Loaded courses: $courses'); // Debug print
        return courses;
      } else {
        // If no courses found, add default ones and return
        for (var course in _defaultCourses) {
          await _coursesCollection.add({'name': course});
        }
        print(
          'No courses found, using defaults: $_defaultCourses',
        ); // Debug print
        return _defaultCourses;
      }
    } catch (e) {
      print('Error loading courses: $e');
      // Return default courses in case of error
      return _defaultCourses;
    }
  }

  // Method to refresh courses, forcing a server fetch
  Future<List<String>> refreshCourses() async {
    return getCourses(forceRefresh: true);
  }

  // Method to add a new course
  Future<bool> addCourse(String course) async {
    try {
      if (course.isEmpty) {
        print('Course name is empty, not adding'); // Debug print
        return false;
      }

      // Get current courses
      final courses = await getCourses();

      print('Trying to add course: "$course"'); // Debug print

      // Check if course already exists
      if (courses.contains(course)) {
        print('Course already exists, not adding'); // Debug print
        return false;
      }

      // Add new course to Firestore
      print('Adding course to Firestore: "$course"'); // Debug print
      await _coursesCollection.add({
        'name': course,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('Course added successfully'); // Debug print
      return true;
    } catch (e) {
      print('Error adding course: $e'); // Debug print
      return false;
    }
  }

  // Method to find a course code for a specific department and course
  Future<String?> getCourseCodeForDepartmentAndCourse(
    String department,
    String course,
  ) async {
    try {
      if (department.isEmpty || course.isEmpty) return null;

      // Query the course mappings collection
      final snapshot =
          await _courseMappingsCollection
              .where('department', isEqualTo: department)
              .where('course', isEqualTo: course)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['courseCode'] as String?;
      }

      return null;
    } catch (e) {
      print('Error finding course code for $department/$course: $e');
      return null;
    }
  }

  // Method to save a course mapping (department + course -> course code)
  Future<bool> saveCourseMapping(
    String department,
    String course,
    String courseCode,
  ) async {
    try {
      if (department.isEmpty || course.isEmpty || courseCode.isEmpty) {
        print('Department, course or course code is empty, not saving mapping');
        return false;
      }

      print('Saving course mapping: $department/$course -> $courseCode');

      // Check if mapping already exists
      final snapshot =
          await _courseMappingsCollection
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
        await _courseMappingsCollection.add({
          'department': department,
          'course': course,
          'courseCode': courseCode,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      print('Course mapping saved successfully');
      return true;
    } catch (e) {
      print('Error saving course mapping: $e');
      return false;
    }
  }

  // Method to upload files to Cloudinary and store metadata in Firestore
  Future<bool> uploadFiles(
    BuildContext context,
    List<Map<String, dynamic>> uploads,
  ) async {
    if (uploads.isEmpty) return false;

    // Create a list of upload tasks
    final List<UploadTask> uploadTasks =
        uploads.map((uploadData) {
          final filePath = uploadData['filePath'] as String;
          final fileName =
              uploadData['displayName'] as String? ?? path.basename(filePath);

          // Remove the filePath from metadata as it's not needed in the database
          final metadata = Map<String, dynamic>.from(uploadData);
          metadata.remove('filePath');

          return UploadTask(
            fileName: fileName,
            filePath: filePath,
            metadata: metadata,
          );
        }).toList();

    // Show the upload progress screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UploadProgressScreen(uploadTasks: uploadTasks),
      ),
    );

    // If user cancelled, return false
    if (result != true) return false;

    // Count successful uploads
    final successfulUploads =
        uploadTasks
            .where(
              (task) =>
                  task.status == UploadStatus.completed &&
                  task.uploadedUrl != null,
            )
            .length;

    // Return true if at least one upload was successful
    return successfulUploads > 0;
  }

  // Method to upload a single file to Cloudinary and store metadata
  Future<void> uploadFile(
    String filePath, {
    String? documentName,
    String? documentType,
    String? category,
    String? semester,
    String? department,
    String? course,
    String? courseCode,
  }) async {
    try {
      // Check if Cloudinary is configured
      if (!_cloudinaryService.isConfigured) {
        throw Exception(
          'Cloudinary is not properly configured. Please check your credentials.',
        );
      }

      // Create metadata for the document
      final metadata = {
        'fileName': documentName ?? path.basename(filePath),
        'uploadedAt':
            FieldValue.serverTimestamp(), // Use server timestamp instead of client time
      };

      // Optional metadata fields
      if (documentType != null) metadata['documentType'] = documentType;
      if (category != null) metadata['category'] = category;
      if (semester != null) metadata['semester'] = semester;
      if (department != null) metadata['department'] = department;
      if (course != null) metadata['course'] = course;
      if (courseCode != null) metadata['courseCode'] = courseCode;

      // Use a simple folder name without nested paths
      String folder = 'academia_hub';

      print('Uploading file $filePath to Cloudinary folder: $folder');

      // Upload file to Cloudinary
      final response = await _cloudinaryService.uploadFile(
        filePath,
        folder: folder,
        metadata: metadata,
      );

      // Extract file extension from the original file path
      final extension =
          path.extension(filePath).replaceAll('.', '').toLowerCase();
          
      // Get current user data for metadata
      final userData = await _authService.getUserData();

      // Store document metadata and Cloudinary response in Firestore
      await _documentsCollection.add({
        ...metadata,
        'publicId': response.publicId,
        'secureUrl': response.secureUrl,
        'url': response.url,
        'format': extension, // Use file extension instead of response.format
        'resourceType':
            'document', // Use generic type instead of response.resourceType
        'createdAt': FieldValue.serverTimestamp(), // Use server timestamp
        'bytes':
            File(
              filePath,
            ).lengthSync(), // Get file size from file instead of response.bytes
        // Add user information
        'uploaderId': _authService.currentUser?.uid,
        'uploaderName': userData?.name ?? _authService.currentUser?.displayName ?? 'Anonymous',
        'uploaderEmail': userData?.email ?? _authService.currentUser?.email,
        'university': userData?.university,
      });

      // If department, course, and courseCode are provided, save the mapping
      if (department != null && course != null && courseCode != null) {
        await saveCourseMapping(department, course, courseCode);
      }
      
      // Award activity points for document upload
      await _activityPointsService.awardResourceUploadPoints();

      print('File uploaded successfully: ${response.secureUrl}');
    } catch (e) {
      print('Error uploading file to Cloudinary: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  // Method to get file types that can be uploaded
  List<String> getSupportedFileTypes() {
    return ['PDF', 'DOC/DOCX', 'PPT/PPTX', 'XLS/XLSX', 'TXT', 'ZIP', 'JPG/PNG'];
  }

  // Method to check file size (limit to 20MB for example)
  bool isFileSizeValid(int sizeInBytes) {
    const maxSize = 20 * 1024 * 1024; // 20MB in bytes
    return sizeInBytes <= maxSize;
  }

  // Get recently uploaded documents
  Future<List<DocumentSnapshot>> getRecentDocuments({int limit = 20}) async {
    try {
      // Get current user ID
      final userId = _authService.currentUser?.uid;
      
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Query the documents collection, filtered by the current user's ID and ordered by upload date
      final querySnapshot = await _documentsCollection
          .where('uploaderId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs;
    } catch (e) {
      print('Error getting recent documents: $e');
      throw Exception('Failed to load recent documents: $e');
    }
  }

  // Delete a document from Firestore and Cloudinary
  Future<bool> deleteDocument(String publicId, String documentId) async {
    try {
      print(
        'Deleting document: $documentId with Cloudinary publicId: $publicId',
      );

      // Step 1: Delete from Firestore
      await _documentsCollection.doc(documentId).delete();
      print('Document deleted from Firestore: $documentId');

      // Step 2: Attempt to delete from Cloudinary
      if (publicId.isNotEmpty) {
        final success = await _cloudinaryService.deleteFile(publicId);
        if (success) {
          print('Cloudinary deletion request processed for: $publicId');
        } else {
          print(
            'Warning: Cloudinary deletion may not have succeeded for: $publicId',
          );
          print(
            'The file might need to be deleted manually from the Cloudinary dashboard',
          );
        }
      } else {
        print('Warning: No publicId provided, skipping Cloudinary deletion');
      }

      return true;
    } catch (e) {
      print('Error deleting document: $e');
      throw Exception('Failed to delete document: $e');
    }
  }
}
