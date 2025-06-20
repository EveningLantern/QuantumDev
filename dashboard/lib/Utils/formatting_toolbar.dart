import 'package:flutter/material.dart';

class FormattingToolbar extends StatelessWidget {
  final bool isBoldActive;
  final bool isUnderlineActive;
  final bool isItalicActive;
  final bool isStrikethroughActive;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleUnderline;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleStrikethrough;
  final VoidCallback onPickTextColor; // New callback for text color
  final bool isEnabled; // New parameter to control if toolbar is enabled

  // New callbacks for additional features
  final VoidCallback onImportExcel;
  final VoidCallback onExportExcel;
  final Function(String)
      onChangeFontStyle; // Changed to accept font name parameter
  final VoidCallback onInsertToday;
  final VoidCallback onInsertEdate;
  final VoidCallback onInsertNetworkdays;
  final VoidCallback onInsertMin;
  final VoidCallback onInsertMax;
  final VoidCallback onInsertSigmoid; // New callback for sigmoid function
  final VoidCallback onInsertIntegration; // New callback for integration
  final VoidCallback onUndo; // New callback for undo
  final VoidCallback onRedo; // New callback for redo
  final String currentFontFamily;
  final VoidCallback onDeleteRecord; // New callback for record deletion
  final VoidCallback onInsertCountIf; // New callback for Count If function

  const FormattingToolbar({
    super.key,
    required this.isBoldActive,
    required this.isUnderlineActive,
    required this.isItalicActive,
    required this.isStrikethroughActive,
    required this.onToggleBold,
    required this.onToggleUnderline,
    required this.onToggleItalic,
    required this.onToggleStrikethrough,
    required this.onPickTextColor,
    required this.onImportExcel,
    required this.onExportExcel,
    required this.onChangeFontStyle,
    required this.onInsertToday,
    required this.onInsertEdate,
    required this.onInsertNetworkdays,
    required this.onInsertMin,
    required this.onInsertMax,
    required this.onInsertSigmoid, // Required parameter for sigmoid function
    required this.onInsertIntegration, // Required parameter for integration
    required this.onUndo, // Required parameter for undo
    required this.onRedo, // Required parameter for redo
    required this.onDeleteRecord, // Required parameter for delete functionality
    required this.onInsertCountIf, // Required parameter for Count If function
    this.currentFontFamily = 'Arial',
    this.isEnabled = true, // Default to enabled
  });

  // Professional font list similar to Excel/Word
  static const List<String> _professionalFonts = [
    'Arial',
    'Arial Black',
    'Arial Narrow',
    'Calibri',
    'Cambria',
    'Comic Sans MS',
    'Consolas',
    'Courier New',
    'Georgia',
    'Helvetica',
    'Impact',
    'Lucida Console',
    'Lucida Sans Unicode',
    'Microsoft Sans Serif',
    'Palatino Linotype',
    'Segoe UI',
    'Tahoma',
    'Times New Roman',
    'Trebuchet MS',
    'Verdana',
  ];

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
              // Undo/Redo Section
              _buildSection([
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  color: Colors.indigo[700],
                  onPressed: onUndo,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  color: Colors.indigo[700],
                  onPressed: onRedo,
                ),
              ]),

              _buildDivider(),

              // Import/Export Section
              _buildSection([
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Import Excel',
                  color: Colors.green[700],
                  onPressed: onImportExcel,
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'Export Excel',
                  color: Colors.blue[700],
                  onPressed: onExportExcel,
                ),
              ]),

              _buildDivider(),

              // Font and Formatting Section
              _buildSection([
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.font_download,
                              color: Colors.black87, size: 16),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              currentFontFamily,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                    tooltip: 'Font Family',
                    onSelected: (String value) => onChangeFontStyle(value),
                    itemBuilder: (BuildContext context) => _professionalFonts
                        .map((font) => PopupMenuItem<String>(
                              value: font,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: font == currentFontFamily
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.1)
                                      : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    if (font == currentFontFamily)
                                      Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    if (font == currentFontFamily)
                                      const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        font,
                                        style: TextStyle(
                                          fontFamily: font,
                                          fontSize: 14,
                                          fontWeight: font == currentFontFamily
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: font == currentFontFamily
                                              ? Theme.of(context).primaryColor
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  tooltip: 'Bold',
                  color: isBoldActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  onPressed: onToggleBold,
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic),
                  tooltip: 'Italic',
                  color: isItalicActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  onPressed: onToggleItalic,
                ),
                IconButton(
                  icon: const Icon(Icons.format_underlined),
                  tooltip: 'Underline',
                  color: isUnderlineActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  onPressed: onToggleUnderline,
                ),
                IconButton(
                  icon: const Icon(Icons.format_strikethrough),
                  tooltip: 'Strikethrough',
                  color: isStrikethroughActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                  onPressed: onToggleStrikethrough,
                ),
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.format_color_text),
                      Positioned(
                        bottom: 2,
                        left: 2,
                        right: 2,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  tooltip: 'Text Color',
                  color: Colors.black87,
                  onPressed: onPickTextColor,
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

              _buildDivider(),

              // Count If Function Section
              _buildSection([
                IconButton(
                  icon: const Icon(Icons.format_list_numbered),
                  tooltip: 'Count If',
                  color: Colors.teal[700],
                  onPressed: onInsertCountIf,
                ),
              ]),

              _buildDivider(),

              // Delete Record Section
              _buildSection([
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'Delete Record',
                  color: Colors.red[700],
                  onPressed: onDeleteRecord,
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
