import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class MetadataService {
  static final MetadataService _instance = MetadataService._internal();

  factory MetadataService() {
    return _instance;
  }

  MetadataService._internal();

  Map<String, dynamic>? _metadata;
  String? _metadataPath;

  // Initialize the service by loading metadata from JSON file
  Future<void> initialize() async {
    if (_metadata != null) return; // Already initialized

    try {
      // First try to load from app documents directory (for persistence)
      final directory = await getApplicationDocumentsDirectory();
      _metadataPath = '${directory.path}/metadata.json';
      
      // Check if the file exists
      final file = File(_metadataPath!);
      if (await file.exists()) {
        // Load from persisted file
        final String jsonString = await file.readAsString();
        _metadata = json.decode(jsonString);
        print('Metadata loaded from persisted file');
      } else {
        // Fall back to assets bundle
        final String jsonString = await rootBundle.loadString(
          'assets/data/metadata.json',
        );
        _metadata = json.decode(jsonString);
        
        // Save the initial data for future use
        await saveMetadata();
        print('Metadata loaded from assets and saved to documents');
      }
    } catch (e) {
      print('Error loading metadata: $e');
      // Initialize with empty data if loading fails
      _metadata = {
        "blocks": [],
        "blockDepartments": {}, // Map of block to its departments
        "courses": [],
        "courseCodes": {},
        "departmentBlocks": {},
        "semesterCourses": {},
      };
      
      // Try to save the empty structure
      try {
        await saveMetadata();
      } catch (saveError) {
        print('Error saving initial metadata: $saveError');
      }
    }
  }

  // Save metadata to JSON file for persistence
  Future<bool> saveMetadata() async {
    if (_metadata == null) return false;
    if (_metadataPath == null) {
      final directory = await getApplicationDocumentsDirectory();
      _metadataPath = '${directory.path}/metadata.json';
    }
    
    try {
      final file = File(_metadataPath!);
      final String jsonString = json.encode(_metadata);
      await file.writeAsString(jsonString);
      print('Metadata saved successfully to $_metadataPath');
      return true;
    } catch (e) {
      print('Error saving metadata: $e');
      return false;
    }
  }

  // Get departments list
  List<String> getDepartments() {
    if (_metadata == null) return [];
    return List<String>.from(_metadata!['departments'] ?? []);
  }
  
  // Add a new department to the metadata
  Future<bool> addDepartment(String department) async {
    if (_metadata == null) await initialize();
    if (department.trim().isEmpty) return false;
    
    // Make sure departments list exists
    if (!_metadata!.containsKey('departments')) {
      _metadata!['departments'] = [];
    }
    
    // Add department if not already in the list
    final departments = List<String>.from(_metadata!['departments'] ?? []);
    if (!departments.contains(department)) {
      departments.add(department);
      _metadata!['departments'] = departments;
      print('Added department to metadata: $department');
      
      // Save the updated metadata
      return await saveMetadata();
    }
    
    return true;
  }

  // Get blocks list
  List<String> getBlocks() {
    if (_metadata == null) return [];
    return List<String>.from(_metadata!['blocks'] ?? []);
  }

  // Add a new block to the metadata
  Future<bool> addBlock(String block) async {
    if (_metadata == null) await initialize();
    if (block.trim().isEmpty) return false;
    
    // Make sure blocks list exists
    if (!_metadata!.containsKey('blocks')) {
      _metadata!['blocks'] = [];
    }
    
    // Add block if not already in the list
    final blocks = List<String>.from(_metadata!['blocks'] ?? []);
    if (!blocks.contains(block)) {
      blocks.add(block);
      _metadata!['blocks'] = blocks;
      print('Added block to metadata: $block');
      
      // Save the updated metadata
      return await saveMetadata();
    }
    
    return true;
  }

  // Get blocks for a specific department
  List<String> getBlocksForDepartment(String department) {
    if (_metadata == null) return [];

    final departmentBlocks =
        _metadata!['departmentBlocks'] as Map<String, dynamic>?;
    if (departmentBlocks == null) return getBlocks();

    final blocks = departmentBlocks[department];
    if (blocks == null) return getBlocks();

    return List<String>.from(blocks);
  }

  // Get courses list
  List<String> getCourses() {
    if (_metadata == null) return [];
    return List<String>.from(_metadata!['courses'] ?? []);
  }
  
  // Add a new course to the metadata
  Future<bool> addCourse(String course, String semester, String department, String block) async {
    if (_metadata == null) await initialize();
    if (course.trim().isEmpty) return false;
    
    // Make sure courses list exists
    if (!_metadata!.containsKey('courses')) {
      _metadata!['courses'] = [];
    }
    
    // Add course to general courses list if not already in the list
    final courses = List<String>.from(_metadata!['courses'] ?? []);
    if (!courses.contains(course)) {
      courses.add(course);
      _metadata!['courses'] = courses;
    }
    
    // Add course to semester-specific list
    if (!_metadata!.containsKey('semesterCourses')) {
      _metadata!['semesterCourses'] = {};
    }
    
    // Ensure the department exists
    final semesterCourses = _metadata!['semesterCourses'] as Map<String, dynamic>;
    if (!semesterCourses.containsKey(department)) {
      semesterCourses[department] = {};
    }
    
    // Ensure the block exists for this department
    final departmentData = semesterCourses[department] as Map<String, dynamic>;
    if (!departmentData.containsKey(block)) {
      departmentData[block] = {};
    }
    
    // Ensure the semester exists for this block
    final blockData = departmentData[block] as Map<String, dynamic>;
    if (!blockData.containsKey(semester)) {
      blockData[semester] = [];
    }
    
    // Add course to this semester if not already there
    final semesterSpecificCourses = List<String>.from(blockData[semester] ?? []);
    if (!semesterSpecificCourses.contains(course)) {
      semesterSpecificCourses.add(course);
      blockData[semester] = semesterSpecificCourses;
    }
    
    print('Added course to metadata: $course for $semester, $department, $block');
    
    // Save the updated metadata
    return await saveMetadata();
  }

  // Get course code for a specific course
  String? getCourseCode(String course) {
    if (_metadata == null) return null;

    final courseCodes = _metadata!['courseCodes'] as Map<String, dynamic>?;
    if (courseCodes == null) return null;

    return courseCodes[course] as String?;
  }
  
  // Set course code for a specific course
  Future<bool> setCourseCode(String course, String courseCode) async {
    if (_metadata == null) await initialize();
    if (course.trim().isEmpty || courseCode.trim().isEmpty) return false;
    
    // Make sure courseCodes map exists
    if (!_metadata!.containsKey('courseCodes')) {
      _metadata!['courseCodes'] = {};
    }
    
    // Add or update course code
    final courseCodes = _metadata!['courseCodes'] as Map<String, dynamic>;
    courseCodes[course] = courseCode;
    
    print('Set course code in metadata: $course -> $courseCode');
    
    // Save the updated metadata
    return await saveMetadata();
  }

  // Get all course codes
  List<String> getAllCourseCodes() {
    if (_metadata == null) return [];

    final courseCodes = _metadata!['courseCodes'] as Map<String, dynamic>?;
    if (courseCodes == null) return [];

    return List<String>.from(courseCodes.values);
  }

  // Get courses for a specific semester, department, and block
  List<String> getCoursesForSemesterDepartmentBlock(
    String semester,
    String department,
    String block,
  ) {
    if (_metadata == null) return [];

    try {
      final semesterCourses =
          _metadata!['semesterCourses'] as Map<String, dynamic>?;
      if (semesterCourses == null) return [];

      final departmentData =
          semesterCourses[department] as Map<String, dynamic>?;
      if (departmentData == null) return [];

      final blockData = departmentData[block] as Map<String, dynamic>?;
      if (blockData == null) return [];

      final courses = blockData[semester] as List<dynamic>?;
      if (courses == null) return [];

      print(
        'Found exact match for $semester, $department, $block with courses: ${courses.join(", ")}',
      );
      return List<String>.from(courses);
    } catch (e) {
      print('Error getting courses for $semester, $department, $block: $e');
      return [];
    }
  }
  
  // Debug function to dump the current metadata structure
  void debugPrintMetadata() {
    if (_metadata == null) {
      print('Metadata is null');
      return;
    }
    
    print('METADATA DUMP:');
    print(json.encode(_metadata));
  }

  // Get departments list for a specific block
  List<String> getDepartmentsForBlock(String block) {
    if (_metadata == null) return [];
    final blockDepartments = _metadata!['blockDepartments'] as Map<String, dynamic>;
    return List<String>.from(blockDepartments[block] ?? []);
  }

  // Add a department to a specific block
  Future<bool> addDepartmentToBlock(String block, String department) async {
    if (_metadata == null) return false;
    
    try {
      final blockDepartments = _metadata!['blockDepartments'] as Map<String, dynamic>;
      if (!blockDepartments.containsKey(block)) {
        blockDepartments[block] = [];
      }
      
      final departments = List<String>.from(blockDepartments[block]);
      if (!departments.contains(department)) {
        departments.add(department);
        blockDepartments[block] = departments;
        await saveMetadata();
      }
      return true;
    } catch (e) {
      print('Error adding department to block: $e');
      return false;
    }
  }

  // Remove a department from a block
  Future<bool> removeDepartmentFromBlock(String block, String department) async {
    if (_metadata == null) return false;
    
    try {
      final blockDepartments = _metadata!['blockDepartments'] as Map<String, dynamic>;
      if (blockDepartments.containsKey(block)) {
        final departments = List<String>.from(blockDepartments[block]);
        departments.remove(department);
        blockDepartments[block] = departments;
        await saveMetadata();
      }
      return true;
    } catch (e) {
      print('Error removing department from block: $e');
      return false;
    }
  }

  // Get all departments across all blocks
  List<String> getAllDepartments() {
    if (_metadata == null) return [];
    final blockDepartments = _metadata!['blockDepartments'] as Map<String, dynamic>;
    final allDepartments = <String>{};
    
    blockDepartments.forEach((block, departments) {
      allDepartments.addAll(List<String>.from(departments));
    });
    
    return allDepartments.toList()..sort();
  }
}
