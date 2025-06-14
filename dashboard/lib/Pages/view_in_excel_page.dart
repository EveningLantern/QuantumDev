import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON decoding/encoding
import 'dart:io'; // For file operations
import 'dart:math'; // For mathematical functions like exp
import 'package:http/http.dart' as http; // HTTP package
import 'package:intl/intl.dart'; // For date formatting in filter dialog
import 'package:shared_preferences/shared_preferences.dart'; // For local persistence
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // For color picker
import 'package:file_picker/file_picker.dart'; // For file picking
import 'package:path_provider/path_provider.dart'; // For getting app directories
import '../Utils/formatting_toolbar.dart'; // Your formatting toolbar
import '../Utils/serach_filter.dart'; // Search and filter functionality
import '../endpoints.dart'; // Backend endpoints
import '../parsing/date_parsing.dart'; // For date parsing functions

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
    // Parse the due_date from ISO format to YYYY-MM-DD
    String rawDueDate = json['due_date'] ?? '';
    String formattedDueDate = parseIsoDateToYYYYMMDD(rawDueDate);

    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      dueDate: formattedDueDate,
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
  final String _apiUrlBase = Endpoints.baseUrl;

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

  // --- Function Result Display Variables ---
  String? _functionResult; // Stores the result of the last function calculation
  Color _functionResultColor =
      Colors.grey[900]!; // Color for the function result text
  bool _showFunctionResult = false; // Controls visibility of the result panel

  // --- Search and Filter State Variables ---
  String _searchQuery = '';
  String _selectedSearchFilter = 'All';
  bool _isSearchVisible = false;

  // --- Inline Editing State Variables ---
  String? _editingCellKey;
  TextEditingController _cellEditController = TextEditingController();
  FocusNode _cellEditFocusNode = FocusNode();

  // --- Undo/Redo State Variables ---
  List<Map<String, dynamic>> _undoStack = [];
  List<Map<String, dynamic>> _redoStack = [];
  static const int _maxUndoRedoStackSize =
      50; // Limit stack size to prevent memory issues

  // --- Column Resizing State Variables ---
  Map<String, double> _columnWidths = {
    colId: 80.0,
    colName: 150.0,
    colDueDate: 120.0,
    colVehicleNumber: 120.0,
    colContactNumber: 120.0,
    colModel: 120.0,
    colInsurer: 120.0,
  };
  String? _resizingColumn;
  double _startX = 0.0;
  double _startWidth = 0.0;

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
    _cellEditController.dispose();
    _cellEditFocusNode.dispose();
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
      // Save current state for undo before making changes
      _saveStateForUndo();

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
            SnackBar(
              content: Text(
                  'Excel import feature coming soon! Please use CSV for now.'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing file: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _importFromCSV(File file) async {
    // For tracking the current customer being processed
    String currentCustomerName = '';
    BuildContext? dialogContext;
    StateSetter? dialogSetState;

    try {
      String contents = await file.readAsString();
      List<String> lines = contents.split('\n');

      if (lines.isEmpty) return;

      // Show progress dialog with live updates
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          dialogContext = context;
          return StatefulBuilder(
            builder: (context, setStateFunction) {
              dialogSetState = setStateFunction;
              return AlertDialog(
                title: const Text('Importing Data'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Currently processing: $currentCustomerName'),
                  ],
                ),
              );
            },
          );
        },
      );

      // Skip the first line (header) and start from the second line
      List<Customer> importedCustomers = [];
      int successCount = 0;

      // Process each line starting from the second line (index 1)
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        // Split by comma - expecting 4 values
        List<String> values = lines[i].split(',');

        // Check if we have at least 4 values
        if (values.length < 4) {
          // Skip malformed rows
          continue;
        }

        // Generate a unique ID
        String id = DateTime.now().millisecondsSinceEpoch.toString() +
            '_' +
            i.toString();

        // Map values according to specified order:
        // 1st value -> name
        // 2nd value -> dueDate
        // 3rd value -> vehicleNumber
        // 4th value -> contactNumber
        // 5th value -> model (if available)
        // 6th value -> insurer (if available)

        String name = values[0].trim();

        // Update the dialog to show current record being processed
        if (dialogSetState != null) {
          // Use the stored StatefulBuilder's setState function
          dialogSetState!(() {
            currentCustomerName = name;
          });
        }

        // Check if any required value is missing or empty
        if (name.isEmpty) {
          // Close progress dialog
          if (dialogContext != null) {
            Navigator.of(dialogContext!).pop();
          }

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import stopped: Missing name in row ${i + 1}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );

          // Stop processing if any required value is missing
          return;
        }

        // Create customer with the values in the specified order
        Customer customer = Customer(
          id: id,
          name: name,
          dueDate: values.length > 1 ? values[1].trim() : '',
          vehicleNumber: values.length > 2 ? values[2].trim() : '',
          contactNumber: values.length > 3 ? values[3].trim() : '',
          model: values.length > 4 ? values[4].trim() : '',
          insurer: values.length > 5 ? values[5].trim() : '',
        );

        // Add to server immediately
        try {
          await _addCustomerToServerSilent(customer);
          successCount++;
          importedCustomers.add(customer);
        } catch (e) {
          // Close progress dialog
          if (dialogContext != null) {
            Navigator.of(dialogContext!).pop();
          }

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Import stopped at row ${i + 1}: Failed to add customer "$name"'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );

          // Stop processing on first error
          return;
        }
      }

      // Close progress dialog
      if (dialogContext != null) {
        Navigator.of(dialogContext!).pop();
      }

      // Refresh data
      _fetchDataFromServer();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Successful',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Successfully imported $successCount customers',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Close progress dialog if it's open
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Error parsing CSV: $e',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _addCustomerToServerSilent(Customer customer) async {
    try {
      await http
          .post(
            Uri.parse(Endpoints.addEndpoint),
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

      // Format current date and time for filename
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
      String fileName = 'customer_data_${formattedDate}.csv';
      File file = File('${downloadsDir.path}/$fileName');

      await file.writeAsString(csvContent.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported to: ${file.path}'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _changeFontStyle(String fontFamily) {
    if (_selectedCellKey == null) return;

    final currentStyle = _getCurrentCellStyle();
    _applyStyleChange(currentStyle.copyWith(fontFamily: fontFamily));
    setState(() {
      _currentFontFamily = fontFamily;
    });
  }

  void _changeFontSize(double fontSize) {
    if (_selectedCellKey == null) return;

    // Note: CellStyle doesn't currently support fontSize, but we can extend it later
    // For now, we'll just acknowledge the change
    setState(() {
      // You might want to add fontSize to CellStyle class and handle it here
    });
  }

  void _toggleItalic() {
    if (_selectedCellKey == null) return;
    // Note: CellStyle doesn't currently support italic, but we can extend it later
    // For now, we'll just acknowledge the change
    setState(() {
      // You might want to add isItalic to CellStyle class and handle it here
    });
  }

  void _toggleStrikethrough() {
    if (_selectedCellKey == null) return;
    // Note: CellStyle doesn't currently support strikethrough, but we can extend it later
    // For now, we'll just acknowledge the change
    setState(() {
      // You might want to add isStrikethrough to CellStyle class and handle it here
    });
  }

  void _pickTextColor() {
    if (_selectedCellKey == null) return;
    // Note: CellStyle doesn't currently support text color, but we can extend it later
    // For now, we'll just acknowledge the change
    setState(() {
      // You might want to add textColor to CellStyle class and handle it here
    });
  }

  // Method to handle record deletion
  void _deleteRecord() async {
    // Check if a cell is selected
    if (_selectedCellKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a record to delete'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
      return;
    }

    // Extract the customer ID from the selected cell key
    final customerId = _selectedCellKey!.split('_')[0];

    // Find the customer to delete
    final customerIndex = _customers.indexWhere((c) => c.id == customerId);
    if (customerIndex == -1) return;

    final customer = _customers[customerIndex];

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                  'Are you sure you want to delete the record for ${customer.name}?\n\nThis action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('DELETE'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      // Call the delete endpoint with the correct format
      // Using the format: https://manojsir-backend.vercel.app/delete?name=Trial Name&model=TVS&contact_number=8912345645

      // Find the customer to get all required fields
      final customer = _customers.firstWhere((c) => c.id == customerId);

      final deleteUrl = Uri.parse(Endpoints.deleteEndpoint).replace(
        queryParameters: {
          'name': customer.name,
          'model': customer.model,
          'contact_number': customer.contactNumber,
        },
      );

      // Using GET request instead of DELETE as the API might be expecting GET
      final response = await http.get(
        deleteUrl,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to delete record: ${response.statusCode} ${response.reasonPhrase}');
      }

      // Update local state
      setState(() {
        _customers.removeAt(customerIndex);
        _selectedCellKey = null;
      });

      _applySearchAndFilters();

      // Show success message with animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Record for ${customer.name} has been successfully deleted',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Failed to delete record: $e'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _insertToday() {
    if (_selectedCellKey == null) {
      setState(() {
        _functionResult = 'Please select a cell with a date value first';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get the selected cell's value
    String cellKey = _selectedCellKey!;
    String cellValue = '';

    // Extract the customer ID and column name from the cell key
    List<String> keyParts = cellKey.split('_');
    if (keyParts.length >= 2) {
      String customerId = keyParts[0];
      String columnName = keyParts[1];

      // Find the customer with the matching ID
      Customer? customer;
      try {
        customer = _displayedCustomers.firstWhere(
          (c) => c.id == customerId,
        );
      } catch (e) {
        // Customer not found
        customer = null;
      }

      if (customer != null) {
        // Get the value based on the column name
        if (columnName == colDueDate) {
          cellValue = customer.dueDate;
        } else {
          setState(() {
            _functionResult = 'Please select a cell with a date value';
            _functionResultColor = Colors.orange[700]!;
            _showFunctionResult = true;
          });
          return;
        }
      }
    }

    // Parse the selected date
    DateTime? selectedDate = tryParseDate(cellValue);
    if (selectedDate == null) {
      setState(() {
        _functionResult = 'Invalid date format in the selected cell';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get today's date (without time)
    DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Calculate the difference in days
    int differenceInDays = selectedDate.difference(today).inDays;

    String resultMessage;
    Color resultColor;

    if (differenceInDays < 0) {
      resultMessage = 'Due date passed by ${-differenceInDays} days';
      resultColor = Colors.red[700]!; // Red for overdue
    } else if (differenceInDays == 0) {
      resultMessage = 'Due date is today';
      resultColor = Colors.orange[700]!; // Orange for due today
    } else if (differenceInDays <= 7) {
      resultMessage = '${differenceInDays} days left for the due date';
      resultColor = Colors.amber[700]!; // Amber for due soon (within a week)
    } else {
      resultMessage = '${differenceInDays} days left for the due date';
      resultColor = Colors.green[700]!; // Green for plenty of time
    }

    setState(() {
      _functionResult = resultMessage;
      _functionResultColor = resultColor;
      _showFunctionResult = true;
    });
  }

  void _insertEdate() {
    if (_selectedCellKey == null) {
      setState(() {
        _functionResult = 'Please select a cell with a date value first';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get the selected cell's value
    String cellKey = _selectedCellKey!;
    String cellValue = '';

    // Extract the customer ID and column name from the cell key
    List<String> keyParts = cellKey.split('_');
    if (keyParts.length < 2) {
      setState(() {
        _functionResult = 'Invalid cell selection';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    String customerId = keyParts[0];
    String columnName = keyParts[1];

    // Find the customer with the matching ID
    Customer? customer;
    try {
      customer = _displayedCustomers.firstWhere(
        (c) => c.id == customerId,
      );
    } catch (e) {
      // Customer not found
      setState(() {
        _functionResult = 'Customer not found';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get the value based on the column name
    if (columnName == colDueDate) {
      cellValue = customer.dueDate;
    } else {
      setState(() {
        _functionResult = 'Please select a cell with a date value';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Parse the selected date
    DateTime? selectedDate = tryParseDate(cellValue);
    if (selectedDate == null) {
      setState(() {
        _functionResult = 'Invalid date format in the selected cell';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController daysController =
            TextEditingController(text: '0');
        final TextEditingController monthsController =
            TextEditingController(text: '0');
        final TextEditingController yearsController =
            TextEditingController(text: '0');

        // For live preview of the new date
        ValueNotifier<String> previewDate = ValueNotifier<String>(cellValue);

        // Function to update the preview date
        void updatePreviewDate() {
          int days = int.tryParse(daysController.text) ?? 0;
          int months = int.tryParse(monthsController.text) ?? 0;
          int years = int.tryParse(yearsController.text) ?? 0;

          if (selectedDate != null) {
            DateTime newDate = selectedDate;

            try {
              // Add years and months
              newDate = DateTime(
                newDate.year + years,
                newDate.month + months,
                newDate.day,
                newDate.hour,
                newDate.minute,
                newDate.second,
              );

              // Add days
              newDate = newDate.add(Duration(days: days));

              // Format the result
              previewDate.value = formatDateToYYYYMMDD(newDate);
            } catch (e) {
              previewDate.value = "Invalid date";
            }
          }
        }

        // Add listeners to update preview when values change
        daysController.addListener(updatePreviewDate);
        monthsController.addListener(updatePreviewDate);
        yearsController.addListener(updatePreviewDate);

        return AlertDialog(
          title: const Text('EDATE Function'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current date: $cellValue',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text('Add to the current date:'),
              const SizedBox(height: 10),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: monthsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Months',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yearsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Years',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: previewDate,
                builder: (context, value, child) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('New date will be:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            )),
                        const SizedBox(height: 5),
                        Text(
                          value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: value == "Invalid date"
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                // Parse input values with default of 0
                int days = int.tryParse(daysController.text) ?? 0;
                int months = int.tryParse(monthsController.text) ?? 0;
                int years = int.tryParse(yearsController.text) ?? 0;

                // Calculate the new date
                DateTime newDate;
                String resultValue;

                try {
                  newDate = selectedDate!;

                  // Add years and months
                  newDate = DateTime(
                    newDate.year + years,
                    newDate.month + months,
                    newDate.day,
                    newDate.hour,
                    newDate.minute,
                    newDate.second,
                  );

                  // Add days
                  newDate = newDate.add(Duration(days: days));

                  // Format the result
                  resultValue = formatDateToYYYYMMDD(newDate);
                } catch (e) {
                  // Show error message for invalid date
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Invalid date calculation. Please check your inputs.'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                  return; // Don't proceed with the update
                }

                // Update the customer object
                if (columnName == colDueDate) {
                  // Create a copy of the customer with the updated due date
                  Customer updatedCustomer = Customer(
                    id: customer!.id,
                    name: customer.name,
                    dueDate: resultValue,
                    vehicleNumber: customer.vehicleNumber,
                    contactNumber: customer.contactNumber,
                    model: customer.model,
                    insurer: customer.insurer,
                  );

                  // Update the customer on the server and in the local lists
                  try {
                    // Create a customer object with only the due date field for the server update
                    Customer serverUpdateCustomer = Customer(
                      id: customer!.id,
                      name: '',
                      dueDate: resultValue,
                      vehicleNumber: '',
                      contactNumber: '',
                      model: '',
                      insurer: '',
                    );

                    // Show loading indicator
                    setState(() {
                      _functionResult = 'Updating date on server...';
                      _functionResultColor = Colors.blue[700]!;
                      _showFunctionResult = true;
                    });

                    // Update on the server
                    _updateCustomerInServer(serverUpdateCustomer).then((_) {
                      // Update the customer in the displayed list
                      setState(() {
                        int index = _displayedCustomers
                            .indexWhere((c) => c.id == customerId);
                        if (index != -1) {
                          _displayedCustomers[index] = updatedCustomer;
                        }

                        // Also update in the main list
                        index =
                            _customers.indexWhere((c) => c.id == customerId);
                        if (index != -1) {
                          _customers[index] = updatedCustomer;
                        }

                        // Show the result
                        _functionResult =
                            'Date updated: $cellValue → $resultValue';
                        _functionResultColor = Colors.green[700]!;
                        _showFunctionResult = true;
                      });
                    }).catchError((error) {
                      setState(() {
                        _functionResult =
                            'Error updating date on server: ${error.toString()}';
                        _functionResultColor = Colors.red[700]!;
                        _showFunctionResult = true;
                      });
                    });
                  } catch (e) {
                    setState(() {
                      _functionResult = 'Error: ${e.toString()}';
                      _functionResultColor = Colors.red[700]!;
                      _showFunctionResult = true;
                    });
                  }
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

  void _insertNetworkdays() {
    if (_selectedCellKey == null) {
      setState(() {
        _functionResult = 'Please select a cell with a date value first';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get the selected cell's value
    String cellKey = _selectedCellKey!;
    String cellValue = '';

    // Extract the customer ID and column name from the cell key
    List<String> keyParts = cellKey.split('_');
    if (keyParts.length < 2) {
      setState(() {
        _functionResult = 'Invalid cell selection';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    String customerId = keyParts[0];
    String columnName = keyParts[1];

    // Find the customer with the matching ID
    Customer? customer;
    try {
      customer = _displayedCustomers.firstWhere(
        (c) => c.id == customerId,
      );
    } catch (e) {
      // Customer not found
      setState(() {
        _functionResult = 'Customer not found';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get the value based on the column name
    if (columnName == colDueDate) {
      cellValue = customer.dueDate;
    } else {
      setState(() {
        _functionResult = 'Please select a cell with a date value';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Parse the selected date
    DateTime? selectedDate = tryParseDate(cellValue);
    if (selectedDate == null) {
      setState(() {
        _functionResult = 'Invalid date format in the selected cell';
        _functionResultColor = Colors.red[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Get today's date (without time)
    DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Calculate working days between today and the selected date
    int workingDays;
    bool isInFuture;

    if (selectedDate.isAfter(today)) {
      // Selected date is in the future
      workingDays = _calculateNetworkDays(today, selectedDate);
      isInFuture = true;
    } else if (selectedDate.isBefore(today)) {
      // Selected date is in the past
      workingDays = _calculateNetworkDays(selectedDate, today);
      isInFuture = false;
    } else {
      // Selected date is today
      workingDays = 0;
      isInFuture = true;
    }

    // Format the result message
    String resultMessage;
    Color resultColor;

    if (workingDays == 0) {
      resultMessage = 'The selected date is today (no working days difference)';
      resultColor = Colors.blue[700]!;
    } else if (isInFuture) {
      resultMessage = '$workingDays working days left until the selected date';
      resultColor = workingDays <= 5 ? Colors.amber[700]! : Colors.green[700]!;
    } else {
      resultMessage =
          '$workingDays working days have passed since the selected date';
      resultColor = Colors.red[700]!;
    }

    // Generate a visual representation of the working days
    String visualRepresentation = _generateWorkingDaysVisual(
        isInFuture ? today : selectedDate,
        isInFuture ? selectedDate : today,
        isInFuture);

    setState(() {
      _functionResult = '$resultMessage\n\n$visualRepresentation';
      _functionResultColor = resultColor;
      _showFunctionResult = true;
    });
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

  String _generateWorkingDaysVisual(
      DateTime start, DateTime end, bool isInFuture) {
    // Limit to showing at most 30 days to avoid overwhelming the UI
    final int maxDaysToShow = 30;

    // Calculate total days between dates
    int totalDays = end.difference(start).inDays + 1;

    // If more than maxDaysToShow, we'll show the first and last few days
    bool showEllipsis = totalDays > maxDaysToShow;

    // Prepare the visual representation
    StringBuffer visual = StringBuffer();

    // Add header with date range
    visual.writeln(
        '${formatDateToYYYYMMDD(start)} to ${formatDateToYYYYMMDD(end)}:');
    visual.writeln('');

    // Function to add a day representation
    void addDayVisual(DateTime date, bool isWorkingDay) {
      String dayName = _getDayName(date.weekday);
      String dayStr = formatDateToYYYYMMDD(date);
      String symbol = isWorkingDay ? '📅' : '🚫';

      // Highlight today
      bool isToday = date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;

      if (isToday) {
        visual.writeln('$symbol $dayStr ($dayName) - TODAY');
      } else {
        visual.writeln('$symbol $dayStr ($dayName)');
      }
    }

    // Add days to the visual
    DateTime current = start;
    int daysShown = 0;

    // Show first days
    while (daysShown < (showEllipsis ? maxDaysToShow ~/ 2 : maxDaysToShow) &&
        (current.isBefore(end) || current.isAtSameMomentAs(end))) {
      bool isWorkingDay = current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday;
      addDayVisual(current, isWorkingDay);
      current = current.add(const Duration(days: 1));
      daysShown++;
    }

    // Add ellipsis if needed
    if (showEllipsis) {
      visual.writeln('...');

      // Skip to show the last few days
      int daysToSkip = totalDays - maxDaysToShow;
      current = start.add(Duration(days: daysToSkip + (maxDaysToShow ~/ 2)));

      // Show last days
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        bool isWorkingDay = current.weekday != DateTime.saturday &&
            current.weekday != DateTime.sunday;
        addDayVisual(current, isWorkingDay);
        current = current.add(const Duration(days: 1));
      }
    }

    return visual.toString();
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  void _insertMin() {
    // Get all due dates from customers
    List<DateTime> dueDates = _getValidDueDates();

    if (dueDates.isEmpty) {
      setState(() {
        _functionResult = 'No valid due dates found in the records';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Find the oldest (minimum) date
    DateTime oldestDate = dueDates.reduce((a, b) => a.isBefore(b) ? a : b);
    String formattedDate = formatDateToYYYYMMDD(oldestDate);

    // Find the customer with this date
    Customer? customer = _findCustomerByDueDate(formattedDate);

    // Calculate days from today
    DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int daysDifference = oldestDate.difference(today).inDays;
    String timeDescription;

    if (daysDifference < 0) {
      timeDescription = '${-daysDifference} days ago';
    } else if (daysDifference == 0) {
      timeDescription = 'today';
    } else {
      timeDescription = 'in $daysDifference days';
    }

    // Create detailed result message
    StringBuffer resultMessage = StringBuffer();
    resultMessage
        .writeln('MIN: Oldest due date is $formattedDate ($timeDescription)');

    if (customer != null) {
      resultMessage.writeln('\nCustomer Details:');
      resultMessage.writeln('Name: ${customer.name}');
      resultMessage.writeln('Vehicle: ${customer.vehicleNumber}');
      resultMessage.writeln('Contact: ${customer.contactNumber}');
      resultMessage.writeln('Model: ${customer.model}');
      resultMessage.writeln('Insurer: ${customer.insurer}');
    }

    // Set color based on date
    Color resultColor;
    if (daysDifference < 0) {
      resultColor = Colors.red[700]!; // Past date
    } else if (daysDifference == 0) {
      resultColor = Colors.blue[700]!; // Today
    } else if (daysDifference <= 7) {
      resultColor = Colors.amber[700]!; // Coming soon
    } else {
      resultColor = Colors.green[700]!; // Future date
    }

    // Add a calendar visualization for context
    String calendarView = _generateDateContextVisual(oldestDate);

    setState(() {
      _functionResult = resultMessage.toString() + "\n\n" + calendarView;
      _functionResultColor = resultColor;
      _showFunctionResult = true;
    });
  }

  void _insertMax() {
    // Get all due dates from customers
    List<DateTime> dueDates = _getValidDueDates();

    if (dueDates.isEmpty) {
      setState(() {
        _functionResult = 'No valid due dates found in the records';
        _functionResultColor = Colors.orange[700]!;
        _showFunctionResult = true;
      });
      return;
    }

    // Find the farthest (maximum) date
    DateTime farthestDate = dueDates.reduce((a, b) => a.isAfter(b) ? a : b);
    String formattedDate = formatDateToYYYYMMDD(farthestDate);

    // Find the customer with this date
    Customer? customer = _findCustomerByDueDate(formattedDate);

    // Calculate days from today
    DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int daysDifference = farthestDate.difference(today).inDays;
    String timeDescription;

    if (daysDifference < 0) {
      timeDescription = '${-daysDifference} days ago';
    } else if (daysDifference == 0) {
      timeDescription = 'today';
    } else {
      timeDescription = 'in $daysDifference days';
    }

    // Create detailed result message
    StringBuffer resultMessage = StringBuffer();
    resultMessage
        .writeln('MAX: Farthest due date is $formattedDate ($timeDescription)');

    if (customer != null) {
      resultMessage.writeln('\nCustomer Details:');
      resultMessage.writeln('Name: ${customer.name}');
      resultMessage.writeln('Vehicle: ${customer.vehicleNumber}');
      resultMessage.writeln('Contact: ${customer.contactNumber}');
      resultMessage.writeln('Model: ${customer.model}');
      resultMessage.writeln('Insurer: ${customer.insurer}');
    }

    // Set color based on date
    Color resultColor;
    if (daysDifference < 0) {
      resultColor = Colors.red[700]!; // Past date
    } else if (daysDifference == 0) {
      resultColor = Colors.blue[700]!; // Today
    } else if (daysDifference <= 7) {
      resultColor = Colors.amber[700]!; // Coming soon
    } else {
      resultColor = Colors.green[700]!; // Future date
    }

    // Add a calendar visualization for context
    String calendarView = _generateDateContextVisual(farthestDate);

    setState(() {
      _functionResult = resultMessage.toString() + "\n\n" + calendarView;
      _functionResultColor = resultColor;
      _showFunctionResult = true;
    });
  }

  // Helper method to get all valid due dates
  List<DateTime> _getValidDueDates() {
    return _customers
        .map((c) => tryParseDate(c.dueDate))
        .where((date) => date != null)
        .cast<DateTime>()
        .toList();
  }

  // Helper method to find a customer by due date
  Customer? _findCustomerByDueDate(String dueDate) {
    try {
      return _customers.firstWhere((c) => c.dueDate == dueDate);
    } catch (e) {
      return null;
    }
  }

  // Generate a visual representation of a date in context
  String _generateDateContextVisual(DateTime targetDate) {
    // Get today's date without time
    DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Calculate the start and end dates for the visualization
    // Show 7 days before and after the target date
    DateTime startDate = targetDate.subtract(const Duration(days: 7));
    DateTime endDate = targetDate.add(const Duration(days: 7));

    // Prepare the visual representation
    StringBuffer visual = StringBuffer();

    // Add header
    visual.writeln('Date Context (±7 days):');
    visual.writeln('');

    // Function to add a day representation
    void addDayVisual(DateTime date) {
      String dayName = _getDayName(date.weekday);
      String dayStr = formatDateToYYYYMMDD(date);

      // Determine the symbol based on the date
      String symbol;
      if (date.year == targetDate.year &&
          date.month == targetDate.month &&
          date.day == targetDate.day) {
        symbol = '🎯'; // Target date
      } else if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        symbol = '📅'; // Today
      } else if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        symbol = '🚫'; // Weekend
      } else {
        symbol = '📆'; // Regular weekday
      }

      // Format the line with appropriate highlighting
      if (date.year == targetDate.year &&
          date.month == targetDate.month &&
          date.day == targetDate.day) {
        visual.writeln('$symbol $dayStr ($dayName) - TARGET DATE');
      } else if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        visual.writeln('$symbol $dayStr ($dayName) - TODAY');
      } else {
        visual.writeln('$symbol $dayStr ($dayName)');
      }
    }

    // Add days to the visual
    DateTime current = startDate;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      addDayVisual(current);
      current = current.add(const Duration(days: 1));
    }

    return visual.toString();
  }

  // --- Sigmoid Function ---
  void _insertSigmoid() {
    _showInputDialog('SIGMOID', 'Enter a value for x:', (value) {
      try {
        double x = double.parse(value);
        double result = 1 / (1 + exp(-x)); // Sigmoid function: 1/(1+e^(-x))
        return 'SIGMOID($x): ${result.toStringAsFixed(4)}';
      } catch (e) {
        return 'Error: Invalid input';
      }
    });
  }

  // --- Integration Function ---
  void _insertIntegration() {
    _showIntegrationDialog();
  }

  void _showIntegrationDialog() {
    final TextEditingController functionController = TextEditingController();
    final TextEditingController lowerBoundController = TextEditingController();
    final TextEditingController upperBoundController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Definite Integration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: functionController,
                decoration: const InputDecoration(
                  labelText: 'Function (e.g., x^2)',
                  hintText: 'Enter a function of x',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: lowerBoundController,
                      decoration: const InputDecoration(
                        labelText: 'Lower Bound (a)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: upperBoundController,
                      decoration: const InputDecoration(
                        labelText: 'Upper Bound (b)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                // In a real implementation, we would calculate the integral here
                // For now, we'll just display the formula
                final func = functionController.text.isEmpty
                    ? 'x^2'
                    : functionController.text;
                final a = lowerBoundController.text.isEmpty
                    ? '0'
                    : lowerBoundController.text;
                final b = upperBoundController.text.isEmpty
                    ? '1'
                    : upperBoundController.text;

                setState(() {
                  _functionResult = 'INTEGRATE($func, $a, $b)';
                  _showFunctionResult = true;
                });

                Navigator.of(context).pop();
              },
              child: const Text('INSERT'),
            ),
          ],
        );
      },
    );
  }

  void _showInputDialog(
      String title, String hint, String Function(String) calculator) {
    final TextEditingController inputController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: inputController,
            decoration: InputDecoration(
              hintText: hint,
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final result = calculator(inputController.text);
                setState(() {
                  _functionResult = result;
                  _showFunctionResult = true;
                });
                Navigator.of(context).pop();
              },
              child: const Text('CALCULATE'),
            ),
          ],
        );
      },
    );
  }

  // --- Undo/Redo Methods ---
  void _saveStateForUndo() {
    // Create a snapshot of the current state
    final currentState = {
      'cellStyles': Map<String, CellStyle>.from(_cellStyles),
      'cellValues': Map<String, String>.from(_cellValues),
      'selectedCellKey': _selectedCellKey,
    };

    // Add to undo stack
    _undoStack.add(currentState);

    // Clear redo stack when a new action is performed
    _redoStack.clear();

    // Limit stack size
    if (_undoStack.length > _maxUndoRedoStackSize) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      // Show message that there's nothing to undo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to undo'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Save current state to redo stack
    final currentState = {
      'cellStyles': Map<String, CellStyle>.from(_cellStyles),
      'cellValues': Map<String, String>.from(_cellValues),
      'selectedCellKey': _selectedCellKey,
    };
    _redoStack.add(currentState);

    // Restore previous state
    final previousState = _undoStack.removeLast();
    setState(() {
      _cellStyles = previousState['cellStyles'] as Map<String, CellStyle>;
      _cellValues = previousState['cellValues'] as Map<String, String>;
      _selectedCellKey = previousState['selectedCellKey'] as String?;
    });

    // Show undo message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Undo successful'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      // Show message that there's nothing to redo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to redo'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Save current state to undo stack
    final currentState = {
      'cellStyles': Map<String, CellStyle>.from(_cellStyles),
      'cellValues': Map<String, String>.from(_cellValues),
      'selectedCellKey': _selectedCellKey,
    };
    _undoStack.add(currentState);

    // Restore next state
    final nextState = _redoStack.removeLast();
    setState(() {
      _cellStyles = nextState['cellStyles'] as Map<String, CellStyle>;
      _cellValues = nextState['cellValues'] as Map<String, String>;
      _selectedCellKey = nextState['selectedCellKey'] as String?;
    });

    // Show redo message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redo successful'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // The _showRangeDialog function has been replaced with direct implementations
  // in _insertMin and _insertMax that work specifically with due dates

  // Count If function implementation
  void _insertCountIf() {
    // Define the fields that can be selected
    final List<String> fields = ['Name', 'Due Date', 'Insurer', 'Model'];
    String selectedField = fields[0]; // Default to Name

    // Get the selected cell value if available
    String defaultValue = '';
    if (_selectedCellKey != null) {
      // Extract the customer ID and column name from the cell key
      List<String> keyParts = _selectedCellKey!.split('_');
      if (keyParts.length >= 2) {
        String customerId = keyParts[0];
        String columnName = keyParts[1];

        // Find the customer
        Customer? customer = _customers.firstWhere(
          (c) => c.id == customerId,
          orElse: () => null as Customer,
        );

        if (customer != null) {
          // Get the value based on the column name and set the appropriate field
          if (columnName == 'name') {
            defaultValue = customer.name;
            selectedField = 'Name';
          } else if (columnName == 'dueDate') {
            defaultValue = customer.dueDate;
            selectedField = 'Due Date';
          } else if (columnName == 'insurer') {
            defaultValue = customer.insurer;
            selectedField = 'Insurer';
          } else if (columnName == 'model') {
            defaultValue = customer.model;
            selectedField = 'Model';
          } else {
            // For other columns, just get the display value
            defaultValue = _cellValues[_selectedCellKey!] ?? '';
          }
        }
      } else {
        // If we can't parse the cell key, use the cell value if available
        defaultValue = _cellValues[_selectedCellKey!] ?? '';
      }
    }

    final TextEditingController valueController =
        TextEditingController(text: defaultValue);
    int count = 0;

    // Function to count occurrences
    void countOccurrences() {
      String searchValue = valueController.text.trim().toLowerCase();
      if (searchValue.isEmpty) {
        count = 0;
        return;
      }

      count = 0;
      for (var customer in _customers) {
        String fieldValue = '';

        // Get the appropriate field value based on selection
        switch (selectedField) {
          case 'Name':
            fieldValue = customer.name;
            break;
          case 'Due Date':
            fieldValue = customer.dueDate;
            break;
          case 'Insurer':
            fieldValue = customer.insurer;
            break;
          case 'Model':
            fieldValue = customer.model;
            break;
        }

        // Count if the field contains the search value (case insensitive)
        if (fieldValue.toLowerCase().contains(searchValue)) {
          count++;
        }
      }
    }

    // Count occurrences initially with the default value
    countOccurrences();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Count If Function'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Count occurrences where:'),
                  const SizedBox(height: 15),

                  // Field selection dropdown
                  DropdownButtonFormField<String>(
                    value: selectedField,
                    decoration: const InputDecoration(
                      labelText: 'Field',
                      border: OutlineInputBorder(),
                    ),
                    items: fields.map((String field) {
                      return DropdownMenuItem<String>(
                        value: field,
                        child: Text(field),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedField = newValue;
                        });
                        countOccurrences(); // Recount when field changes
                        setState(() {}); // Update the UI with new count
                      }
                    },
                  ),

                  const SizedBox(height: 15),

                  // Value input field
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(
                      labelText: 'Contains Value',
                      hintText: 'Enter search value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      countOccurrences(); // Recount when value changes
                      setState(() {}); // Update the UI with new count
                    },
                  ),

                  const SizedBox(height: 20),

                  // Result preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Result:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            )),
                        const SizedBox(height: 5),
                        Text(
                          'Found $count occurrences',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Show Result'),
                  onPressed: () {
                    // Make sure we have the latest count
                    countOccurrences();

                    // Prepare the result message
                    String resultMessage =
                        'COUNT IF: Found $count occurrences where $selectedField contains "${valueController.text}"\n\n';

                    // Add details of matching records if count is not too large
                    if (count > 0 && count <= 10) {
                      resultMessage += 'Matching records:\n';
                      int index = 1;

                      for (var customer in _customers) {
                        String fieldValue = '';

                        // Get the appropriate field value based on selection
                        switch (selectedField) {
                          case 'Name':
                            fieldValue = customer.name;
                            break;
                          case 'Due Date':
                            fieldValue = customer.dueDate;
                            break;
                          case 'Insurer':
                            fieldValue = customer.insurer;
                            break;
                          case 'Model':
                            fieldValue = customer.model;
                            break;
                        }

                        // Add matching record details
                        if (fieldValue.toLowerCase().contains(
                            valueController.text.trim().toLowerCase())) {
                          resultMessage +=
                              '$index. ${customer.name} (${customer.vehicleNumber})\n';
                          index++;
                        }
                      }
                    } else if (count > 10) {
                      resultMessage +=
                          'Too many matches to display individually.';
                    }

                    // Close the dialog
                    Navigator.of(context).pop();

                    // Update the UI outside of the dialog
                    this.setState(() {
                      _functionResult = resultMessage;
                      _functionResultColor = Colors.teal[700]!;
                      _showFunctionResult = true;
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _setCellValue(String cellKey, String value) {
    // Save current state for undo before making changes
    _saveStateForUndo();

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
    final bool isEditing = _editingCellKey == cellKey;

    // Check if cell has a custom value (formula result)
    final displayText = _cellValues[cellKey] ?? cellText;

    return DataCell(
      MouseRegion(
        onEnter: (_) {
          if (mounted) {
            setState(() => _hoveredCellKey = cellKey);
          }
        },
        onExit: (_) {
          if (mounted) {
            setState(() => _hoveredCellKey = null);
          }
        },
        child: GestureDetector(
          onTap: () => _handleCellTap(cellKey),
          onDoubleTap: () {
            // Don't allow editing of ID column
            if (columnName != colId) {
              _startCellEditing(customerId, columnName, displayText);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            transform: (isHovered && !isSelected)
                ? (Matrix4.identity()..scale(1.03))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).primaryColorDark, width: 2)
                  : isEditing
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: isEditing
                ? TextField(
                    controller: _cellEditController,
                    focusNode: _cellEditFocusNode,
                    style: TextStyle(
                      fontFamily: style.fontFamily,
                      fontWeight:
                          style.isBold ? FontWeight.bold : FontWeight.normal,
                      decoration: style.isUnderline
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // Glowing white in dark mode
                          : Colors.black, // Black in light mode
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (value) =>
                        _saveCellEdit(customerId, columnName),
                    onTapOutside: (event) => _cancelCellEditing(),
                  )
                : Text(
                    displayText,
                    style: TextStyle(
                      fontFamily: style.fontFamily,
                      fontWeight:
                          style.isBold ? FontWeight.bold : FontWeight.normal,
                      decoration: style.isUnderline
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      backgroundColor: style.highlightColor,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // Glowing white in dark mode
                          : Colors.black, // Black in light mode
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
          .get(Uri.parse(Endpoints.getAllEndpoint))
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
              Uri.parse(Endpoints.addEndpoint),
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
        // Using the format: https://manojsir-backend.vercel.app/delete?name=Trial Name&model=TVS&contact_number=8912345645
        final deleteUrl =
            Uri.parse(Endpoints.deleteEndpoint).replace(queryParameters: {
          'name': customer.name,
          'model': customer.model,
          'contact_number': customer.contactNumber,
        });
        // Using GET request instead of DELETE as the API might be expecting GET
        final response =
            await http.get(deleteUrl).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _fetchDataFromServer(); // Refresh data
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deletion Successful',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Record for ${customer.name} has been deleted',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deletion Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Failed to delete record: ${response.statusCode} ${response.reasonPhrase}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deletion Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Error deleting record: $e',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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

  // --- Inline Cell Editing Methods ---
  void _startCellEditing(
      String customerId, String columnKey, String currentValue) {
    setState(() {
      _editingCellKey = '${customerId}_$columnKey';
      _cellEditController.text = currentValue;
    });

    // Focus the text field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cellEditFocusNode.requestFocus();
    });
  }

  void _cancelCellEditing() {
    setState(() {
      _editingCellKey = null;
      _cellEditController.clear();
    });
  }

  Future<void> _updateCustomerInServer(Customer customer) async {
    try {
      // Create the update URL with the specific field being updated
      // Format: https://manojsir-backend.vercel.app/update?id=183&contact_number=7046983554
      String updateUrl;

      if (customer.name.isNotEmpty) {
        updateUrl =
            'https://manojsir-backend.vercel.app/update?id=${customer.id}&name=${Uri.encodeComponent(customer.name)}';
      } else if (customer.dueDate.isNotEmpty) {
        updateUrl =
            'https://manojsir-backend.vercel.app/update?id=${customer.id}&due_date=${Uri.encodeComponent(customer.dueDate)}';
      } else if (customer.vehicleNumber.isNotEmpty) {
        updateUrl =
            'https://manojsir-backend.vercel.app/update?id=${customer.id}&vehicle_number=${Uri.encodeComponent(customer.vehicleNumber)}';
      } else if (customer.contactNumber.isNotEmpty) {
        updateUrl =
            'https://manojsir-backend.vercel.app/update?id=${customer.id}&contact_number=${Uri.encodeComponent(customer.contactNumber)}';
      } else if (customer.model.isNotEmpty) {
        updateUrl =
            'https://manojsir-backend.vercel.app/update?id=${customer.id}&model=${Uri.encodeComponent(customer.model)}';
      } else if (customer.insurer.isNotEmpty) {
        updateUrl =
            'https://manojsir-backend.vercel.app/update?id=${customer.id}&insurer=${Uri.encodeComponent(customer.insurer)}';
      } else {
        // No fields to update
        return;
      }

      // Send PUT request to update the specific field
      final response = await http.put(
        Uri.parse(updateUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update customer: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error updating customer: $e');
    }
  }

  Future<void> _saveCellEdit(String customerId, String columnKey) async {
    final newValue = _cellEditController.text.trim();

    // Find the customer to update
    final customerIndex = _customers.indexWhere((c) => c.id == customerId);
    if (customerIndex == -1) return;

    final customer = _customers[customerIndex];

    // Create a customer object with only the specific field being updated
    // This ensures we're only sending the relevant field in the update request
    Customer updatedCustomer = Customer(
      id: customer.id,
      name: columnKey == colName ? newValue : '',
      dueDate: columnKey == colDueDate ? newValue : '',
      vehicleNumber: columnKey == colVehicleNumber ? newValue : '',
      contactNumber: columnKey == colContactNumber ? newValue : '',
      model: columnKey == colModel ? newValue : '',
      insurer: columnKey == colInsurer ? newValue : '',
    );

    try {
      // Update in backend - only the specific field will be included in the URL
      await _updateCustomerInServer(updatedCustomer);

      // Create a fully updated customer object for the local state
      Customer fullUpdatedCustomer;
      switch (columnKey) {
        case colName:
          fullUpdatedCustomer = Customer(
            id: customer.id,
            name: newValue,
            dueDate: customer.dueDate,
            vehicleNumber: customer.vehicleNumber,
            contactNumber: customer.contactNumber,
            model: customer.model,
            insurer: customer.insurer,
          );
          break;
        case colDueDate:
          fullUpdatedCustomer = Customer(
            id: customer.id,
            name: customer.name,
            dueDate: newValue,
            vehicleNumber: customer.vehicleNumber,
            contactNumber: customer.contactNumber,
            model: customer.model,
            insurer: customer.insurer,
          );
          break;
        case colVehicleNumber:
          fullUpdatedCustomer = Customer(
            id: customer.id,
            name: customer.name,
            dueDate: customer.dueDate,
            vehicleNumber: newValue,
            contactNumber: customer.contactNumber,
            model: customer.model,
            insurer: customer.insurer,
          );
          break;
        case colContactNumber:
          fullUpdatedCustomer = Customer(
            id: customer.id,
            name: customer.name,
            dueDate: customer.dueDate,
            vehicleNumber: customer.vehicleNumber,
            contactNumber: newValue,
            model: customer.model,
            insurer: customer.insurer,
          );
          break;
        case colModel:
          fullUpdatedCustomer = Customer(
            id: customer.id,
            name: customer.name,
            dueDate: customer.dueDate,
            vehicleNumber: customer.vehicleNumber,
            contactNumber: customer.contactNumber,
            model: newValue,
            insurer: customer.insurer,
          );
          break;
        case colInsurer:
          fullUpdatedCustomer = Customer(
            id: customer.id,
            name: customer.name,
            dueDate: customer.dueDate,
            vehicleNumber: customer.vehicleNumber,
            contactNumber: customer.contactNumber,
            model: customer.model,
            insurer: newValue,
          );
          break;
        default:
          return; // Invalid column
      }

      // Update local state with the full customer object
      setState(() {
        _customers[customerIndex] = fullUpdatedCustomer;
        _editingCellKey = null;
        _cellEditController.clear();
      });

      _applySearchAndFilters();

      // Show success message with details about the updated field
      String fieldName = '';
      switch (columnKey) {
        case colName:
          fieldName = 'Name';
          break;
        case colDueDate:
          fieldName = 'Due Date';
          break;
        case colVehicleNumber:
          fieldName = 'Vehicle Number';
          break;
        case colContactNumber:
          fieldName = 'Contact Number';
          break;
        case colModel:
          fieldName = 'Model';
          break;
        case colInsurer:
          fieldName = 'Insurer';
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Successful',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$fieldName updated to: $newValue',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Show detailed error message
      String fieldName = '';
      switch (columnKey) {
        case colName:
          fieldName = 'Name';
          break;
        case colDueDate:
          fieldName = 'Due Date';
          break;
        case colVehicleNumber:
          fieldName = 'Vehicle Number';
          break;
        case colContactNumber:
          fieldName = 'Contact Number';
          break;
        case colModel:
          fieldName = 'Model';
          break;
        case colInsurer:
          fieldName = 'Insurer';
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Failed to update $fieldName: $e',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
            DateTime? customerDate = tryParseDate(customerValue);
            if (customerDate == null) {
              return false;
            }
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
      label: Container(
        width: _columnWidths[columnKey] ?? 120.0,
        child: Stack(
          children: [
            // Main column content
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the content
              children: [
                if (_sortColumnKey == columnKey)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      _sortAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // Glowing white in dark mode
                          : Theme.of(context)
                              .primaryColor, // Primary color in light mode
                    ),
                  ),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center, // Center the text
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // Glowing white in dark mode
                          : Colors.black, // Black in light mode
                    ),
                  ),
                ),
              ],
            ),

            // Resizing handle on the right edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragStart: (details) {
                  setState(() {
                    _resizingColumn = columnKey;
                    _startX = details.globalPosition.dx;
                    _startWidth = _columnWidths[columnKey] ?? 120.0;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  if (_resizingColumn == columnKey) {
                    final dx = details.globalPosition.dx - _startX;
                    setState(() {
                      // Ensure minimum width of 50 pixels
                      _columnWidths[columnKey] =
                          (_startWidth + dx).clamp(50.0, 500.0);
                    });
                  }
                },
                onHorizontalDragEnd: (details) {
                  setState(() {
                    _resizingColumn = null;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: 8,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 20,
                        color: _resizingColumn == columnKey
                            ? Colors.blue
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
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
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
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
                isItalicActive: false, // Add support later
                isStrikethroughActive: false, // Add support later
                onToggleBold: _toggleBold,
                onToggleUnderline: _toggleUnderline,
                onToggleItalic: _toggleItalic,
                onToggleStrikethrough: _toggleStrikethrough,
                onPickHighlightColor: _pickHighlightColor,
                onPickTextColor: _pickTextColor,
                onImportExcel: _importExcel,
                onExportExcel: _exportExcel,
                onChangeFontStyle: _changeFontStyle,
                onChangeFontSize: _changeFontSize,
                onInsertToday: _insertToday,
                onInsertEdate: _insertEdate,
                onInsertNetworkdays: _insertNetworkdays,
                onInsertMin: _insertMin,
                onInsertMax: _insertMax,
                onDeleteRecord:
                    _deleteRecord, // Add delete record functionality
                onInsertCountIf: _insertCountIf, // Add Count If functionality
                currentFontFamily: _currentFontFamily,
                currentFontSize:
                    12.0, // Add support for dynamic font size later
                isEnabled: _selectedCellKey != null,
                onInsertSigmoid: _insertSigmoid,
                onInsertIntegration: _insertIntegration,
                onUndo: _undo,
                onRedo: _redo,
              ),
            ),

            // Function Result Display
            if (_showFunctionResult && _functionResult != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 10.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                      color: _functionResultColor.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _functionResultColor.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Function Result:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _showFunctionResult = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // Check if the result contains a calendar visualization
                        bool hasCalendarView =
                            _functionResult!.contains('\n\n');

                        if (hasCalendarView) {
                          // Split the message and the calendar view
                          List<String> parts = _functionResult!.split('\n\n');
                          String message = parts[0];
                          String calendarView =
                              parts.length > 1 ? parts[1] : '';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main message with icon
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    message.contains('passed')
                                        ? Icons.warning_amber_rounded
                                        : message.contains('today')
                                            ? Icons.today_rounded
                                            : message.contains('left')
                                                ? Icons.event_available_rounded
                                                : Icons.info_outline_rounded,
                                    color: _functionResultColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      message,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _functionResultColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Calendar visualization
                              if (calendarView.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Working Days Calendar:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        calendarView,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          height: 1.4,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        } else {
                          // Regular message with icon (no calendar)
                          return Row(
                            children: [
                              Icon(
                                _functionResult!.contains('passed by')
                                    ? Icons.warning_amber_rounded
                                    : _functionResult!.contains('today')
                                        ? Icons.today_rounded
                                        : _functionResult!.contains('days left')
                                            ? Icons.event_available_rounded
                                            : Icons.info_outline_rounded,
                                color: _functionResultColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _functionResult!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _functionResultColor,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
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
                      Text('No customers found.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.orange[700]))
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
                        return Theme.of(context)
                            .appBarTheme
                            .backgroundColor; // Match app bar color
                      }),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        return Theme.of(context)
                            .appBarTheme
                            .backgroundColor
                            ?.withOpacity(
                                0.8); // Slightly transparent app bar color
                      }),
                      border: TableBorder.all(
                          color: Theme.of(context).primaryColor, width: 1),
                      columnSpacing:
                          0, // We'll handle spacing with column widths
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
