import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../model/university_model.dart';

class UniversityService {
  static List<University> _universities = [];
  static bool _isInitialized = false;

  // Load the universities from the CSV file
  static Future<List<University>> loadUniversities() async {
    if (_isInitialized) {
      return _universities;
    }

    try {
      final String rawData = await rootBundle.loadString('assets/data/universities.csv');
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(rawData, eol: '\n');
      
      // Skip the header row if it exists
      final startIndex = csvTable.isNotEmpty && 
                        csvTable[0].isNotEmpty && 
                        csvTable[0][0].toString().toLowerCase().contains('name') ? 1 : 0;
      
      _universities = csvTable
          .skip(startIndex)
          .map((data) => University.fromList(data))
          .toList();
      
      _isInitialized = true;
      return _universities;
    } catch (e) {
      print('Error loading universities: $e');
      return [];
    }
  }

  // Search for universities by name
  static Future<List<University>> searchUniversities(String query) async {
    final List<University> allUniversities = await loadUniversities();
    if (query.isEmpty) {
      return allUniversities;
    }

    final String sanitizedQuery = query.toLowerCase().trim();
    
    return allUniversities.where((university) {
      final String name = university.name.toLowerCase();
      final String location = university.location.toLowerCase();
      
      return name.contains(sanitizedQuery) || 
             location.contains(sanitizedQuery);
    }).toList();
  }
} 