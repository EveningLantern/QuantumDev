import 'package:flutter/material.dart';

class FormattingToolbar extends StatelessWidget {
  final bool isBoldActive;
  final bool isUnderlineActive;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleUnderline;
  final VoidCallback onPickHighlightColor;
  final bool isEnabled; // New parameter to control if toolbar is enabled

  // New callbacks for additional features
  final VoidCallback onImportExcel;
  final VoidCallback onExportExcel;
  final VoidCallback onChangeFontStyle;
  final VoidCallback onInsertToday;
  final VoidCallback onInsertEdate;
  final VoidCallback onInsertNetworkdays;
  final VoidCallback onInsertMin;
  final VoidCallback onInsertMax;
  final String currentFontFamily;

  const FormattingToolbar({
    super.key,
    required this.isBoldActive,
    required this.isUnderlineActive,
    required this.onToggleBold,
    required this.onToggleUnderline,
    required this.onPickHighlightColor,
    required this.onImportExcel,
    required this.onExportExcel,
    required this.onChangeFontStyle,
    required this.onInsertToday,
    required this.onInsertEdate,
    required this.onInsertNetworkdays,
    required this.onInsertMin,
    required this.onInsertMax,
    this.currentFontFamily = 'Arial',
    this.isEnabled = true, // Default to enabled
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.grey[200] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isEnabled ? 0.3 : 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            if (!isEnabled)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Text(
                  'Select a cell to format',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else ...[
              // Import/Export Section
              _buildSection([
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'Import Excel',
                  color: Colors.green[700],
                  onPressed: onImportExcel,
                ),
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Export Excel',
                  color: Colors.blue[700],
                  onPressed: onExportExcel,
                ),
              ]),

              _buildDivider(),

              // Font and Formatting Section
              _buildSection([
                PopupMenuButton<String>(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.font_download, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        currentFontFamily,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                  tooltip: 'Font Family',
                  onSelected: (String value) => onChangeFontStyle(),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'Arial', child: Text('Arial')),
                    const PopupMenuItem(
                        value: 'Times New Roman',
                        child: Text('Times New Roman')),
                    const PopupMenuItem(
                        value: 'Helvetica', child: Text('Helvetica')),
                    const PopupMenuItem(
                        value: 'Courier New', child: Text('Courier New')),
                    const PopupMenuItem(
                        value: 'Verdana', child: Text('Verdana')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  tooltip: 'Bold',
                  color: isBoldActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  onPressed: onToggleBold,
                ),
                IconButton(
                  icon: const Icon(Icons.format_underline),
                  tooltip: 'Underline',
                  color: isUnderlineActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  onPressed: onToggleUnderline,
                ),
                IconButton(
                  icon: const Icon(Icons.format_color_fill),
                  tooltip: 'Highlight Color',
                  color: Colors.black87,
                  onPressed: onPickHighlightColor,
                ),
              ]),

              _buildDivider(),

              // Date Functions Section
              _buildSection([
                PopupMenuButton<String>(
                  icon: const Icon(Icons.date_range, color: Colors.purple),
                  tooltip: 'Date Functions',
                  onSelected: (String value) {
                    switch (value) {
                      case 'TODAY':
                        onInsertToday();
                        break;
                      case 'EDATE':
                        onInsertEdate();
                        break;
                      case 'NETWORKDAYS':
                        onInsertNetworkdays();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'TODAY',
                      child: Row(
                        children: [
                          Icon(Icons.today, size: 16),
                          SizedBox(width: 8),
                          Text('TODAY()'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'EDATE',
                      child: Row(
                        children: [
                          Icon(Icons.event, size: 16),
                          SizedBox(width: 8),
                          Text('EDATE()'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'NETWORKDAYS',
                      child: Row(
                        children: [
                          Icon(Icons.business, size: 16),
                          SizedBox(width: 8),
                          Text('NETWORKDAYS()'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),

              _buildDivider(),

              // Math Functions Section
              _buildSection([
                PopupMenuButton<String>(
                  icon: const Icon(Icons.functions, color: Colors.orange),
                  tooltip: 'Math Functions',
                  onSelected: (String value) {
                    switch (value) {
                      case 'MIN':
                        onInsertMin();
                        break;
                      case 'MAX':
                        onInsertMax();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'MIN',
                      child: Row(
                        children: [
                          Icon(Icons.trending_down, size: 16),
                          SizedBox(width: 8),
                          Text('MIN()'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'MAX',
                      child: Row(
                        children: [
                          Icon(Icons.trending_up, size: 16),
                          SizedBox(width: 8),
                          Text('MAX()'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[400],
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
