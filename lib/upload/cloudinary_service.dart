import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:crypto/crypto.dart' as crypto;
import '../config/env_config.dart'; // Import environment config file

class CloudinaryService {
  // Cloudinary configuration from environment variables
  static String get cloudName => EnvConfig.cloudinaryCloudName;
  static String get uploadPreset => EnvConfig.cloudinaryUploadPreset;

  // Flag to check if credentials are set
  bool get isConfigured =>
      cloudName.isNotEmpty &&
      uploadPreset.isNotEmpty &&
      cloudName != 'YOUR_CLOUD_NAME' &&
      uploadPreset != 'YOUR_UPLOAD_PRESET';

  // Singleton pattern
  static final CloudinaryService _instance = CloudinaryService._internal();

  factory CloudinaryService() {
    return _instance;
  }

  late final CloudinaryPublic cloudinary;
  late final Dio dio;

  CloudinaryService._internal() {
    // Create CloudinaryPublic instance with a longer timeout
    cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

    // Create a Dio instance for large file uploads
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ),
    );
  }

  // Test if Cloudinary connection is working properly
  Future<bool> testConnection() async {
    try {
      if (!isConfigured) {
        print('Cloudinary is not configured. Please check your credentials.');
        return false;
      }

      print('Testing Cloudinary connection with:');
      print('Cloud Name: $cloudName');
      print('Upload Preset: $uploadPreset');

      // We'll just check if the configuration loads properly
      return cloudName.isNotEmpty &&
          uploadPreset.isNotEmpty &&
          cloudName != 'YOUR_CLOUD_NAME' &&
          uploadPreset != 'YOUR_UPLOAD_PRESET';
    } catch (e) {
      print('Error testing Cloudinary connection: $e');
      return false;
    }
  }

  // Check if a file is too large for direct upload
  bool _isFileTooLarge(File file) {
    // 10MB is a safe threshold for direct uploads with cloudinary_public package
    const int maxDirectUploadSize = 10 * 1024 * 1024; // 10MB in bytes
    return file.lengthSync() > maxDirectUploadSize;
  }

  // Upload a file to Cloudinary
  Future<CloudinaryResponse> uploadFile(
    String filePath, {
    String folder = 'academia_hub',
    Map<String, dynamic>? metadata,
    Function(double)? progressCallback,
  }) async {
    try {
      if (!isConfigured) {
        throw Exception(
          'Cloudinary is not configured. Please set your cloud name and upload preset.',
        );
      }

      if (kIsWeb) {
        // Handle web uploads differently if needed
        // Web implementation would go here
        throw Exception('Web uploads not implemented yet');
      } else {
        // Mobile upload implementation
        final file = File(filePath);

        if (!file.existsSync()) {
          throw Exception('File does not exist at path: $filePath');
        }

        // Get file size to determine upload approach
        final fileSize = file.lengthSync();
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        print('Uploading file size: $fileSizeMB MB');

        // Determine resource type based on file extension for Cloudinary
        final extension = filePath.split('.').last.toLowerCase();
        String resourceTypeStr = _getResourceTypeForExtension(extension);

        // For large files, use Dio for direct HTTP upload to Cloudinary API
        if (_isFileTooLarge(file)) {
          return await _uploadLargeFile(
            file,
            folder: folder,
            resourceType: resourceTypeStr,
            progressCallback: progressCallback,
          );
        } else {
          // For smaller files, use the cloudinary_public package
          CloudinaryFile cloudinaryFile;

          // Create CloudinaryFile with the appropriate resource type
          if (resourceTypeStr == 'image') {
            cloudinaryFile = CloudinaryFile.fromFile(
              file.path,
              folder: folder,
              resourceType: CloudinaryResourceType.Auto,
            );
          } else if (resourceTypeStr == 'video') {
            cloudinaryFile = CloudinaryFile.fromFile(
              file.path,
              folder: folder,
              resourceType: CloudinaryResourceType.Auto,
            );
          } else {
            cloudinaryFile = CloudinaryFile.fromFile(
              file.path,
              folder: folder,
              resourceType: CloudinaryResourceType.Auto,
            );
          }

          // Create progress callback adapter for the CloudinaryPublic package
          final onProgressAdapter =
              progressCallback != null
                  ? (int count, int total) {
                    final progress = total > 0 ? count / total : 0.0;
                    progressCallback(progress);
                  }
                  : null;

          // Upload to Cloudinary using the standard package
          return await cloudinary.uploadFile(
            cloudinaryFile,
            onProgress: onProgressAdapter,
          );
        }
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  // Upload large file directly to Cloudinary using Dio
  Future<CloudinaryResponse> _uploadLargeFile(
    File file, {
    required String folder,
    required String resourceType,
    Function(double)? progressCallback,
  }) async {
    try {
      // Build the upload URL with the correct resource type
      final uploadUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload';

      // Create form data with all required parameters
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: MediaType.parse(_getContentTypeForFile(file.path)),
        ),
        'upload_preset': uploadPreset,
        'folder': folder,
      });

      // Set up Dio options
      final options = Options(
        headers: {'Content-Type': 'multipart/form-data'},
        // Don't follow redirects automatically
        followRedirects: false,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      );

      // Upload with progress tracking
      final response = await dio.post(
        uploadUrl,
        data: formData,
        options: options,
        onSendProgress: (int sent, int total) {
          if (progressCallback != null && total > 0) {
            final progress = sent / total;
            progressCallback(progress);
          }
        },
      );

      // Check for successful upload
      if (response.statusCode != 200) {
        final message =
            response.data is Map
                ? response.data['error']?.toString()
                : 'Upload failed';
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Cloudinary upload failed: $message',
        );
      }

      // Convert Dio response to CloudinaryResponse format
      final Map<String, dynamic> responseData = response.data;

      // Create a custom CloudinaryResponse
      return CloudinaryResponse(
        secureUrl: responseData['secure_url'] ?? '',
        publicId: responseData['public_id'] ?? '',
        url: responseData['url'] ?? '',
        originalFilename:
            responseData['original_filename'] ?? file.path.split('/').last,
        assetId: responseData['asset_id'] ?? '',
        createdAt:
            responseData['created_at'] != null
                ? DateTime.parse(responseData['created_at'])
                : DateTime.now(),
        data: responseData,
      );
    } catch (e) {
      print('Error in large file upload: $e');
      rethrow;
    }
  }

  // Get appropriate content type for multi-part file upload
  String _getContentTypeForFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // Get appropriate resource type string based on file extension
  String _getResourceTypeForExtension(String extension) {
    // For images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 'image';
    }
    // For videos
    else if (['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv'].contains(extension)) {
      return 'video';
    }
    // For documents like PDF and other files
    else {
      return 'raw';
    }
  }

  // Upload multiple files to Cloudinary
  Future<List<CloudinaryResponse>> uploadFiles(
    List<String> filePaths, {
    String folder = 'academia_hub',
    List<Map<String, dynamic>?>? metadataList,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'Cloudinary is not configured. Please set your cloud name and upload preset.',
      );
    }

    final List<CloudinaryResponse> responses = [];
    final List<String> failedUploads = [];

    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      final metadata =
          metadataList != null && i < metadataList.length
              ? metadataList[i]
              : null;

      try {
        final response = await uploadFile(
          filePath,
          folder: folder,
          metadata: metadata,
        );
        responses.add(response);
      } catch (e) {
        print('Error uploading file $filePath: $e');
        failedUploads.add(filePath);
      }
    }

    if (failedUploads.isNotEmpty) {
      throw Exception(
        'Failed to upload ${failedUploads.length} files: ${failedUploads.join(', ')}',
      );
    }

    return responses;
  }

  // Delete a file from Cloudinary by its public ID
  Future<bool> deleteFile(String publicId) async {
    try {
      if (!isConfigured) {
        throw Exception(
          'Cloudinary is not configured. Please set your cloud name and upload preset.',
        );
      }

      print(
        'Attempting to delete Cloudinary resource with public ID: $publicId',
      );

      // Get API key and secret from your EnvConfig
      final apiKey = EnvConfig.cloudinaryApiKey;
      final apiSecret = EnvConfig.cloudinaryApiSecret;

      // Check if we have credentials for authenticated API calls
      if (apiKey.isEmpty ||
          apiSecret.isEmpty ||
          apiKey == 'YOUR_API_KEY' ||
          apiSecret == 'YOUR_API_SECRET') {
        print('❗ WARNING: Missing Cloudinary API credentials for deletion');
        print(
          '❗ IMPORTANT: Cloudinary resources must be deleted manually from the Cloudinary dashboard',
        );
        print('❗ The public ID to delete is: $publicId');
        return false;
      }

      // Prepare authenticated deletion request using Cloudinary Admin API
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Extract resource type from public ID or assume "image" as default
      // In Cloudinary, public IDs might contain folder structure like "academia_hub/file.pdf"
      String resourceType = 'image'; // Default resource type

      // Try to determine resource type from public ID (if extension is available)
      if (publicId.contains('.')) {
        final extension = publicId.split('.').last.toLowerCase();
        resourceType = _getResourceTypeForExtension(extension);
      }

      // Create the string to sign
      final signatureString =
          'public_id=$publicId&timestamp=$timestamp${apiSecret}';
      // Generate signature using SHA-1 hash
      final signature = _generateSHA1(signatureString);

      // Build the request URL for the Cloudinary Admin API with the appropriate resource type
      final deleteUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy';

      // Prepare request body
      final formData = FormData.fromMap({
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      // Send the deletion request
      final response = await dio.post(deleteUrl, data: formData);

      // Check response
      if (response.statusCode == 200) {
        if (response.data['result'] == 'ok') {
          print('✅ Successfully deleted Cloudinary resource: $publicId');
          return true;
        } else {
          // If the resource type guess was wrong, try with "raw" as fallback
          if (resourceType != 'raw') {
            print(
              '🔄 First deletion attempt failed, trying with "raw" resource type',
            );
            return await _retryDeleteWithResourceType(
              publicId,
              'raw',
              apiKey,
              apiSecret,
            );
          }
        }
      }

      print('❌ Failed to delete Cloudinary resource: ${response.data}');
      return false;
    } catch (e) {
      print('Error in Cloudinary delete operation: $e');
      return false;
    }
  }

  // Helper method to retry deletion with a different resource type
  Future<bool> _retryDeleteWithResourceType(
    String publicId,
    String resourceType,
    String apiKey,
    String apiSecret,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signatureString =
          'public_id=$publicId&timestamp=$timestamp${apiSecret}';
      final signature = _generateSHA1(signatureString);

      final deleteUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy';

      final formData = FormData.fromMap({
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      final response = await dio.post(deleteUrl, data: formData);

      if (response.statusCode == 200 && response.data['result'] == 'ok') {
        print(
          '✅ Successfully deleted Cloudinary resource with type $resourceType: $publicId',
        );
        return true;
      }

      print('❌ Retry deletion failed: ${response.data}');
      return false;
    } catch (e) {
      print('Error in retry deletion: $e');
      return false;
    }
  }

  // Helper method to generate SHA-1 hash for Cloudinary API signatures
  String _generateSHA1(String input) {
    var bytes = utf8.encode(input);
    var digest = crypto.sha1.convert(bytes);
    return digest.toString();
  }

  // Debug method to check if API credentials are properly loaded
  void debugCredentials() {
    print('Cloudinary Credentials Debug:');
    print('Cloud Name: $cloudName');
    print('Upload Preset: $uploadPreset');
    print('API Key set: ${EnvConfig.cloudinaryApiKey.isNotEmpty && EnvConfig.cloudinaryApiKey != 'YOUR_API_KEY'}');
    print('API Secret set: ${EnvConfig.cloudinaryApiSecret.isNotEmpty && EnvConfig.cloudinaryApiSecret != 'YOUR_API_SECRET'}');
    print('Is Configured: $isConfigured');
  }
}
