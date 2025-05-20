import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/university_model.dart';
import '../services/university_service.dart';

class UniversitySelectionScreen extends StatefulWidget {
  final Function(String) onUniversitySelected;

  const UniversitySelectionScreen({
    Key? key,
    required this.onUniversitySelected,
  }) : super(key: key);

  @override
  _UniversitySelectionScreenState createState() => _UniversitySelectionScreenState();
}

class _UniversitySelectionScreenState extends State<UniversitySelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedUniversity;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isKeyboardVisible = false;
  
  List<University> _universities = [];
  List<University> _filteredUniversities = [];
  
  @override
  void initState() {
    super.initState();
    _loadUniversities();
    
    _searchController.addListener(() {
      _filterUniversities(_searchController.text);
    });
    
    _searchFocusNode.addListener(() {
      setState(() {
        _isKeyboardVisible = _searchFocusNode.hasFocus;
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadUniversities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final universities = await UniversityService.loadUniversities();
      
      setState(() {
        _universities = universities;
        _filteredUniversities = universities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load universities: $e";
        _isLoading = false;
      });
    }
  }
  
  void _filterUniversities(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUniversities = _universities;
      });
      return;
    }
    
    // Don't allow numbers or special characters in search
    if (_containsInvalidCharacters(query)) {
      return;
    }
    
    final sanitizedQuery = query.toLowerCase().trim();
    
    setState(() {
      _filteredUniversities = _universities.where((university) {
        final name = university.name.toLowerCase();
        final location = university.location.toLowerCase();
        
        // Check if name starts with the query (for alphabetical searching)
        if (name.startsWith(sanitizedQuery)) {
          return true;
        }
        
        // Check if any word in the name starts with the query
        if (name.split(' ').any((word) => word.startsWith(sanitizedQuery))) {
          return true;
        }
        
        // Check if name contains the query (for semantic searching)
        if (name.contains(sanitizedQuery)) {
          return true;
        }
        
        // Check location as secondary search field
        if (location.contains(sanitizedQuery)) {
          return true;
        }
        
        return false;
      }).toList();
    });
  }
  
  bool _containsInvalidCharacters(String text) {
    final RegExp regExp = RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]');
    return regExp.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            "Select Your University",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Color(0xFF125F9D),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Show header only when keyboard is not visible to save space
              if (!_isKeyboardVisible) ...[
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Which university do you attend?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF125F9D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "This helps us show you relevant materials for your institution.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
              ],
              // Always show the search box, just adjust padding
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0, 
                  vertical: _isKeyboardVisible ? 8.0 : 16.0
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: "Search for your university",
                    prefixIcon: Icon(Icons.search, color: Color(0xFF125F9D)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Color(0xFF125F9D)),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    errorText: _containsInvalidCharacters(_searchController.text) 
                        ? "Please use only letters for search" 
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF125F9D),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF125F9D),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF125F9D),
                        width: 2,
                      ),
                    ),
                  ),
                  inputFormatters: [
                    // Only allow letters and spaces
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  ],
                ),
              ),
              // Use Expanded with Flexible to ensure list takes available space
              Flexible(
                flex: 3,
                child: _buildUniversityList(),
              ),
              // Continue button - show in a smaller size when keyboard is visible
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: _isKeyboardVisible ? 8.0 : 16.0,
                ),
                child: ElevatedButton(
                  onPressed: _selectedUniversity == null
                      ? null
                      : () => widget.onUniversitySelected(_selectedUniversity!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF125F9D),
                    padding: EdgeInsets.symmetric(
                      vertical: _isKeyboardVisible ? 8.0 : 16.0
                    ),
                    minimumSize: Size(
                      double.infinity, 
                      _isKeyboardVisible ? 40 : 56
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: _isKeyboardVisible ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUniversityList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF125F9D),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUniversities,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF125F9D),
              ),
              child: Text("Try Again", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    
    if (_filteredUniversities.isEmpty) {
      return Center(
        child: Text(
          "No universities found matching your search",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: _isKeyboardVisible ? 4.0 : 8.0,
      ),
      child: ListView.builder(
        itemCount: _filteredUniversities.length,
        itemBuilder: (context, index) {
          final university = _filteredUniversities[index];
          return Card(
            margin: EdgeInsets.only(
              bottom: _isKeyboardVisible ? 4.0 : 8.0
            ),
            color: Color(0xFFF5F5F5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _selectedUniversity == university.name 
                    ? Color(0xFF125F9D) 
                    : Colors.grey.shade300,
                width: _selectedUniversity == university.name ? 2 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _isKeyboardVisible ? 4.0 : 8.0,
              ),
              title: Text(
                university.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF125F9D),
                  fontSize: _isKeyboardVisible ? 14.0 : 16.0,
                ),
              ),
              subtitle: university.location.isNotEmpty
                  ? Text(
                      university.location,
                      style: TextStyle(
                        fontSize: _isKeyboardVisible ? 12.0 : 14.0,
                      ),
                    )
                  : null,
              dense: _isKeyboardVisible,
              trailing: _selectedUniversity == university.name
                  ? Icon(
                      Icons.check_circle,
                      color: Color(0xFF125F9D),
                      size: _isKeyboardVisible ? 20.0 : 24.0,
                    )
                  : null,
              onTap: () {
                setState(() {
                  _selectedUniversity = university.name;
                  // Hide keyboard when a university is selected
                  FocusScope.of(context).unfocus();
                });
              },
              selected: _selectedUniversity == university.name,
              selectedTileColor: Colors.blue[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
} 