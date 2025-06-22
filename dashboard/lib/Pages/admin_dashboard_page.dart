import 'dart:convert';
import 'dart:io'; // For SocketException
import 'dart:async'; // For Timer
import 'dart:math'; // For sin function in animations
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date parsing and comparison
import '../endpoints.dart';
import 'package:animated_text_kit/animated_text_kit.dart'; // For typewriter animation
import 'package:fl_chart/fl_chart.dart'; // For pie and bar charts
import '../theme.dart'; // For accessing theme colors
import '../parsing/date_parsing.dart'; // For date parsing functions
import '../Utils/lineGraph.dart' as line_graph; // For line chart with alias
import 'package:shared_preferences/shared_preferences.dart'; // For persistent storage
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:path_provider/path_provider.dart'; // For app directory

// Define a model for the raw customer data expected from /getAll
class CustomerData {
  final String customerName;
  final String dueDate; // Expecting "YYYY-MM-DD" or similar parseable format
  final String insuranceProvider;
  final String carModel;

  CustomerData({
    required this.customerName,
    required this.dueDate,
    required this.insuranceProvider,
    required this.carModel,
  });

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    // Get the raw due date string
    String rawDueDate = json['due_date'] ?? json['dueDate'] ?? 'N/A';

    // Use our date parsing function to convert ISO format to YYYY-MM-DD
    String formattedDueDate =
        rawDueDate != 'N/A' ? parseIsoDateToYYYYMMDD(rawDueDate) : 'N/A';

    return CustomerData(
      customerName: json['name'] ??
          json['customer_name'] ??
          json['customerName'] ??
          'N/A', // Prioritize 'name'
      dueDate: formattedDueDate,
      insuranceProvider: json['insurer'] ??
          json['insurance_provider'] ??
          json['insuranceProvider'] ??
          'N/A',
      carModel: json['model'] ?? json['carModel'] ?? 'N/A',
    );
  }
}

// Define data models for the processed dashboard information
class UpcomingDueInfo {
  final String customerName;
  final String dueDate; // Can be the original string or formatted

  UpcomingDueInfo({required this.customerName, required this.dueDate});
}

class InsurerData {
  final String name;
  final int count;
  final double percentage;

  InsurerData({
    required this.name,
    required this.count,
    required this.percentage,
  });
}

class DueDateData {
  final DateTime date;
  final int count;

  DueDateData({
    required this.date,
    required this.count,
  });
}

class AdminDashboardProcessedData {
  final List<UpcomingDueInfo> upcomingDues;
  final List<String> topInsurers; // List of names
  final List<String> topCarModels; // List of names
  final List<InsurerData> insurerDistribution; // For pie chart
  final List<DueDateData> dueDateDistribution; // For bar chart

  AdminDashboardProcessedData({
    required this.upcomingDues,
    required this.topInsurers,
    required this.topCarModels,
    required this.insurerDistribution,
    required this.dueDateDistribution,
  });
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  AdminDashboardProcessedData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNetworkError = false;
  final String _apiUrlBase = Endpoints.baseUrl;

  // For time-based greeting
  String _timeOfDay = '';
  Timer? _timer;

  // For logo animation
  late AnimationController _animationController;
  late Animation<double> _animation;

  // For date range selection
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  List<CustomerData> _allCustomers = [];

  // For tracking earliest and latest due dates
  DateTime? _minDueDate;
  DateTime? _maxDueDate;
  CustomerData? _minDueDateCustomer;
  CustomerData? _maxDueDateCustomer;

  // For user profile settings
  String _userName = 'Sagar';
  String _userEmail = '';
  String _userPhone = '';
  String _userRole = 'User'; // Default role
  String _userImagePath = 'assets/app_logo.jpg'; // Default image
  bool _isHoveringHeroSection = false;

  // Available roles for dropdown
  final List<String> _availableRoles = ['User', 'Admin'];

  // For chart expand functionality
  bool _isChartExpanded = false;

  // Validation functions
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty phone number
    }

    // Remove any non-digit characters for validation
    String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty email
    }

    // Check if email contains '@'
    if (!value.contains('@')) {
      return 'Email must contain @';
    }

    // Split email into parts
    List<String> parts = value.split('@');
    if (parts.length != 2) {
      return 'Invalid email format';
    }

    String domain = parts[1];

    // Check if domain ends with valid extensions
    List<String> validExtensions = [
      '.com',
      '.edu.in',
      '.co.in',
      '.org',
      '.net',
      '.gov.in',
      '.ac.in',
      '.in',
      '.edu',
      '.gov',
      '.mil',
      '.biz',
      '.info'
    ];

    bool hasValidExtension = validExtensions.any((ext) => domain.endsWith(ext));

    if (!hasValidExtension) {
      return 'Email must end with valid domain (.com, .edu.in, .co.in, etc.)';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load saved user data
    _fetchAndProcessDashboardData();
    _updateTimeOfDay();

    // Set up timer to update greeting every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTimeOfDay();
    });

    // Set up animation controller with longer, smoother animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Start the animation with a slight delay for a more polished feel
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _updateTimeOfDay() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _timeOfDay = 'Good Morning,';
      } else if (hour < 17) {
        _timeOfDay = 'Good Afternoon,';
      } else {
        _timeOfDay = 'Good Evening,';
      }
    });
  }

  Future<void> _fetchAndProcessDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isNetworkError = false;
    });

    try {
      // Step 1: Fetch all data
      final response = await http
          .get(Uri.parse(
              Endpoints.getAllEndpoint)) // Using endpoint from endpoints.dart
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        _allCustomers = jsonData
            .map((item) => CustomerData.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        setState(() {
          _errorMessage =
              'Failed to load data: ${response.statusCode} ${response.reasonPhrase}';
          if (response.statusCode >= 500) {
            // Basic check for server-side issues
            _errorMessage =
                'Server currently not working (Error ${response.statusCode}). Please try again later.';
            _isNetworkError =
                true; // Treat server errors as a type of network/connectivity issue for UI
          }
          _isLoading = false;
        });
        return;
      }
    } on SocketException {
      setState(() {
        _errorMessage =
            'Network error. Server currently not working or no internet connection.';
        _isNetworkError = true;
        _isLoading = false;
      });
      return;
    } on http.ClientException catch (e) {
      setState(() {
        _errorMessage =
            'Could not connect to the server. Server currently not working or check your network. ($e)';
        _isNetworkError = true;
        _isLoading = false;
      });
      return;
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
      return;
    }

    // Process the data with the current date range
    _processData();
  }

  void _processData() {
    if (_allCustomers.isEmpty) {
      setState(() {
        _dashboardData = AdminDashboardProcessedData(
          upcomingDues: [],
          topInsurers: [],
          topCarModels: [],
          insurerDistribution: [],
          dueDateDistribution: [],
        );
        _isLoading = false;
      });
      return;
    }

    // Reset min and max date tracking variables
    _minDueDate = null;
    _maxDueDate = null;
    _minDueDateCustomer = null;
    _maxDueDateCustomer = null;

    // Calculate min and max due dates from all customers
    for (var customer in _allCustomers) {
      DateTime? dueDate = tryParseDate(customer.dueDate);
      if (dueDate != null) {
        // Update minimum due date
        if (_minDueDate == null || dueDate.isBefore(_minDueDate!)) {
          _minDueDate = dueDate;
          _minDueDateCustomer = customer;
        }

        // Update maximum due date
        if (_maxDueDate == null || dueDate.isAfter(_maxDueDate!)) {
          _maxDueDate = dueDate;
          _maxDueDateCustomer = customer;
        }
      }
    }

    try {
      // Process Upcoming Dues (based on selected date range)
      final List<UpcomingDueInfo> upcomingDuesList = [];
      final DateFormat displayFormat = DateFormat('dd MMM, yyyy');

      for (var customer in _allCustomers) {
        try {
          // Use our tryParseDate function to handle various date formats
          DateTime? dueDate = tryParseDate(customer.dueDate);

          if (dueDate == null) {
            // Skip customers with unparseable dates
            continue;
          }

          // Check if due date is within the selected range
          if (dueDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              dueDate.isBefore(_endDate.add(const Duration(days: 1)))) {
            upcomingDuesList.add(UpcomingDueInfo(
                customerName: customer.customerName,
                dueDate: displayFormat.format(dueDate)));
          }
        } catch (e) {
          // Handle cases where a specific due_date might be unparseable
          debugPrint(
              'Could not parse due date for ${customer.customerName}: ${customer.dueDate} - $e');
        }
      }

      // Sort by date
      upcomingDuesList.sort((a, b) {
        try {
          return displayFormat
              .parse(a.dueDate)
              .compareTo(displayFormat.parse(b.dueDate));
        } catch (e) {
          return 0; // In case of parsing error, maintain original order
        }
      });

      // Process Insurance Providers for both top list and pie chart
      final Map<String, int> insurerCounts = {};
      for (var customer in _allCustomers) {
        if (customer.insuranceProvider.isNotEmpty &&
            customer.insuranceProvider != 'N/A') {
          insurerCounts[customer.insuranceProvider] =
              (insurerCounts[customer.insuranceProvider] ?? 0) + 1;
        }
      }
      final sortedInsurers = insurerCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final List<String> topInsurersList =
          sortedInsurers.take(3).map((e) => e.key).toList();

      // Calculate total for percentage
      final int totalCustomers =
          insurerCounts.values.fold(0, (sum, count) => sum + count);

      // Create insurer distribution data for pie chart (limit to top 4 + "Others")
      final List<InsurerData> insurerDistribution = [];
      int othersCount = 0;

      for (int i = 0; i < sortedInsurers.length; i++) {
        if (i < 4) {
          // Top 4 insurers
          final entry = sortedInsurers[i];
          final percentage = (entry.value / totalCustomers) * 100;
          insurerDistribution.add(InsurerData(
            name: entry.key,
            count: entry.value,
            percentage: percentage,
          ));
        } else {
          // Group the rest as "Others"
          othersCount += sortedInsurers[i].value;
        }
      }

      // Add "Others" category if there are more than 4 insurers
      if (othersCount > 0) {
        final percentage = (othersCount / totalCustomers) * 100;
        insurerDistribution.add(InsurerData(
          name: 'Others',
          count: othersCount,
          percentage: percentage,
        ));
      }

      // Process Top 3 Car Models
      final Map<String, int> carModelCounts = {};
      for (var customer in _allCustomers) {
        if (customer.carModel.isNotEmpty && customer.carModel != 'N/A') {
          carModelCounts[customer.carModel] =
              (carModelCounts[customer.carModel] ?? 0) + 1;
        }
      }
      final sortedCarModels = carModelCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final List<String> topCarModelsList =
          sortedCarModels.take(3).map((e) => e.key).toList();

      // Process due dates for bar chart based on selected date range
      final Map<String, int> dueDateCounts = {};
      final DateFormat keyFormat = DateFormat('yyyy-MM-dd');

      // Initialize all dates in the selected range
      final int daysDifference = _endDate.difference(_startDate).inDays;
      final int daysToShow = daysDifference + 1;

      debugPrint(
          'Processing due dates for chart. Date range: $_startDate to $_endDate');
      debugPrint('Days difference: $daysDifference, Days to show: $daysToShow');

      for (int i = 0; i < daysToShow; i++) {
        final date = _startDate.add(Duration(days: i));
        final dateKey = keyFormat.format(date);
        dueDateCounts[dateKey] = 0;
        debugPrint('Initialized date: $dateKey with count 0');
      }

      // Count customers by due date
      int totalCustomersWithValidDates = 0;
      int customersInSelectedRange = 0;

      debugPrint(
          'Counting customers by due date from ${_allCustomers.length} total customers');

      for (var customer in _allCustomers) {
        try {
          // Use our tryParseDate function to handle various date formats
          DateTime? dueDate = tryParseDate(customer.dueDate);

          if (dueDate == null) {
            // Skip customers with unparseable dates
            debugPrint(
                'Customer ${customer.customerName} has unparseable due date: ${customer.dueDate}');
            continue;
          }

          totalCustomersWithValidDates++;

          // Only count if within our selected range
          if (!dueDate.isBefore(_startDate) && !dueDate.isAfter(_endDate)) {
            final String dateKey = formatDateToYYYYMMDD(dueDate);
            dueDateCounts[dateKey] = (dueDateCounts[dateKey] ?? 0) + 1;
            customersInSelectedRange++;
            debugPrint(
                'Customer ${customer.customerName} due date: $dateKey, count now: ${dueDateCounts[dateKey]}');
          } else {
            debugPrint(
                'Customer ${customer.customerName} due date: ${dueDate.toString()} - outside selected range');
          }
        } catch (e) {
          // Skip unparseable dates
          debugPrint(
              'Error parsing date for bar chart: ${customer.dueDate} - $e');
        }
      }

      debugPrint(
          'Total customers with valid dates: $totalCustomersWithValidDates');
      debugPrint('Customers in selected range: $customersInSelectedRange');

      // Convert to list of DueDateData objects
      debugPrint(
          'Converting due date counts to DueDateData objects. Map size: ${dueDateCounts.length}');

      final List<DueDateData> dueDateDistribution =
          dueDateCounts.entries.map((entry) {
        final date = keyFormat.parse(entry.key);
        final count = entry.value;
        debugPrint('Creating DueDateData: date=$date, count=$count');
        return DueDateData(
          date: date,
          count: count,
        );
      }).toList();

      // Sort by date
      dueDateDistribution.sort((a, b) => a.date.compareTo(b.date));

      debugPrint(
          'Final dueDateDistribution size: ${dueDateDistribution.length}');
      if (dueDateDistribution.isNotEmpty) {
        debugPrint(
            'First item: ${dueDateDistribution.first.date} - ${dueDateDistribution.first.count}');
        debugPrint(
            'Last item: ${dueDateDistribution.last.date} - ${dueDateDistribution.last.count}');
      } else {
        debugPrint('dueDateDistribution is empty!');
      }

      setState(() {
        _dashboardData = AdminDashboardProcessedData(
          upcomingDues: upcomingDuesList,
          topInsurers: topInsurersList,
          topCarModels: topCarModelsList,
          insurerDistribution: insurerDistribution,
          dueDateDistribution: dueDateDistribution,
        );
        _isLoading = false;

        // Debug print to verify data is set correctly
        debugPrint(
            'Dashboard data set. dueDateDistribution size: ${_dashboardData!.dueDateDistribution.length}');
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing data: $e';
        _isLoading = false;
      });
    }

    // Step 2: Process the fetched data
    if (_allCustomers.isNotEmpty) {
      try {
        // Process Upcoming Dues (due in next 30 days)
        final List<UpcomingDueInfo> upcomingDuesList = [];
        final DateTime now = DateTime.now();
        final DateTime thirtyDaysFromNow = now.add(const Duration(days: 30));

        for (var customer in _allCustomers) {
          try {
            // Attempt to parse the date. Adjust format if needed.
            // Handle different date formats
            DateTime dueDate;

            // Try to parse the date based on its format
            if (customer.dueDate.contains('-') &&
                customer.dueDate.length >= 10) {
              // ISO format (YYYY-MM-DD)
              dueDate = DateFormat('yyyy-MM-dd')
                  .parse(customer.dueDate.substring(0, 10));
            } else {
              // Legacy format (dd.MM.yyyy)
              dueDate = DateFormat('dd.MM.yyyy').parse(customer.dueDate);
            }

            // Check if due date is in the future and within the next 30 days
            if (dueDate.isAfter(now) && dueDate.isBefore(thirtyDaysFromNow)) {
              upcomingDuesList.add(UpcomingDueInfo(
                  customerName: customer.customerName, // Name is added
                  dueDate: DateFormat('dd MMM, yyyy')
                      .format(dueDate) // Formatted due date is added
                  ));
            }
          } catch (e) {
            // Handle cases where a specific due_date might be unparseable
            debugPrint(
                'Could not parse due date for ${customer.customerName}: ${customer.dueDate} - $e');
            // Optionally add to a list of problematic entries or show a generic entry
            // For now, we skip it if unparseable
          }
        }
        upcomingDuesList.sort((a, b) => DateFormat('dd MMM, yyyy')
            .parse(a.dueDate)
            .compareTo(DateFormat('dd MMM, yyyy').parse(b.dueDate)));

        // Process Insurance Providers for both top list and pie chart
        final Map<String, int> insurerCounts = {};
        for (var customer in _allCustomers) {
          if (customer.insuranceProvider.isNotEmpty &&
              customer.insuranceProvider != 'N/A') {
            insurerCounts[customer.insuranceProvider] =
                (insurerCounts[customer.insuranceProvider] ?? 0) + 1;
          }
        }
        final sortedInsurers = insurerCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final List<String> topInsurersList =
            sortedInsurers.take(3).map((e) => e.key).toList();

        // Calculate total for percentage
        final int totalCustomers =
            insurerCounts.values.fold(0, (sum, count) => sum + count);

        // Create insurer distribution data for pie chart (limit to top 4 + "Others")
        final List<InsurerData> insurerDistribution = [];
        int othersCount = 0;

        for (int i = 0; i < sortedInsurers.length; i++) {
          if (i < 4) {
            // Top 4 insurers
            final entry = sortedInsurers[i];
            final percentage = (entry.value / totalCustomers) * 100;
            insurerDistribution.add(InsurerData(
              name: entry.key,
              count: entry.value,
              percentage: percentage,
            ));
          } else {
            // Group the rest as "Others"
            othersCount += sortedInsurers[i].value;
          }
        }

        // Add "Others" category if there are more than 4 insurers
        if (othersCount > 0) {
          final percentage = (othersCount / totalCustomers) * 100;
          insurerDistribution.add(InsurerData(
            name: 'Others',
            count: othersCount,
            percentage: percentage,
          ));
        }

        // Process Top 3 Car Models
        final Map<String, int> carModelCounts = {};
        for (var customer in _allCustomers) {
          if (customer.carModel.isNotEmpty && customer.carModel != 'N/A') {
            carModelCounts[customer.carModel] =
                (carModelCounts[customer.carModel] ?? 0) + 1;
          }
        }
        final sortedCarModels = carModelCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final List<String> topCarModelsList =
            sortedCarModels.take(3).map((e) => e.key).toList();

        // Process due dates for bar chart (all dates from the data)
        final Map<String, int> dueDateCounts = {};
        final DateFormat keyFormat = DateFormat('yyyy-MM-dd');
        final DateFormat ddMMyyyyFormat = DateFormat('dd.MM.yyyy');
        final DateFormat yyyyMMddFormat = DateFormat('yyyy-MM-dd');

        // First, find the earliest and latest dates in the data
        DateTime? earliestDate;
        DateTime? latestDate;

        for (var customer in _allCustomers) {
          try {
            DateTime dueDate;

            // Try to parse the date based on its format
            if (customer.dueDate.contains('-') &&
                customer.dueDate.length >= 10) {
              // ISO format (YYYY-MM-DD)
              dueDate = yyyyMMddFormat.parse(customer.dueDate.substring(0, 10));
            } else {
              // Legacy format (dd.MM.yyyy)
              dueDate = ddMMyyyyFormat.parse(customer.dueDate);
            }
            if (earliestDate == null || dueDate.isBefore(earliestDate)) {
              earliestDate = dueDate;
            }
            if (latestDate == null || dueDate.isAfter(latestDate)) {
              latestDate = dueDate;
            }
          } catch (e) {
            // Skip unparseable dates
          }
        }

        // If we have valid date range, initialize all dates in the range
        if (earliestDate != null && latestDate != null) {
          // Limit to a reasonable range (e.g., 60 days) if the range is too large
          final int daysDifference = latestDate.difference(earliestDate).inDays;
          final int daysToShow = daysDifference > 60 ? 60 : daysDifference + 1;

          for (int i = 0; i < daysToShow; i++) {
            final date = earliestDate.add(Duration(days: i));
            dueDateCounts[keyFormat.format(date)] = 0;
          }

          // Count customers by due date
          for (var customer in _allCustomers) {
            try {
              DateTime dueDate;

              // Try to parse the date based on its format
              if (customer.dueDate.contains('-') &&
                  customer.dueDate.length >= 10) {
                // ISO format (YYYY-MM-DD)
                dueDate =
                    yyyyMMddFormat.parse(customer.dueDate.substring(0, 10));
              } else {
                // Legacy format (dd.MM.yyyy)
                dueDate = ddMMyyyyFormat.parse(customer.dueDate);
              }

              // Only count if within our display range
              if (!dueDate.isBefore(earliestDate) &&
                  !dueDate.isAfter(
                      earliestDate.add(Duration(days: daysToShow - 1)))) {
                final String dateKey = keyFormat.format(dueDate);
                dueDateCounts[dateKey] = (dueDateCounts[dateKey] ?? 0) + 1;
              }
            } catch (e) {
              // Skip unparseable dates
            }
          }
        }

        // Convert to list of DueDateData objects
        final List<DueDateData> dueDateDistribution =
            dueDateCounts.entries.map((entry) {
          return DueDateData(
            date: keyFormat.parse(entry.key),
            count: entry.value,
          );
        }).toList();

        // Sort by date
        dueDateDistribution.sort((a, b) => a.date.compareTo(b.date));

        setState(() {
          _dashboardData = AdminDashboardProcessedData(
            upcomingDues: upcomingDuesList,
            topInsurers: topInsurersList,
            topCarModels: topCarModelsList,
            insurerDistribution: insurerDistribution,
            dueDateDistribution: dueDateDistribution,
          );
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Error processing dashboard data: $e';
          _isLoading = false;
        });
      }
    } else {
      // Handle case where /getAll returns empty list but no error
      setState(() {
        _dashboardData = AdminDashboardProcessedData(
          upcomingDues: [],
          topInsurers: [],
          topCarModels: [],
          insurerDistribution: [],
          dueDateDistribution: [],
        );
        _isLoading = false;
        // Optionally set a message like "No customer data found to process."
      });
    }
  }

  // User data persistence methods
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Sagar';
        _userEmail = prefs.getString('user_email') ?? '';
        _userPhone = prefs.getString('user_phone') ?? '';

        // Validate loaded role - ensure it's in available roles list
        String loadedRole = prefs.getString('user_role') ?? 'User';
        _userRole = _availableRoles.contains(loadedRole) ? loadedRole : 'User';

        _userImagePath =
            prefs.getString('user_image_path') ?? 'assets/app_logo.jpg';
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_phone', _userPhone);
      await prefs.setString('user_role', _userRole);
      await prefs.setString('user_image_path', _userImagePath);
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  // Image picker functionality
  Future<void> _pickImage() async {
    if (!mounted) return;

    // Store the scaffold messenger reference before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final ImagePicker picker = ImagePicker();

      // Directly pick from gallery to avoid context issues
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Get the app's documents directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName =
            'profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String newPath = '${appDir.path}/$fileName';

        // Copy the selected image to the app's directory
        await File(image.path).copy(newPath);

        // Delete the old image if it's not the default
        if (_userImagePath != 'assets/app_logo.jpg' &&
            File(_userImagePath).existsSync()) {
          try {
            await File(_userImagePath).delete();
          } catch (e) {
            debugPrint('Error deleting old image: $e');
          }
        }

        // Update the image path only if still mounted
        if (mounted) {
          setState(() {
            _userImagePath = newPath;
          });

          // Save the new path
          await _saveUserData();

          // Show success message using stored reference
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      // Show error message using stored reference
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error selecting image: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper method to build image widget
  Widget _buildImageWidget(String imagePath, double width, double height) {
    if (imagePath.startsWith('assets/')) {
      // Asset image
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/app_logo.jpg',
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      // File image
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/app_logo.jpg',
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
        );
      } else {
        // File doesn't exist, fall back to default
        return Image.asset(
          'assets/app_logo.jpg',
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    }
  }

  // Moved _buildErrorWidget inside the State class
  // New Hero Section with text animation and settings
  Widget _buildHeroSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringHeroSection = true),
      onExit: (_) => setState(() => _isHoveringHeroSection = false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    theme.colorScheme.primary.withOpacity(0.8),
                    theme.colorScheme.primary.withOpacity(0.4),
                  ]
                : [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.primary.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App logo in circular container on the left
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: _buildImageWidget(_userImagePath, 120, 120),
                  ),
                ),

                const SizedBox(width: 30),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated welcome text
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? const Color(0xFFF5F5DC)
                              : primaryColor, // Cream white in dark mode, primary color in light mode
                          letterSpacing: -0.5,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$_timeOfDay $_userName!',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? const Color(0xFFF5F5DC)
                                    : primaryColor, // Cream white in dark mode, primary color in light mode
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Animated subtitle
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: textColor.withOpacity(0.7),
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'Welcome to your Dashboard',
                              speed: const Duration(milliseconds: 80),
                            ),
                          ],
                          isRepeatingAnimation: false,
                          totalRepeatCount: 1,
                          displayFullTextOnTap: true,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Current date and time
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),

                // User details column (right side)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_userEmail.isNotEmpty)
                      Text(
                        _userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    if (_userPhone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _userPhone,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.6),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    if (_userRole.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _userRole,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.6),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),

                    // Settings button positioned below user info
                    if (_isHoveringHeroSection)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AnimatedOpacity(
                          opacity: _isHoveringHeroSection ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showSettingsDialog(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.shadowColor.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.settings,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Settings dialog
  void _showSettingsDialog(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

    // Form key for validation
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    // Controllers for text fields
    final TextEditingController nameController =
        TextEditingController(text: _userName);
    final TextEditingController emailController =
        TextEditingController(text: _userEmail);
    final TextEditingController phoneController =
        TextEditingController(text: _userPhone);

    // Selected role for dropdown - ensure it's a valid option
    String selectedRole =
        _availableRoles.contains(_userRole) ? _userRole : 'User';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Profile Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Profile Image Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: _buildImageWidget(_userImagePath, 100, 100),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () async {
                            await _pickImage();
                            // The dialog will automatically show the updated image
                            // since setState is called in _pickImage
                          },
                          icon: Icon(Icons.camera_alt, color: primaryColor),
                          label: Text(
                            'Choose from Gallery',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Fields
                  _buildTextField(
                    controller: nameController,
                    label: 'Name',
                    icon: Icons.person,
                    theme: theme,
                    primaryColor: primaryColor,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: emailController,
                    label: 'Email',
                    icon: Icons.email,
                    theme: theme,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    theme: theme,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    keyboardType: TextInputType.phone,
                    validator: _validatePhoneNumber,
                  ),

                  const SizedBox(height: 16),

                  // Role Dropdown
                  StatefulBuilder(
                    builder: (context, setDropdownState) {
                      return DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          labelStyle:
                              TextStyle(color: textColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.work, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: textColor.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: textColor.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        dropdownColor: theme.colorScheme.surface,
                        style: TextStyle(color: textColor),
                        items: _availableRoles.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role,
                              style: TextStyle(color: textColor),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setDropdownState(() {
                              selectedRole = newValue;
                            });
                          }
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          // Validate the form
                          if (formKey.currentState!.validate()) {
                            // Save the settings
                            setState(() {
                              _userName = nameController.text.trim().isEmpty
                                  ? 'Sagar'
                                  : nameController.text.trim();
                              _userEmail = emailController.text.trim();
                              _userPhone = phoneController.text.trim();
                              _userRole = selectedRole;
                            });

                            // Save to persistent storage
                            await _saveUserData();

                            Navigator.of(context).pop();

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Profile updated successfully!'),
                                backgroundColor: primaryColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    required Color primaryColor,
    required Color textColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
      ),
    );
  }

  // Build summary cards for key metrics
  Widget _buildSummaryCards(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color secondaryColor = theme.colorScheme.secondary;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Calculate total clients
    final int totalClients = _dashboardData != null
        ? (_dashboardData!.insurerDistribution
            .fold(0, (sum, item) => sum + item.count))
        : 0;

    // Calculate renewals due today using yyyy-MM-dd format
    final int renewalsDueToday = _allCustomers.isEmpty
        ? 0
        : _allCustomers.where((customer) {
            // Parse the customer's due date
            DateTime? dueDate = tryParseDate(customer.dueDate);
            if (dueDate == null) return false;

            // Format both dates to yyyy-MM-dd for comparison
            String dueDateFormatted = formatDateToYYYYMMDD(dueDate);
            String todayFormatted = formatDateToYYYYMMDD(DateTime.now());

            // Compare the formatted dates
            return dueDateFormatted == todayFormatted;
          }).length;

    // Get most chosen insurer
    final String mostChosenInsurer =
        _dashboardData != null && _dashboardData!.insurerDistribution.isNotEmpty
            ? _dashboardData!.insurerDistribution
                .reduce((a, b) => a.count > b.count ? a : b)
                .name
            : 'N/A';

    // Get earliest and latest due dates from the entire dataset
    String dueDateRange = 'N/A';
    if (_minDueDate != null && _maxDueDate != null) {
      // Format dates in YYYY-MM-DD format as required
      final earliest = formatDateToYYYYMMDD(_minDueDate);
      final latest = formatDateToYYYYMMDD(_maxDueDate);
      dueDateRange = '$earliest - $latest';
    }

    // Define card data
    final List<Map<String, dynamic>> cardData = [
      {
        'title': 'Total Clients',
        'value': '$totalClients',
        'icon': Icons.people_alt_rounded,
        'color': theme.colorScheme.primary,
      },
      {
        'title': 'Renewals Due Today',
        'value': '$renewalsDueToday',
        'icon': Icons.event_available_rounded,
        'color': theme.colorScheme.secondary,
      },
      {
        'title': 'Most Chosen Insurer',
        'value': mostChosenInsurer,
        'icon': Icons.star_rounded,
        'color': Colors.amber,
      },
      {
        'title': 'Due Date Range',
        'value': dueDateRange,
        'icon': Icons.date_range_rounded,
        'color': Colors.teal,
        'tooltip': _minDueDateCustomer != null && _maxDueDateCustomer != null
            ? 'From ${_minDueDateCustomer!.customerName} to ${_maxDueDateCustomer!.customerName}'
            : null,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout - wrap cards if width is too small
          final bool isNarrow = constraints.maxWidth < 800;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: cardData.map((card) {
              // Create the card content widget
              Widget cardContent = Container(
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: card['color'].withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          card['title'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        Icon(
                          card['icon'],
                          color: card['color'],
                          size: 24,
                        ),
                      ],
                    ),
                    Text(
                      card['value'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );

              // Wrap with tooltip if available
              if (card['tooltip'] != null) {
                cardContent = Tooltip(
                  message: card['tooltip'],
                  showDuration: const Duration(seconds: 3),
                  child: cardContent,
                );
              }

              return SizedBox(
                width: isNarrow
                    ? (constraints.maxWidth / 2) - 24
                    : (constraints.maxWidth / 4) - 16,
                child: cardContent,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(
      String message, bool isNetworkError, Color iconColor) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              color: isNetworkError
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.error,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              isNetworkError ? 'Connection Issue' : 'An Error Occurred',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (isNetworkError ||
                message.contains("Server currently not working"))
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: _fetchAndProcessDashboardData,
              ),
          ],
        ),
      ),
    );
  }

  // Badge widget for pie chart
  Widget _Badge({
    required String text,
    required double size,
    required Color borderColor,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: isDarkMode ? theme.colorScheme.surface : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Center(
        child: FittedBox(
          child: Text(
            text.length > 3 ? text.substring(0, 3) : text,
            style: TextStyle(
              color: borderColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Build the insurer distribution pie chart
  Widget _buildInsurerPieChart() {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color secondaryColor = theme.colorScheme.secondary;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    final List<InsurerData> data = _dashboardData!.insurerDistribution;

    // Define chart colors that work in both light and dark mode
    final List<Color> chartColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      isDarkMode ? Colors.tealAccent[400]! : Colors.orange[400]!,
      isDarkMode ? Colors.purpleAccent[100]! : Colors.purple[400]!,
      isDarkMode ? Colors.grey[300]! : Colors.grey[600]!,
    ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 350,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insurer Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(children: [
                // Pie Chart
                Expanded(
                  flex: 3,
                  child: data.isEmpty
                      ? Center(
                          child: Text('No insurer data available',
                              style: TextStyle(color: Colors.grey[500])))
                      : AspectRatio(
                          aspectRatio: 1.0,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: List.generate(data.length, (index) {
                                return PieChartSectionData(
                                  color:
                                      chartColors[index % chartColors.length],
                                  value: data[index].percentage,
                                  title:
                                      '${data[index].percentage.toStringAsFixed(1)}%',
                                  radius: 80, // Reduced radius to fit better
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  badgeWidget: _Badge(
                                    text: data[index].name,
                                    size: 40,
                                    borderColor:
                                        chartColors[index % chartColors.length],
                                  ),
                                  badgePositionPercentageOffset: 1.1,
                                );
                              }),
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                  // Handle touch events if needed
                                },
                              ),
                            ),
                          ),
                        ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // Old summary cards method - removed
  Widget _buildOldSummaryCards() {
    // Calculate total clients
    final int totalClients = _dashboardData!.upcomingDues.length;

    // Calculate renewals due today
    final DateTime today = DateTime.now();
    final DateFormat dateFormat = DateFormat('dd MMM, yyyy');
    int renewalsDueToday = 0;

    for (var due in _dashboardData!.upcomingDues) {
      try {
        final DateTime dueDate = dateFormat.parse(due.dueDate);
        if (dueDate.year == today.year &&
            dueDate.month == today.month &&
            dueDate.day == today.day) {
          renewalsDueToday++;
        }
      } catch (e) {
        // Skip unparseable dates
      }
    }

    // Find most chosen insurer
    String mostChosenInsurer = _dashboardData!.topInsurers.isNotEmpty
        ? _dashboardData!.topInsurers.first
        : 'N/A';

    // Use the MIN and MAX dates calculated from all customers
    String earliestAndLatestDueDate = 'N/A';
    if (_minDueDate != null && _maxDueDate != null) {
      final String earliest = DateFormat('MMM d, yyyy').format(_minDueDate!);
      final String latest = DateFormat('MMM d, yyyy').format(_maxDueDate!);

      // Add customer names if available
      String minCustomerInfo = _minDueDateCustomer != null
          ? ' (${_minDueDateCustomer!.customerName})'
          : '';
      String maxCustomerInfo = _maxDueDateCustomer != null
          ? ' (${_maxDueDateCustomer!.customerName})'
          : '';

      earliestAndLatestDueDate =
          'MIN: $earliest$minCustomerInfo\nMAX: $latest$maxCustomerInfo';
    } else if (_dashboardData!.upcomingDues.isNotEmpty) {
      // Fallback to the old method if MIN/MAX dates are not available
      try {
        final List<DateTime> allDates = _dashboardData!.upcomingDues
            .map((due) => dateFormat.parse(due.dueDate))
            .toList();

        allDates.sort();

        if (allDates.isNotEmpty) {
          final String earliest =
              DateFormat('MMM d, yyyy').format(allDates.first);
          final String latest = DateFormat('MMM d, yyyy').format(allDates.last);
          earliestAndLatestDueDate = '$earliest - $latest';
        }
      } catch (e) {
        // Handle parsing errors
      }
    }

    // Define card style
    final cardBorderRadius = BorderRadius.circular(12);
    final cardElevation = 2.0;
    final cardPadding = const EdgeInsets.all(16.0);

    // Define text styles
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[300]
          : Colors.grey[600],
    );

    final valueStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87,
    );

    // Create the cards
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive layout based on available width
              if (constraints.maxWidth > 800) {
                // Wide layout - cards in a row
                return Row(
                  children: [
                    // Total Clients
                    Expanded(
                      child: Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(
                            borderRadius: cardBorderRadius),
                        child: Padding(
                          padding: cardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Clients', style: titleStyle),
                              const SizedBox(height: 8),
                              Text('$totalClients', style: valueStyle),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Renewals Due Today
                    Expanded(
                      child: Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(
                            borderRadius: cardBorderRadius),
                        child: Padding(
                          padding: cardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Renewals Due Today', style: titleStyle),
                              const SizedBox(height: 8),
                              Text('$renewalsDueToday', style: valueStyle),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Most Chosen Insurer
                    Expanded(
                      child: Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(
                            borderRadius: cardBorderRadius),
                        child: Padding(
                          padding: cardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Most Chosen Insurer', style: titleStyle),
                              const SizedBox(height: 8),
                              Text(
                                mostChosenInsurer,
                                style: valueStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Earliest and Latest Due Date
                    Expanded(
                      child: Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(
                            borderRadius: cardBorderRadius),
                        child: Padding(
                          padding: cardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due Date Range', style: titleStyle),
                              const SizedBox(height: 8),
                              // Check if we're using the new MIN/MAX format
                              earliestAndLatestDueDate.contains('MIN:')
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // MIN date with red color
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'MIN: ',
                                                style: TextStyle(
                                                  color: Colors.red[700],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: earliestAndLatestDueDate
                                                    .split('\n')[0]
                                                    .substring(5),
                                                style: valueStyle.copyWith(
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // MAX date with green color
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'MAX: ',
                                                style: TextStyle(
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: earliestAndLatestDueDate
                                                    .split('\n')[1]
                                                    .substring(5),
                                                style: valueStyle.copyWith(
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      earliestAndLatestDueDate,
                                      style: valueStyle.copyWith(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Narrow layout - cards stacked vertically
                return Column(
                  children: [
                    // Total Clients
                    Card(
                      elevation: cardElevation,
                      shape: RoundedRectangleBorder(
                          borderRadius: cardBorderRadius),
                      child: Padding(
                        padding: cardPadding,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Clients', style: titleStyle),
                                  const SizedBox(height: 8),
                                  Text('$totalClients', style: valueStyle),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Renewals Due Today
                    Card(
                      elevation: cardElevation,
                      shape: RoundedRectangleBorder(
                          borderRadius: cardBorderRadius),
                      child: Padding(
                        padding: cardPadding,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Renewals Due Today', style: titleStyle),
                                  const SizedBox(height: 8),
                                  Text('$renewalsDueToday', style: valueStyle),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Most Chosen Insurer
                    Card(
                      elevation: cardElevation,
                      shape: RoundedRectangleBorder(
                          borderRadius: cardBorderRadius),
                      child: Padding(
                        padding: cardPadding,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Most Chosen Insurer',
                                      style: titleStyle),
                                  const SizedBox(height: 8),
                                  Text(
                                    mostChosenInsurer,
                                    style: valueStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Earliest and Latest Due Date
                    Card(
                      elevation: cardElevation,
                      shape: RoundedRectangleBorder(
                          borderRadius: cardBorderRadius),
                      child: Padding(
                        padding: cardPadding,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Due Date Range', style: titleStyle),
                                  const SizedBox(height: 8),
                                  // Check if we're using the new MIN/MAX format
                                  earliestAndLatestDueDate.contains('MIN:')
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // MIN date with red color
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'MIN: ',
                                                    style: TextStyle(
                                                      color: Colors.red[700],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        earliestAndLatestDueDate
                                                            .split('\n')[0]
                                                            .substring(5),
                                                    style: valueStyle.copyWith(
                                                        fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // MAX date with green color
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'MAX: ',
                                                    style: TextStyle(
                                                      color: Colors.green[700],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        earliestAndLatestDueDate
                                                            .split('\n')[1]
                                                            .substring(5),
                                                    style: valueStyle.copyWith(
                                                        fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          earliestAndLatestDueDate,
                                          style:
                                              valueStyle.copyWith(fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Build the due date bar chart
  // Method to show date range picker
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });

      // Reprocess data with the new date range
      _processData();
    }
  }

  Widget _buildDueDateLineChart() {
    // Use the DueDateLineChart widget from lineGraph.dart
    // The chart now fetches its own data from the API
    debugPrint(
        'Building DueDateLineChart with date range: ${_startDate.toString()} to ${_endDate.toString()}');

    return line_graph.DueDateLineChart(
      startDate: _startDate,
      endDate: _endDate,
      onDateRangePressed: () => _selectDateRange(context),
      isExpanded: _isChartExpanded,
      onExpandPressed: () {
        setState(() {
          _isChartExpanded = !_isChartExpanded;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors from the current theme
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color backgroundColor = theme.colorScheme.background;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final Size screenSize = MediaQuery.of(context).size;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            )
          : _errorMessage != null
              ? _buildErrorWidget(_errorMessage!, _isNetworkError, primaryColor)
              : _dashboardData == null
                  ? Center(
                      child: Text(
                        'No data processed or available.',
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    )
                  : _isChartExpanded
                      ? // Expanded chart view
                      Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: backgroundColor,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildDueDateLineChart(),
                            ),
                          ),
                        )
                      : // Normal dashboard view
                      SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            vertical: 40.0,
                            horizontal: 24.0,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth:
                                    1200, // Maximum width for large screens
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  // Hero section with text animation
                                  _buildHeroSection(context),

                                  const SizedBox(height: 30),

                                  // Summary Cards
                                  _buildSummaryCards(context),

                                  const SizedBox(height: 30),

                                  // Charts side by side
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Responsive layout based on available width
                                      if (constraints.maxWidth > 800) {
                                        // Wide layout - charts in a row
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            // Insurer Pie Chart
                                            Expanded(
                                              child: _buildInsurerPieChart(),
                                            ),
                                            const SizedBox(width: 24),
                                            // Due Date Line Chart
                                            Expanded(
                                              child: _buildDueDateLineChart(),
                                            ),
                                          ],
                                        );
                                      } else {
                                        // Narrow layout - charts stacked vertically
                                        return Column(
                                          children: <Widget>[
                                            // Insurer Pie Chart
                                            _buildInsurerPieChart(),
                                            const SizedBox(height: 24),
                                            // Due Date Line Chart
                                            _buildDueDateLineChart(),
                                          ],
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),
      floatingActionButton: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset:
                Offset(0, 4 * sin(_animationController.value * 2 * 3.14159)),
            child: FloatingActionButton.extended(
              onPressed: _fetchAndProcessDashboardData,
              tooltip: 'Refresh Data',
              backgroundColor: Theme.of(context).colorScheme.primary,
              elevation: 4,
              icon: Icon(Icons.refresh_rounded,
                  color: Theme.of(context).colorScheme.onPrimary),
              label: Text(
                'Refresh',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBlock(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final Color secondaryColor = theme.colorScheme.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo on the left with modern animation
          _buildAnimatedLogo(primaryColor),

          const SizedBox(width: 30),

          // Text content on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Subtitle with fade-in animation
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
                  )),
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeIn,
                    child: Text(
                      'Dashboard Overview',
                      style: TextStyle(
                        fontSize: 22,
                        color: textColor.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Additional info with fade-in animation
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.4, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                  )),
                  child: AnimatedOpacity(
                    opacity: 0.9,
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeIn,
                    child: Text(
                      'Your customer data is ready for review',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w300,
                      ),
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

  Widget _buildAnimatedLogo(Color primaryColor) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final ThemeData theme = Theme.of(context);
        final bool isDarkMode = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated circular progress indicator
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _animation.value - 0.95, // Convert scale to progress
                  strokeWidth: 2,
                  backgroundColor:
                      theme.colorScheme.onBackground.withOpacity(0.1),
                  color: primaryColor,
                ),
              ),

              // Logo image with subtle scale animation
              Transform.scale(
                scale: 0.98 +
                    (_animation.value - 0.95) * 0.1, // Subtle scale effect
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      'assets/app_logo.jpg',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Build the upcoming dues section

// This method is now part of the _AdminDashboardPageState class
Widget _buildUpcomingDuesContent(List<UpcomingDueInfo> dues, Color textColor) {
  if (dues.isEmpty) {
    return Text(
      'No upcoming renewals in the next 30 days.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
    );
  }

  // Group dues by month for better organization
  final Map<String, List<UpcomingDueInfo>> duesByMonth = {};

  for (var due in dues) {
    try {
      final date = DateFormat('dd MMM, yyyy').parse(due.dueDate);
      final monthKey = DateFormat('MMMM yyyy').format(date);

      if (!duesByMonth.containsKey(monthKey)) {
        duesByMonth[monthKey] = [];
      }

      duesByMonth[monthKey]!.add(due);
    } catch (e) {
      // Skip entries with unparseable dates
    }
  }

  // Sort the months chronologically
  final sortedMonths = duesByMonth.keys.toList()
    ..sort((a, b) {
      try {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header showing total count
      Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(
          '${dues.length} ${dues.length == 1 ? "Policy" : "Policies"} Due for Renewal',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor.withOpacity(0.8),
          ),
        ),
      ),

      // List of dues grouped by month
      ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300, // Adjust based on your layout needs
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sortedMonths.length,
          itemBuilder: (context, monthIndex) {
            final month = sortedMonths[monthIndex];
            final monthDues = duesByMonth[month]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    month,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),

                // Dues for this month
                ...monthDues.take(5).map((due) {
                  // Get day of month for display
                  final date = DateFormat('dd MMM, yyyy').parse(due.dueDate);
                  final dayOfMonth = DateFormat('d').format(date);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        // Day indicator
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              dayOfMonth,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Customer name
                        Expanded(
                          child: Text(
                            due.customerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // Show "more" indicator if there are more than 5 dues in this month
                if (monthDues.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 36.0, top: 4.0, bottom: 8.0),
                    child: Text(
                      '+ ${monthDues.length - 5} more',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ),

                // Divider between months
                if (monthIndex < sortedMonths.length - 1)
                  Divider(color: textColor.withOpacity(0.1)),
              ],
            );
          },
        ),
      ),
    ],
  );
}

// This method is kept for backward compatibility but not used in the new design
Widget _buildTopListContent(List<String> items, Color textColor) {
  if (items.isEmpty ||
      (items.length == 1 &&
          (items[0] == 'No provider data' || items[0] == 'No model data'))) {
    return Text(
      items.isNotEmpty
          ? items[0]
          : 'No data available.', // Handles empty or placeholder
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
    );
  }
  final List<IconData> medalIcons = [
    Icons.emoji_events, // Gold
    Icons.emoji_events, // Silver
    Icons.emoji_events, // Bronze
  ];
  final List<Color> medalColors = [
    Colors.amber[700]!,
    Colors.grey[500]!,
    Colors.brown[400]!,
  ];

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(items.length > 3 ? 3 : items.length, (index) {
      // Limit to top 3
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(medalIcons[index], color: medalColors[index], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                items[index],
                style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }),
  );
}

class DashboardCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;
  final Color backgroundColor;
  final Color borderColor;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click, // Indicate interactivity
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform:
            _isHovered ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: DottedBorder(
          color: widget.borderColor.withOpacity(_isHovered ? 1.0 : 0.7),
          strokeWidth: _isHovered ? 2.5 : 1.5,
          borderType: BorderType.RRect,
          radius: const Radius.circular(18),
          dashPattern: const [
            8,
            6
          ], // Adjust dash pattern (dash length, space length)
          padding:
              EdgeInsets.zero, // DottedBorder handles padding via its child
          child: Container(
            padding:
                const EdgeInsets.all(16.0), // Increased padding for larger feel
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(
                  17), // Slightly less than DottedBorder radius
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.borderColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Important for card height
              children: <Widget>[
                Row(
                  children: [
                    Icon(widget.icon, color: widget.iconColor, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 17, // Slightly increased font size
                          fontWeight: FontWeight.bold,
                          color: widget.borderColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Increased spacing
                Center(
                    child:
                        widget.content), // Center the main content of the card
              ],
            ),
          ),
        ),
      ),
    );
  }
}
