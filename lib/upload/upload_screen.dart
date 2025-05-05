import 'package:flutter/material.dart';
import 'upload_service.dart';

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
  final List<String> _categories = ['Lecture', 'Presentation', 'Notes', 'Handwritten Notes'];
  final List<String> _semesters = ['First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth', 'Seventh', 'Eighth'];
  final List<String> _departments = ['IT (Arfa Karim)'];
  
  @override
  void dispose() {
    // Dispose of text controllers
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
      body: _showDetailsScreen ? _buildDetailsScreen() : _buildSelectionScreen(height),
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
                  child: Icon(
                    Icons.cloud_upload,
                    size: 60,
                    color: blueColor,
                  ),
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
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Maximum file size: 30MB',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You can select up to 10 documents',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 40),
                
                // Select Document button
                ElevatedButton.icon(
                  onPressed: _selectFiles,
                  icon: Icon(Icons.file_upload),
                  label: Text(
                    'Select Documents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 30, 
                      vertical: 12
                    ),
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
    return SingleChildScrollView(
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
                    itemBuilder: (context, index) => _buildDocumentItem(_selectedFiles[index], index),
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
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: blueColor.withOpacity(0.2)),
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
                              child: Icon(Icons.edit_document, color: blueColor, size: 18),
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
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              buttonTheme: ButtonThemeData(
                                alignedDropdown: true,
                              ),
                              // Add custom dropdown styling
                              popupMenuTheme: PopupMenuThemeData(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<int>(
                                  value: _activeDocumentIndex,
                                  isExpanded: true,
                                  icon: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: orangeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(Icons.arrow_drop_down, color: orangeColor),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  borderRadius: BorderRadius.circular(15),
                                  // Limit height to show only 3 items
                                  menuMaxHeight: 156, // Height for approximately 3 items
                                  dropdownColor: Colors.white,
                                  elevation: 8,
                                  // Custom menu item builder
                                  selectedItemBuilder: (BuildContext context) {
                                    return List.generate(_selectedFiles.length, (index) {
                                      final fileName = _selectedFiles[index].nameController.text;
                                      
                                      return Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: orangeColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              _getIconForType(_selectedFiles[index].fileName),
                                              color: orangeColor,
                                              size: 18,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              fileName,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    });
                                  },
                                  items: List.generate(_selectedFiles.length, (index) {
                                    final fileName = _selectedFiles[index].nameController.text;
                                    final fileType = _getFileExtension(_selectedFiles[index].fileName);
                                    
                                    return DropdownMenuItem<int>(
                                      value: index,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _activeDocumentIndex == index 
                                            ? blueColor.withOpacity(0.1) 
                                            : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        margin: EdgeInsets.symmetric(vertical: 2),
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: _activeDocumentIndex == index
                                                  ? blueColor.withOpacity(0.15)
                                                  : orangeColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                boxShadow: _activeDocumentIndex == index ? [
                                                  BoxShadow(
                                                    color: blueColor.withOpacity(0.15),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  )
                                                ] : [],
                                              ),
                                              child: Icon(
                                                _getIconForType(_selectedFiles[index].fileName),
                                                color: _activeDocumentIndex == index
                                                  ? blueColor
                                                  : orangeColor,
                                                size: 18,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                fileName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: _activeDocumentIndex == index 
                                                      ? FontWeight.bold 
                                                      : FontWeight.normal,
                                                  fontSize: 15,
                                                  color: _activeDocumentIndex == index
                                                      ? blueColor
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  onChanged: (int? newIndex) {
                                    if (newIndex != null) {
                                      setState(() {
                                        _activeDocumentIndex = newIndex;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  TextField(
                    controller: _selectedFiles.isNotEmpty ? 
                      _selectedFiles[_activeDocumentIndex].nameController : TextEditingController(),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      hintText: 'Enter document name',
                    ),
                  ),
                  SizedBox(height: 15),
                ],
                
                // Document Type
                Text(
                  'Type:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: _selectedFiles.isNotEmpty ? 
                    _selectedFiles[_activeDocumentIndex].type : null,
                  hint: Text('Select Type'),
                  isExpanded: true,
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: orangeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.arrow_drop_down, color: orangeColor),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  // Limit height to show only 3 items
                  menuMaxHeight: 156, // Height for approximately 3 items
                  elevation: 8,
                  selectedItemBuilder: (BuildContext context) {
                    return _documentTypes.map((String type) {
                      return Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: orangeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_getIconForDocType(type), color: orangeColor, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              type,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: _documentTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: orangeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(_getIconForDocType(type), color: orangeColor, size: 18),
                            ),
                            SizedBox(width: 12),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (_applyToAllDocuments) {
                        // Apply to all documents
                        for (var doc in _selectedFiles) {
                          doc.type = newValue;
                        }
                      } else {
                        // Apply only to active document
                        _selectedFiles[_activeDocumentIndex].type = newValue;
                      }
                    });
                  },
                ),
                SizedBox(height: 15),
                
                // Category
                Text(
                  'Category:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: _selectedFiles.isNotEmpty ? 
                    _selectedFiles[_activeDocumentIndex].category : null,
                  hint: Text('Select Category'),
                  isExpanded: true,
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: orangeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.arrow_drop_down, color: orangeColor),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  // Limit height to show only 3 items
                  menuMaxHeight: 156, // Height for approximately 3 items
                  elevation: 8,
                  selectedItemBuilder: (BuildContext context) {
                    return _categories.map((String category) {
                      IconData categoryIcon;
                      switch(category) {
                        case 'Lecture':
                          categoryIcon = Icons.mic;
                          break;
                        case 'Presentation':
                          categoryIcon = Icons.slideshow;
                          break;
                        case 'Notes':
                          categoryIcon = Icons.note;
                          break;
                        case 'Handwritten Notes':
                          categoryIcon = Icons.edit_note;
                          break;
                        default:
                          categoryIcon = Icons.article;
                      }
                      
                      return Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: orangeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(categoryIcon, color: orangeColor, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: _categories.map((String category) {
                    IconData categoryIcon;
                    switch(category) {
                      case 'Lecture':
                        categoryIcon = Icons.mic;
                        break;
                      case 'Presentation':
                        categoryIcon = Icons.slideshow;
                        break;
                      case 'Notes':
                        categoryIcon = Icons.note;
                        break;
                      case 'Handwritten Notes':
                        categoryIcon = Icons.edit_note;
                        break;
                      default:
                        categoryIcon = Icons.article;
                    }
                    
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: orangeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(categoryIcon, color: orangeColor, size: 18),
                            ),
                            SizedBox(width: 12),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (_applyToAllDocuments) {
                        // Apply to all documents
                        for (var doc in _selectedFiles) {
                          doc.category = newValue;
                        }
                      } else {
                        // Apply only to active document
                        _selectedFiles[_activeDocumentIndex].category = newValue;
                      }
                    });
                  },
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: _selectedFiles.isNotEmpty ? 
                    _selectedFiles[_activeDocumentIndex].semester : null,
                  hint: Text('Select Semester'),
                  isExpanded: true,
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: orangeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.arrow_drop_down, color: orangeColor),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  // Limit height to show only 3 items
                  menuMaxHeight: 156, // Height for approximately 3 items
                  elevation: 8,
                  selectedItemBuilder: (BuildContext context) {
                    return _semesters.map((String semester) {
                      return Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: orangeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.calendar_today, color: orangeColor, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              semester,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: _semesters.map((String semester) {
                    return DropdownMenuItem<String>(
                      value: semester,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: orangeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.calendar_today, color: orangeColor, size: 18),
                            ),
                            SizedBox(width: 12),
                            Text(
                              semester,
                              style: TextStyle(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (_applyToAllDocuments) {
                        // Apply to all documents
                        for (var doc in _selectedFiles) {
                          doc.semester = newValue;
                        }
                      } else {
                        // Apply only to active document
                        _selectedFiles[_activeDocumentIndex].semester = newValue;
                      }
                    });
                  },
                ),
                SizedBox(height: 15),
                
                // Department
                Text(
                  'Department:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: _selectedFiles.isNotEmpty ? 
                    _selectedFiles[_activeDocumentIndex].department : 'IT (Arfa Karim)',
                  isExpanded: true,
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: orangeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.arrow_drop_down, color: orangeColor),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    filled: true,
                    fillColor: Colors.white,
                    helperText: 'Example: IT (Arfa Karim)',
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  // Limit height to show only 3 items
                  menuMaxHeight: 156, // Height for approximately 3 items
                  elevation: 8,
                  selectedItemBuilder: (BuildContext context) {
                    return _departments.map((String department) {
                      return Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: orangeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.school, color: orangeColor, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              department,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: _departments.map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: orangeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.school, color: orangeColor, size: 18),
                            ),
                            SizedBox(width: 12),
                            Text(
                              department,
                              style: TextStyle(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (_applyToAllDocuments) {
                        // Apply to all documents
                        for (var doc in _selectedFiles) {
                          doc.department = newValue;
                        }
                      } else {
                        // Apply only to active document
                        _selectedFiles[_activeDocumentIndex].department = newValue;
                      }
                    });
                  },
                ),
                SizedBox(height: 15),
                
                // Course Code
                Text(
                  'Course Code:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                TextField(
                  controller: _selectedFiles.isNotEmpty ? 
                    _selectedFiles[_activeDocumentIndex].courseCodeController : TextEditingController(),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    helperText: 'Examples: CS-101, IT-102',
                  ),
                  onChanged: (text) {
                    if (_applyToAllDocuments) {
                      // Apply to all documents
                      for (var doc in _selectedFiles) {
                        doc.courseCodeController.text = text;
                      }
                    }
                  },
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
                child: _isUploading
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
    );
  }
  
  // Build a single document item in the list
  Widget _buildDocumentItem(DocumentItem doc, int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _activeDocumentIndex == index ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _activeDocumentIndex == index ? blueColor : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          // Document icon based on type
          Icon(
            _getIconForType(doc.fileName),
            color: orangeColor,
            size: 24,
          ),
          SizedBox(width: 12),
          
          // Document name field (editable)
          Expanded(
            child: TextField(
              controller: doc.nameController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                hintText: 'Document name',
              ),
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
                  color: _activeDocumentIndex == index ? blueColor : Colors.grey[700],
                  fontWeight: _activeDocumentIndex == index ? FontWeight.bold : FontWeight.normal,
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
    // Simulate file selection from device storage
    List<String> mockFiles = [
      'Assignment1.pdf',
      'Lecture_Notes.docx',
      'Presentation.pptx',
    ];
    
    // Create document items with automatically detected file types
    List<DocumentItem> newFiles = mockFiles.map((fileName) {
      return DocumentItem(
        fileName: fileName,
        nameController: TextEditingController(text: fileName.split('.').first),
        courseCodeController: TextEditingController(),
        type: _detectFileType(fileName),
      );
    }).toList();
    
    setState(() {
      _selectedFiles = newFiles;
      _showDetailsScreen = true;
      _activeDocumentIndex = 0;
    });
  }
  
  void _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      // Simulate upload process for all files
      for (var doc in _selectedFiles) {
        await _uploadService.uploadFile(doc.fileName);
      }
      
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
  
  // Get file extension from filename
  String _getFileExtension(String fileName) {
    return fileName.split('.').last;
  }
  
  // Get icon based on document type (from dropdown selection)
  IconData _getIconForDocType(String? docType) {
    if (docType == null) return Icons.insert_drive_file;
    
    switch(docType.toUpperCase()) {
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
  
  DocumentItem({
    required this.fileName,
    required this.nameController,
    required this.courseCodeController,
    this.type,
    this.category,
    this.semester,
    this.department = 'IT (Arfa Karim)',
  });
} 