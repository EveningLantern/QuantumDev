import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON decoding/encoding
import 'dart:io'; // For file operations
import 'package:http/http.dart' as http; // HTTP package
import 'package:intl/intl.dart'; // For date formatting in filter dialog
import 'package:shared_preferences/shared_preferences.dart'; // For local persistence
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // For color picker
import 'package:file_picker/file_picker.dart'; // For file picking
import 'package:path_provider/path_provider.dart'; // For getting app directories
import '../Utils/formatting_toolbar.dart'; // Your formatting toolbar
import '../Utils/serach_filter.dart'; // Search and filter functionality

// Data model for a customer
class Customer {
  String id;
  String name;
  String dueDate;
  String vehicleNumber;
  String contactNumber;
  String model;
  String insurer;

  Customer({
    required this.id,
    required this.name,
    required this.dueDate,
    required this.vehicleNumber,
    required this.contactNumber,
    required this.model,
    required this.insurer,
  });

  // Factory constructor to create a Customer from JSON
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      dueDate: json['due_date'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      model: json['model'] ?? '',
      insurer: json['insurer'] ?? '',
    );
  }

  // Method to convert Customer to JSON for sending to backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'due_date': dueDate,
      'vehicle_number': vehicleNumber,
      'contact_number': contactNumber,
      'model': model,
      'insurer': insurer,
    };
  }
}

// Add this CellStyle class definition:
class CellStyle {
  bool isBold;
  bool isUnderline;
  Color? highlightColor;
  String fontFamily;

  CellStyle({
    this.isBold = false,
    this.isUnderline = false,
    this.highlightColor,
    this.fontFamily = 'Arial',
  });

  Map<String, dynamic> toJson() => {
        'isBold': isBold,
        'isUnderline': isUnderline,
        'highlightColor': highlightColor?.value, // Store color as int
        'fontFamily': fontFamily,
      };

  factory CellStyle.fromJson(Map<String, dynamic> json) => CellStyle(
        isBold: json['isBold'] ?? false,
        isUnderline: json['isUnderline'] ?? false,
        highlightColor: json['highlightColor'] != null
            ? Color(json['highlightColor'])
            : null,
        fontFamily: json['fontFamily'] ?? 'Arial',
      );

  CellStyle copyWith({
    bool? isBold,
    bool? isUnderline,
    Color? highlightColor,
    String? fontFamily,
    bool clearHighlight = false,
  }) {
    return CellStyle(
      isBold: isBold ?? this.isBold,
      isUnderline: isUnderline ?? this.isUnderline,
      highlightColor:
          clearHighlight ? null : (highlightColor ?? this.highlightColor),
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}
// End of CellStyle class definition

class ViewInExcelPage extends StatefulWidget {
  const ViewInExcelPage({super.key});

  @override
  State<ViewInExcelPage> createState() => _ViewInExcelPageState();
}

class _ViewInExcelPageState extends State<ViewInExcelPage>
    with SingleTickerProviderStateMixin {
  List<Customer> _customers = [];
  List<Customer> _displayedCustomers = []; // For filtered and sorted data
  bool _isLoading = true;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _insurerController = TextEditingController();

  Customer? _editingCustomer;
  final String _apiUrlBase = 'http://localhost:3000';

  bool _isFabOpen = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  // Column identifiers for sorting/filtering
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colDueDate = 'dueDate';
  static const String colVehicleNumber = 'vehicleNumber';
  static const String colContactNumber = 'contactNumber';
  static const String colModel = 'model';
  static const String colInsurer = 'insurer';

  // State Variables for Filtering and Sorting
  Map<String, dynamic> _activeFilters = {};
  String? _sortColumnKey;
  bool _sortAscending = true;

  // --- New State Variables for Cell Styling and Selection ---
  Map<String, CellStyle> _cellStyles = {};
  String?
      _selectedCellKey; // Stores key like "customerId_columnName" for single selection
  String? _hoveredCellKey; // Stores key for the cell currently being hovered

  // --- New State Variables for Enhanced Features ---
  String _currentFontFamily = 'Arial';
  Map<String, String> _cellValues = {}; // Store cell values including formulas

  // --- Search and Filter State Variables ---
  String _searchQuery = '';
  String _selectedSearchFilter = 'All';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchDataFromServer();
    _loadCellStyles(); // Load saved styles
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
        CurvedAnimation(
            parent: _fabAnimationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _nameController.dispose();
    _dueDateController.dispose();
    _vehicleNumberController.dispose();
    _contactNumberController.dispose();
    _modelController.dispose();
    _insurerController.dispose();
    _saveCellStyles(); // Save styles on dispose
    super.dispose();
  }

  // --- Cell Styling and Selection Logic ---
  Future<void> _loadCellStyles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stylesJson = prefs.getString('cellStyles');
    if (stylesJson != null) {
      final Map<String, dynamic> decodedMap = json.decode(stylesJson);
      setState(() {
        _cellStyles = decodedMap.map((key, value) =>
            MapEntry(key, CellStyle.fromJson(value as Map<String, dynamic>)));
      });
    }
  }

  Future<void> _saveCellStyles() async {
    final prefs = await SharedPreferences.getInstance();
    final String stylesJson = json
        .encode(_cellStyles.map((key, value) => MapEntry(key, value.toJson())));
    await prefs.setString('cellStyles', stylesJson);
  }

  String _getCellKey(String customerId, String columnName) {
    return '${customerId}_$columnName';
  }

  void _handleCellTap(String cellKey) {
    setState(() {
      if (_selectedCellKey == cellKey) {
        _selectedCellKey = null; // Deselect if tapped again
      } else {
        _selectedCellKey = cellKey;
      }
    });
  }

  CellStyle _getCurrentCellStyle() {
    return _selectedCellKey != null
        ? (_cellStyles[_selectedCellKey!] ?? CellStyle())
        : CellStyle();
  }

  void _applyStyleChange(CellStyle newStyle) {
    if (_selectedCellKey != null) {
      setState(() {
        _cellStyles[_selectedCellKey!] = newStyle;
      });
      _saveCellStyles(); // Save after each change
    }
  }

  void _toggleBold() {
    if (_selectedCellKey == null) return;
    final currentStyle = _getCurrentCellStyle();
    _applyStyleChange(currentStyle.copyWith(isBold: !currentStyle.isBold));
  }

  void _toggleUnderline() {
    if (_selectedCellKey == null) return;
    final currentStyle = _getCurrentCellStyle();
    _applyStyleChange(
        currentStyle.copyWith(isUnderline: !currentStyle.isUnderline));
  }

  void _pickHighlightColor() async {
    if (_selectedCellKey == null) return;
    final currentStyle = _getCurrentCellStyle();
    Color pickerColor = currentStyle.highlightColor ?? Colors.transparent;

    Color? newColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a highlight color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
              enableAlpha: false, // You can enable alpha if needed
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Clear'),
              onPressed: () {
                Navigator.of(context)
                    .pop(Colors.transparent); // Represent no color
              },
            ),
            TextButton(
              child: const Text('Got it'),
              onPressed: () {
                Navigator.of(context).pop(pickerColor);
              },
            ),
          ],
        );
      },
    );

    if (newColor != null) {
      _applyStyleChange(currentStyle.copyWith(
        highlightColor: newColor == Colors.transparent ? null : newColor,
        clearHighlight: newColor == Colors.transparent,
      ));
    }
  }

  // --- New Enhanced Feature Methods ---

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        if (fileName.endsWith('.csv')) {
          await _importFromCSV(file);
        } else {
          // For now, show a message that Excel import is coming soon
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Excel import feature coming soon! Please use CSV for now.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importFromCSV(File file) async {
    try {
      String contents = await file.readAsString();
      List<String> lines = contents.split('\n');

      if (lines.isEmpty) return;

      // Parse CSV and convert to Customer objects
      List<Customer> importedCustomers = [];
      for (int i = 1; i < lines.length; i++) {
        // Skip header
        if (lines[i].trim().isEmpty) continue;

        List<String> values = lines[i].split(',');
        if (values.length >= 7) {
          importedCustomers.add(Customer(
            id: values[0].trim(),
            name: values[1].trim(),
            dueDate: values[2].trim(),
            vehicleNumber: values[3].trim(),
            contactNumber: values[4].trim(),
            model: values[5].trim(),
            insurer: values[6].trim(),
          ));
        }
      }

      // Add imported customers to server
      for (Customer customer in importedCustomers) {
        await _addCustomerToServerSilent(customer);
      }

      _fetchDataFromServer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully imported ${importedCustomers.length} customers'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addCustomerToServerSilent(Customer customer) async {
    try {
      await http
          .post(
            Uri.parse('$_apiUrlBase/addCustomer'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(customer.toJson()),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Silent fail for bulk import
    }
  }

  Future<void> _exportExcel() async {
    try {
      // Create CSV content
      StringBuffer csvContent = StringBuffer();
      csvContent.writeln(
          'ID,Name,Due Date,Vehicle Number,Contact Number,Model,Insurer');

      for (Customer customer in _displayedCustomers) {
        csvContent.writeln(
            '${customer.id},${customer.name},${customer.dueDate},${customer.vehicleNumber},${customer.contactNumber},${customer.model},${customer.insurer}');
      }

      // Get downloads directory
      Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        // Fallback to external storage
        downloadsDir = Directory('/storage/emulated/0/Download');
      }

      String fileName =
          'customer_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      File file = File('${downloadsDir.path}/$fileName');

      await file.writeAsString(csvContent.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported to: ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changeFontStyle() {
    if (_selectedCellKey == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Font Family'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              'Arial',
              'Times New Roman',
              'Helvetica',
              'Courier New',
              'Verdana',
            ]
                .map((font) => ListTile(
                      title: Text(font, style: TextStyle(fontFamily: font)),
                      onTap: () {
                        final currentStyle = _getCurrentCellStyle();
                        _applyStyleChange(
                            currentStyle.copyWith(fontFamily: font));
                        setState(() {
                          _currentFontFamily = font;
                        });
                        Navigator.of(context).pop();
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  void _insertToday() {
    if (_selectedCellKey == null) return;
    String todayValue = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _setCellValue(_selectedCellKey!, 'TODAY(): $todayValue');
  }

  void _insertEdate() {
    if (_selectedCellKey == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController monthsController = TextEditingController();
        return AlertDialog(
          title: const Text('EDATE Function'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add months to today\'s date:'),
              const SizedBox(height: 10),
              TextField(
                controller: monthsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of months',
                  hintText: 'e.g., 3 for 3 months from now',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                int months = int.tryParse(monthsController.text) ?? 0;
                DateTime result =
                    DateTime.now().add(Duration(days: months * 30));
                String resultValue = DateFormat('yyyy-MM-dd').format(result);
                _setCellValue(
                    _selectedCellKey!, 'EDATE($months): $resultValue');
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _insertNetworkdays() {
    if (_selectedCellKey == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController startController = TextEditingController();
        final TextEditingController endController = TextEditingController();
        return AlertDialog(
          title: const Text('NETWORKDAYS Function'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                  hintText: '2024-01-01',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'End Date (YYYY-MM-DD)',
                  hintText: '2024-01-31',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                try {
                  DateTime start = DateTime.parse(startController.text);
                  DateTime end = DateTime.parse(endController.text);
                  int networkDays = _calculateNetworkDays(start, end);
                  _setCellValue(
                      _selectedCellKey!, 'NETWORKDAYS: $networkDays days');
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid date format')),
                  );
                }
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  int _calculateNetworkDays(DateTime start, DateTime end) {
    int days = 0;
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        days++;
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  void _insertMin() {
    if (_selectedCellKey == null) return;
    _showRangeDialog('MIN', (values) {
      double min = values.reduce((a, b) => a < b ? a : b);
      return 'MIN: $min';
    });
  }

  void _insertMax() {
    if (_selectedCellKey == null) return;
    _showRangeDialog('MAX', (values) {
      double max = values.reduce((a, b) => a > b ? a : b);
      return 'MAX: $max';
    });
  }

  void _showRangeDialog(
      String functionName, String Function(List<double>) calculator) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$functionName Function'),
          content: const Text(
              'This will calculate the function for all numeric values in the contact number column.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                List<double> numericValues = _customers
                    .map((c) => double.tryParse(c.contactNumber))
                    .where((v) => v != null)
                    .cast<double>()
                    .toList();

                if (numericValues.isNotEmpty) {
                  String result = calculator(numericValues);
                  _setCellValue(_selectedCellKey!, result);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No numeric values found')),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _setCellValue(String cellKey, String value) {
    setState(() {
      _cellValues[cellKey] = value;
    });
  }

  // Helper to build DataCell with selection and styling
  DataCell _buildStyledCell(
      String customerId, String columnName, String cellText) {
    final cellKey = _getCellKey(customerId, columnName);
    final style = _cellStyles[cellKey] ?? CellStyle();
    final bool isSelected = _selectedCellKey == cellKey;
    final bool isHovered = _hoveredCellKey == cellKey;

    // Check if cell has a custom value (formula result)
    final displayText = _cellValues[cellKey] ?? cellText;

    return DataCell(
      MouseRegion(
        onEnter: (_) {
          if (mounted) {
            // Ensure widget is still in the tree
            setState(() => _hoveredCellKey = cellKey);
          }
        },
        onExit: (_) {
          if (mounted) {
            // Ensure widget is still in the tree
            setState(() => _hoveredCellKey = null);
          }
        },
        child: GestureDetector(
          onTap: () => _handleCellTap(cellKey),
          child: AnimatedContainer(
            duration: const Duration(
                milliseconds: 150), // Duration for hover animation
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            transform: (isHovered && !isSelected)
                ? (Matrix4.identity()
                  ..scale(1.03)) // Slightly scale up on hover if not selected
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              // The container's main background color can be set here if needed,
              // otherwise, it will be transparent or inherit from DataTable.
              // style.highlightColor is now used for text background.
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).primaryColorDark, width: 2)
                  : null,
              borderRadius:
                  BorderRadius.circular(4.0), // Consistent border radius
            ),
            child: Text(
              displayText,
              style: TextStyle(
                fontFamily: style.fontFamily,
                fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
                decoration: style.isUnderline
                    ? TextDecoration.underline
                    : TextDecoration.none,
                backgroundColor: style
                    .highlightColor, // Apply highlight color to the text's background
                // You can also set text color here if needed, e.g., based on highlight
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // --- Data Fetching and CRUD Operations ---
  Future<void> _fetchDataFromServer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeFilters.clear(); // Reset filters on new data fetch
      _sortColumnKey = null;
      _sortAscending = true;
    });
    try {
      final response = await http
          .get(Uri.parse('$_apiUrlBase/getAll'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          _customers =
              jsonData.map((jsonItem) => Customer.fromJson(jsonItem)).toList();
          _applySearchAndFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load data: ${response.statusCode} ${response.reasonPhrase}';
          _isLoading = false;
        });
        debugPrint(
            'Failed to load data: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
      debugPrint('Error fetching data: $e');
    }
  }

  Future<void> _addCustomerToServer() async {
    if (_formKey.currentState!.validate()) {
      final newCustomer = Customer(
        id: '', // Server will generate ID
        name: _nameController.text,
        dueDate: _dueDateController.text,
        vehicleNumber: _vehicleNumberController.text,
        contactNumber: _contactNumberController.text,
        model: _modelController.text,
        insurer: _insurerController.text,
      );

      Navigator.of(context).pop(); // Close dialog
      setState(() {
        _isFabOpen = false;
        _fabAnimationController.reverse();
      });

      try {
        final response = await http
            .post(
              Uri.parse('$_apiUrlBase/addCustomer'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(newCustomer.toJson()),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 201 || response.statusCode == 200) {
          _fetchDataFromServer();
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Customer added successfully!'),
                backgroundColor: Colors.green[700]),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to add customer: ${response.statusCode} ${response.reasonPhrase}'),
                backgroundColor: Colors.red[700]),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding customer: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  Future<void> _updateCustomerToServer() async {
    if (_formKey.currentState!.validate() && _editingCustomer != null) {
      final updatedCustomerData = {
        'name': _nameController.text,
        'due_date': _dueDateController.text,
        'vehicle_number': _vehicleNumberController.text,
        'contact_number': _contactNumberController.text,
        'model': _modelController.text,
        'insurer': _insurerController.text,
      };

      final String originalName = _editingCustomer!.name;
      final String originalModel = _editingCustomer!.model;
      final String originalVehicleNumber = _editingCustomer!.vehicleNumber;

      Navigator.of(context).pop(); // Close dialog

      try {
        final updateUrl =
            Uri.parse('$_apiUrlBase/update').replace(queryParameters: {
          'name': originalName,
          'model': originalModel,
          'vehicle_number': originalVehicleNumber,
        });

        final response = await http
            .put(
              updateUrl,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(updatedCustomerData),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _fetchDataFromServer();
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Customer updated successfully!'),
                backgroundColor: Colors.blue[700]),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to update customer: ${response.statusCode} ${response.reasonPhrase}'),
                backgroundColor: Colors.red[700]),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating customer: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  Future<void> _deleteCustomerFromServer(Customer customer) async {
    // Confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete "${customer.name}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red[700])),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final deleteUrl =
            Uri.parse('$_apiUrlBase/delete').replace(queryParameters: {
          'name': customer.name,
          'model': customer.model,
          'vehicle_number': customer.vehicleNumber,
        });
        final response =
            await http.delete(deleteUrl).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _fetchDataFromServer(); // Refresh data
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Customer deleted successfully!'),
                backgroundColor: Colors.orange[700]),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to delete customer: ${response.statusCode} ${response.reasonPhrase}'),
                backgroundColor: Colors.red[700]),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting customer: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _dueDateController.clear();
    _vehicleNumberController.clear();
    _contactNumberController.clear();
    _modelController.clear();
    _insurerController.clear();
    _editingCustomer = null;
  }

  // --- Dialogs for Add/Edit ---
  Future<void> _showAddCustomerDialog() async {
    _clearForm();
    _editingCustomer = null;
    return _showCustomerDialog(isEditing: false);
  }

  Future<void> _showEditCustomerDialog(Customer customer) async {
    _editingCustomer = customer;
    _nameController.text = customer.name;
    _dueDateController.text = customer.dueDate;
    _vehicleNumberController.text = customer.vehicleNumber;
    _contactNumberController.text = customer.contactNumber;
    _modelController.text = customer.model;
    _insurerController.text = customer.insurer;
    return _showCustomerDialog(isEditing: true);
  }

  Future<void> _showCustomerDialog({required bool isEditing}) async {
    final String dialogTitle = isEditing
        ? 'Edit "${_editingCustomer?.name ?? "Customer"}"'
        : 'Add New Customer';
    final IconData titleIcon =
        isEditing ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded;
    final Function()? onSave =
        isEditing ? _updateCustomerToServer : _addCustomerToServer;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(children: [
            Icon(titleIcon, color: Theme.of(context).primaryColor),
            SizedBox(width: 10),
            Text(dialogTitle)
          ]),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                          labelText: 'Name', icon: Icon(Icons.person_outline)),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter name' : null),
                  TextFormField(
                      controller: _dueDateController,
                      decoration: InputDecoration(
                          labelText: 'Due Date (e.g., YYYY-MM-DD)',
                          icon: Icon(Icons.calendar_today_outlined)),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter due date' : null),
                  TextFormField(
                      controller: _vehicleNumberController,
                      decoration: InputDecoration(
                          labelText: 'Vehicle Number',
                          icon: Icon(Icons.directions_car_outlined)),
                      validator: (value) => value!.isEmpty
                          ? 'Please enter vehicle number'
                          : null),
                  TextFormField(
                      controller: _contactNumberController,
                      decoration: InputDecoration(
                          labelText: 'Contact Number',
                          icon: Icon(Icons.phone_outlined)),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value!.isEmpty
                          ? 'Please enter contact number'
                          : null),
                  TextFormField(
                      controller: _modelController,
                      decoration: InputDecoration(
                          labelText: 'Model',
                          icon: Icon(Icons.car_rental_outlined)),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter model' : null),
                  TextFormField(
                      controller: _insurerController,
                      decoration: InputDecoration(
                          labelText: 'Insurer',
                          icon: Icon(Icons.shield_outlined)),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter insurer' : null),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearForm();
                }),
            ElevatedButton.icon(
                icon: Icon(isEditing
                    ? Icons.save_as_outlined
                    : Icons.add_circle_outline),
                label: Text(isEditing ? 'Save Changes' : 'Add Customer'),
                onPressed: onSave),
          ],
        );
      },
    );
  }

  // --- Search and Filter Methods ---
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applySearchAndFilters();
  }

  void _onClearSearch() {
    setState(() {
      _searchQuery = '';
      _isSearchVisible = false;
    });
    _applySearchAndFilters();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchQuery = '';
        _selectedSearchFilter = 'All';
        _applySearchAndFilters();
      }
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedSearchFilter = filter;
    });
    _applySearchAndFilters();
  }

  void _applySearchAndFilters() {
    List<Customer> filtered = List.from(_customers);

    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      filtered = SearchFilterUtils.filterList<Customer>(
        filtered,
        _searchQuery,
        _selectedSearchFilter,
        (customer) => customer.id,
        (customer) => customer.name,
        (customer) => customer.vehicleNumber,
      );
    }

    // Apply existing filters
    _activeFilters.forEach((key, value) {
      if (value == null || (value is String && value.isEmpty)) return;

      filtered = filtered.where((customer) {
        String customerValue = '';
        switch (key) {
          case colId:
            customerValue = customer.id;
            break;
          case colName:
            customerValue = customer.name;
            break;
          case colDueDate:
            customerValue = customer.dueDate;
            break;
          case colVehicleNumber:
            customerValue = customer.vehicleNumber;
            break;
          case colContactNumber:
            customerValue = customer.contactNumber;
            break;
          case colModel:
            customerValue = customer.model;
            break;
          case colInsurer:
            customerValue = customer.insurer;
            break;
        }
        if (value is DateTime) {
          try {
            DateTime customerDate =
                DateFormat('yyyy-MM-dd').parse(customerValue);
            return customerDate.isAtSameMomentAs(value);
          } catch (e) {
            return false;
          }
        } else {
          return customerValue
              .toLowerCase()
              .contains(value.toString().toLowerCase());
        }
      }).toList();
    });

    // Apply sorting
    if (_sortColumnKey != null) {
      filtered.sort((a, b) {
        String aValue = '';
        String bValue = '';
        switch (_sortColumnKey) {
          case colId:
            aValue = a.id;
            bValue = b.id;
            break;
          case colName:
            aValue = a.name;
            bValue = b.name;
            break;
          case colDueDate:
            aValue = a.dueDate;
            bValue = b.dueDate;
            break;
          case colVehicleNumber:
            aValue = a.vehicleNumber;
            bValue = b.vehicleNumber;
            break;
          case colContactNumber:
            aValue = a.contactNumber;
            bValue = b.contactNumber;
            break;
          case colModel:
            aValue = a.model;
            bValue = b.model;
            break;
          case colInsurer:
            aValue = a.insurer;
            bValue = b.insurer;
            break;
        }
        int comparison = aValue.compareTo(bValue);
        return _sortAscending ? comparison : -comparison;
      });
    }

    setState(() {
      _displayedCustomers = filtered;
    });
  }

  String _getCustomerValueForSort(Customer customer, String columnKey) {
    switch (columnKey) {
      case colId:
        return customer.id;
      case colName:
        return customer.name;
      case colDueDate:
        return customer
            .dueDate; // Consider parsing to DateTime for correct date sorting if format is consistent
      case colVehicleNumber:
        return customer.vehicleNumber;
      case colContactNumber:
        return customer.contactNumber;
      case colModel:
        return customer.model;
      case colInsurer:
        return customer.insurer;
      default:
        return '';
    }
  }

  void _handleSort(String columnKey) {
    setState(() {
      if (_sortColumnKey == columnKey) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnKey = columnKey;
        _sortAscending = true;
      }
      _applySearchAndFilters();
    });
  }

  DataColumn _buildInteractiveDataColumn(String label, String columnKey) {
    return DataColumn(
      label: Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800]))),
            if (_sortColumnKey == columnKey)
              Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: Colors.green[700],
              ),
          ],
        ),
      ),
      onSort: (columnIndex, ascending) => _handleSort(columnKey),
    );
  }

  // --- FAB Animation ---
  void _toggleFabMenu() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
        _editingCustomer = null; // Clear editing state if menu is closed
      }
    });
  }

  void _animateFab(Function action) {
    // If FAB is open for editing, save/close should handle it.
    // If FAB is in 'add' state, perform action.
    setState(() {
      if (_isFabOpen && _editingCustomer != null) {
        // FAB was in 'edit' mode (though now dialog handles edit)
        // This case might be redundant if edit is always via dialog
        _isFabOpen = false;
        _fabAnimationController.reverse();
        // Navigator.of(context).pop(); // Dialog is popped by its own close/save buttons
      } else {
        // FAB is in 'add' state or closed
        _isFabOpen = true;
        _fabAnimationController.forward();
        _editingCustomer = null; // Ensure we are adding
        _showAddCustomerDialog();
      }
    });
  }

  // New helper method to determine text color based on background
  Color _getTextColorForBackground(Color backgroundColor) {
    // Use luminance to decide if the background is dark or light
    // Threshold 0.5 is a common starting point
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final currentStyle = _getCurrentCellStyle();
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Search Bar (conditionally visible)
            if (_isSearchVisible) ...[
              SearchFilter(
                onSearchChanged: _onSearchChanged,
                onClearSearch: _onClearSearch,
                searchQuery: _searchQuery,
                onFilterChanged: _onFilterChanged,
                selectedFilter: _selectedSearchFilter,
              ),
              const SizedBox(height: 10),
            ],
            // Always display FormattingToolbar
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: FormattingToolbar(
                isBoldActive: currentStyle.isBold,
                isUnderlineActive: currentStyle.isUnderline,
                onToggleBold: _toggleBold,
                onToggleUnderline: _toggleUnderline,
                onPickHighlightColor: _pickHighlightColor,
                onImportExcel: _importExcel,
                onExportExcel: _exportExcel,
                onChangeFontStyle: _changeFontStyle,
                onInsertToday: _insertToday,
                onInsertEdate: _insertEdate,
                onInsertNetworkdays: _insertNetworkdays,
                onInsertMin: _insertMin,
                onInsertMax: _insertMax,
                currentFontFamily: _currentFontFamily,
                isEnabled: _selectedCellKey != null,
              ),
            ),
            // const SizedBox(height: 20), // Original spacing, adjust as needed
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Expanded(
                  child: Center(
                      child: Text(_errorMessage!,
                          style:
                              TextStyle(color: Colors.red[700], fontSize: 16))))
            else if (_customers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.grey[400], size: 48),
                      const SizedBox(height: 10),
                      Text('No customer data found on the server.',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600])),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Try Refreshing'),
                        onPressed: _fetchDataFromServer,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white),
                      )
                    ],
                  ),
                ),
              )
            else if (_displayedCustomers.isEmpty && _customers.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off_rounded,
                          color: Colors.orange[400], size: 48),
                      const SizedBox(height: 10),
                      Text('No customers match the current filters.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.orange[700])),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: Icon(Icons.clear_all_rounded),
                        label: Text('Clear All Filters'),
                        onPressed: () {
                          setState(() {
                            _activeFilters.clear();
                            _applySearchAndFilters();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white),
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                        return Colors.green[100]; // Light green for header
                      }),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        return Colors
                            .green[50]; // Very light green for data rows
                      }),
                      border: TableBorder.all(
                          color: Colors.green.shade300, width: 1),
                      sortColumnIndex: _sortColumnKey == null
                          ? null
                          : [
                              colId,
                              colName,
                              colDueDate,
                              colVehicleNumber,
                              colContactNumber,
                              colModel,
                              colInsurer
                            ].indexOf(_sortColumnKey!),
                      sortAscending: _sortAscending,
                      columns: [
                        _buildInteractiveDataColumn('ID', colId),
                        _buildInteractiveDataColumn('Name', colName),
                        _buildInteractiveDataColumn('Due Date', colDueDate),
                        _buildInteractiveDataColumn(
                            'Vehicle No.', colVehicleNumber),
                        _buildInteractiveDataColumn(
                            'Contact No.', colContactNumber),
                        _buildInteractiveDataColumn('Model', colModel),
                        _buildInteractiveDataColumn('Insurer', colInsurer),
                        const DataColumn(
                            label: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _displayedCustomers.map((customer) {
                        return DataRow(
                          cells: [
                            _buildStyledCell(customer.id, colId, customer.id),
                            _buildStyledCell(
                                customer.id, colName, customer.name),
                            _buildStyledCell(
                                customer.id, colDueDate, customer.dueDate),
                            _buildStyledCell(customer.id, colVehicleNumber,
                                customer.vehicleNumber),
                            _buildStyledCell(customer.id, colContactNumber,
                                customer.contactNumber),
                            _buildStyledCell(
                                customer.id, colModel, customer.model),
                            _buildStyledCell(
                                customer.id, colInsurer, customer.insurer),
                            DataCell(
                              // Actions cell remains standard
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: Colors.blue[700]),
                                    onPressed: () =>
                                        _showEditCustomerDialog(customer),
                                    tooltip: 'Edit Customer',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red[700]),
                                    onPressed: () =>
                                        _deleteCustomerFromServer(customer),
                                    tooltip: 'Delete Customer',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            // Search FAB
            onPressed: _toggleSearch,
            backgroundColor:
                _isSearchVisible ? Colors.orange[700] : Colors.purple[700],
            foregroundColor: Colors.white,
            elevation: 6.0,
            heroTag: 'searchFab', // Unique heroTag
            tooltip: _isSearchVisible ? 'Hide Search' : 'Search Records',
            child: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            // Refresh FAB
            onPressed: _fetchDataFromServer,
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 6.0,
            heroTag: 'refreshFab', // Unique heroTag
            tooltip: 'Refresh Data',
            child: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            // Add Customer FAB
            onPressed: () =>
                _animateFab(_showAddCustomerDialog), // Simplified call
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            elevation: 6.0,
            heroTag: 'addCustomerFab', // Unique heroTag
            tooltip: 'Add New Customer',
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close, // Default icon, can be changed
              progress: _fabAnimationController,
            ),
          ),
        ],
      ),
    );
  }
}
