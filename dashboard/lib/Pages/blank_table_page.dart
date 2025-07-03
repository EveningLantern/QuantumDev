import 'package:flutter/material.dart';

class BlankTablePage extends StatefulWidget {
  final String pageName;
  final Function(String, String, String)
      onCellChanged; // Callback for cell changes
  final Function(String?) onCellSelected; // Callback for cell selection

  const BlankTablePage({
    super.key,
    required this.pageName,
    required this.onCellChanged,
    required this.onCellSelected,
  });

  @override
  State<BlankTablePage> createState() => _BlankTablePageState();
}

class _BlankTablePageState extends State<BlankTablePage> {
  // Table data storage
  final Map<String, String> _tableData = {};
  String? _selectedCellKey;

  // Table configuration
  final int _numRows = 20;
  final int _numColumns = 10;

  // Column headers (A, B, C, etc.)
  List<String> get _columnHeaders {
    return List.generate(_numColumns,
        (index) => String.fromCharCode(65 + index)); // A, B, C, D, etc.
  }

  // Row headers (1, 2, 3, etc.)
  List<String> get _rowHeaders {
    return List.generate(_numRows, (index) => (index + 1).toString());
  }

  String _getCellKey(int row, int col) {
    return '${_columnHeaders[col]}${row + 1}';
  }

  void _onCellTap(int row, int col) {
    final cellKey = _getCellKey(row, col);
    setState(() {
      _selectedCellKey = cellKey;
    });
    // Notify parent about cell selection
    widget.onCellSelected(cellKey);
  }

  void _onCellChanged(int row, int col, String value) {
    final cellKey = _getCellKey(row, col);
    setState(() {
      _tableData[cellKey] = value;
    });
    // Notify parent about the change
    widget.onCellChanged(widget.pageName, cellKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Page title
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.pageName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Table
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      // Header row
                      Row(
                        children: [
                          // Top-left corner cell
                          Container(
                            width: 50,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                          ),
                          // Column headers
                          ..._columnHeaders.map((header) => Container(
                                width: 100,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Text(
                                    header,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),

                      // Data rows
                      ...List.generate(_numRows, (rowIndex) {
                        return Row(
                          children: [
                            // Row header
                            Container(
                              width: 50,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  _rowHeaders[rowIndex],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),

                            // Data cells
                            ...List.generate(_numColumns, (colIndex) {
                              final cellKey = _getCellKey(rowIndex, colIndex);
                              final isSelected = _selectedCellKey == cellKey;

                              return GestureDetector(
                                onTap: () => _onCellTap(rowIndex, colIndex),
                                child: Container(
                                  width: 100,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue[100]
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue[300]!
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: TextFormField(
                                    initialValue: _tableData[cellKey] ?? '',
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(8),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    onChanged: (value) => _onCellChanged(
                                        rowIndex, colIndex, value),
                                    onTap: () => _onCellTap(rowIndex, colIndex),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
