import 'package:flutter/material.dart';
import 'upload_service.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isUploading = false;
  String _selectedFile = '';
  final UploadService _uploadService = UploadService();
  final Color orangeColor = Color(0xFFf06517);
  final Color blueColor = Color(0xFF2D6DA8);
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final height = screenSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: Color(0xFFE6E8EB),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Upload Documents',
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Document history icon
          IconButton(
            icon: Icon(
              Icons.history, 
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Document history coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            
            // Document upload card - matching the attached UI
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                width: double.infinity,
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
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cloud upload icon
                      Icon(
                        Icons.cloud_upload,
                        size: 80,
                        color: Colors.grey[700],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Select button
                      ElevatedButton(
                        onPressed: _isUploading ? null : _selectFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orangeColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 40, 
                            vertical: 10
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Supported file formats text
                      Text(
                        'support .docx, pdf, ppt file size 30mb',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      
                      // Show selected file if any
                      if (_selectedFile.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: orangeColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.insert_drive_file, color: orangeColor),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedFile,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _selectedFile = '';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // We'll update resource details later as requested
            if (_selectedFile.isNotEmpty) ...[
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
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
                    Text(
                      'Resource Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Will be updated later...',
                      style: TextStyle(
                        color: Colors.grey[600],
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
                    onPressed: _isUploading ? null : () => _uploadFile(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orangeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isUploading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Upload Document',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
              ),
            ],
            
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
  
  void _selectFile() async {
    // Simulate file selection
    setState(() {
      _selectedFile = 'Sample_Document.pdf';
    });
  }
  
  void _uploadFile() async {
    if (_selectedFile.isEmpty) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      // Simulate upload process
      await _uploadService.uploadFile(_selectedFile);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload successful!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to dashboard
      Navigator.pop(context);
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
} 