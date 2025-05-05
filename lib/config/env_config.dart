import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Environment configuration for the app
/// This file contains sensitive configuration values and should not be committed to version control.
/// In a real project, these values would be loaded from environment variables, .env files, or other secure sources.
class EnvConfig {
  static Map<String, dynamic> _configData = {};
  static bool _initialized = false;
  
  // Cloudinary configuration
  static String get cloudinaryCloudName => _configData['cloud_name'] ?? '';
  static String get cloudinaryUploadPreset => _configData['upload_preset'] ?? '';
  static String get cloudinaryApiKey => _configData['api_key'] ?? '';
  static String get cloudinaryApiSecret => _configData['api_secret'] ?? '';
  
  // Initialize configuration by loading from YAML file
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Load YAML file from assets
      final yamlString = await rootBundle.loadString('assets/config/cloudinary_credentials.yaml');
      final YamlMap yamlMap = loadYaml(yamlString);
      
      // Convert YamlMap to regular Map
      _configData = _convertYamlToMap(yamlMap);
      
      _initialized = true;
      print('EnvConfig initialized successfully');
    } catch (e) {
      print('Error loading configuration: $e');
      // Set default values or handle the error appropriately
    }
  }
  
  // Helper method to convert YamlMap to regular Map
  static Map<String, dynamic> _convertYamlToMap(YamlMap yamlMap) {
    Map<String, dynamic> result = {};
    
    yamlMap.forEach((key, value) {
      if (value is YamlMap) {
        result[key.toString()] = _convertYamlToMap(value);
      } else if (value is YamlList) {
        result[key.toString()] = _convertYamlList(value);
      } else {
        result[key.toString()] = value;
      }
    });
    
    return result;
  }
  
  // Helper method to convert YamlList to regular List
  static List<dynamic> _convertYamlList(YamlList yamlList) {
    List<dynamic> result = [];
    
    for (var item in yamlList) {
      if (item is YamlMap) {
        result.add(_convertYamlToMap(item));
      } else if (item is YamlList) {
        result.add(_convertYamlList(item));
      } else {
        result.add(item);
      }
    }
    
    return result;
  }
} 