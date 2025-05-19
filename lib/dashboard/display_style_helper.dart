import 'package:flutter/material.dart';

/// Enum to define different display styles for document viewing
enum DisplayStyle { grid, list }

/// Helper class for managing document display styles in dashboard
class DisplayStyleHelper {
  /// Returns the icon for toggling display style based on current style
  static IconData getToggleIcon(DisplayStyle currentStyle) {
    return currentStyle == DisplayStyle.grid
        ? Icons.view_list
        : Icons.grid_view;
  }

  /// Returns the icon for the current display style (for indicator)
  static IconData getCurrentIcon(DisplayStyle currentStyle) {
    return currentStyle == DisplayStyle.grid
        ? Icons.grid_view
        : Icons.view_list;
  }

  /// Returns the description text for the current display style
  static String getDisplayStyleDescription(DisplayStyle currentStyle) {
    return currentStyle == DisplayStyle.grid ? 'Grid View' : 'List View';
  }

  /// Builds a grid view for documents
  static Widget buildGridView({
    required List<Map<String, dynamic>> documents,
    required double width,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return GridView.builder(
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return itemBuilder(doc);
      },
    );
  }

  /// Builds a list view for documents
  static Widget buildListView({
    required List<Map<String, dynamic>> documents,
    required double width,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return ListView.builder(
      physics: BouncingScrollPhysics(),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return itemBuilder(doc);
      },
    );
  }

  /// Builds a document list item view
  static Widget buildDocumentListItem({
    required Map<String, dynamic> document,
    required Color primaryColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    final fileName = document['fileName'] ?? 'Unnamed Document';
    final extension = document['extension']?.toLowerCase() ?? '';
    final course = document['course'] ?? '';
    final courseCode = document['courseCode'] ?? '';
    final department = document['department'] ?? '';
    final timeAgo = document['timeAgo'] ?? '';
    final bytes = document['bytes'] as int? ?? 0;

    // Format file size
    String fileSize = '';
    if (bytes > 0) {
      if (bytes < 1024) {
        fileSize = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        fileSize = '${(bytes / 1024).toStringAsFixed(0)} KB';
      } else {
        fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    // Determine file type color and icon
    Color iconColor;
    IconData fileIcon;

    switch (extension) {
      case 'pdf':
        iconColor = Color(0xFFE94235); // Red for PDF
        fileIcon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        iconColor = Color(0xFF2A5699); // Blue for Word
        fileIcon = Icons.description;
        break;
      case 'ppt':
      case 'pptx':
        iconColor = Color(0xFFD24726); // Orange for PowerPoint
        fileIcon = Icons.slideshow;
        break;
      default:
        iconColor = Colors.grey;
        fileIcon = Icons.insert_drive_file;
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // File type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: iconColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(fileIcon, color: iconColor, size: 28),
                ),
              ),
              SizedBox(width: 12),

              // Document info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (course.isNotEmpty)
                          _buildInfoChip(course, iconColor),
                        if (courseCode.isNotEmpty && course.isNotEmpty)
                          SizedBox(width: 4),
                        if (courseCode.isNotEmpty)
                          _buildInfoChip(courseCode, iconColor),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Spacer(),
                        Text(
                          fileSize,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          extension.toUpperCase(),
                          style: TextStyle(
                            color: iconColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action icon
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a display style indicator chip
  static Widget buildDisplayStyleIndicator({
    required DisplayStyle currentStyle,
    required Color indicatorColor,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: indicatorColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(getCurrentIcon(currentStyle), color: indicatorColor, size: 14),
          SizedBox(width: 4),
          Text(
            getDisplayStyleDescription(currentStyle),
            style: TextStyle(
              fontSize: 12,
              color: indicatorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, color: indicatorColor, size: 14),
          ),
        ],
      ),
    );
  }

  // Helper method to build info chips
  static Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
      ),
    );
  }
}
