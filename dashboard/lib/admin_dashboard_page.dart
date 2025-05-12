import 'dart:convert';
import 'dart:io'; // For SocketException
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date parsing and comparison

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
    return CustomerData(
      customerName: json['customer_name'] ?? json['customerName'] ?? 'N/A', // Adjust based on your API
      dueDate: json['due_date'] ?? json['dueDate'] ?? 'N/A',
      insuranceProvider: json['insurance_provider'] ?? json['insuranceProvider'] ?? 'N/A',
      carModel: json['car_model'] ?? json['carModel'] ?? 'N/A',
    );
  }
}

// Define data models for the processed dashboard information
class UpcomingDueInfo {
  final String customerName;
  final String dueDate; // Can be the original string or formatted

  UpcomingDueInfo({required this.customerName, required this.dueDate});
}

class AdminDashboardProcessedData {
  final List<UpcomingDueInfo> upcomingDues;
  final List<String> topInsurers; // List of names
  final List<String> topCarModels; // List of names

  AdminDashboardProcessedData({
    required this.upcomingDues,
    required this.topInsurers,
    required this.topCarModels,
  });
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminDashboardProcessedData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNetworkError = false;
  final String _apiUrlBase = 'http://localhost:3000';

  @override
  void initState() {
    super.initState();
    _fetchAndProcessDashboardData();
  }

  Future<void> _fetchAndProcessDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isNetworkError = false;
    });

    List<CustomerData> allCustomers = [];

    try {
      // Step 1: Fetch all data
      final response = await http.get(Uri.parse('$_apiUrlBase/getAll')) // Changed endpoint
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        allCustomers = jsonData.map((item) => CustomerData.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${response.statusCode} ${response.reasonPhrase}';
          if (response.statusCode >= 500) { // Basic check for server-side issues
            _errorMessage = 'Server currently not working (Error ${response.statusCode}). Please try again later.';
            _isNetworkError = true; // Treat server errors as a type of network/connectivity issue for UI
          }
          _isLoading = false;
        });
        return;
      }
    } on SocketException {
      setState(() {
        _errorMessage = 'Network error. Server currently not working or no internet connection.';
        _isNetworkError = true;
        _isLoading = false;
      });
      return;
    } on http.ClientException catch (e) {
       setState(() {
        _errorMessage = 'Could not connect to the server. Server currently not working or check your network. ($e)';
        _isNetworkError = true;
        _isLoading = false;
      });
      return;
    }
    catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
      return;
    }

    // Step 2: Process the fetched data
    if (allCustomers.isNotEmpty) {
      try {
        // Process Upcoming Dues (due in next 30 days)
        final List<UpcomingDueInfo> upcomingDuesList = [];
        final DateTime now = DateTime.now();
        final DateTime thirtyDaysFromNow = now.add(const Duration(days: 30));

        for (var customer in allCustomers) {
          try {
            // Attempt to parse the date. Adjust format if needed.
            // Example: if dueDate is "dd/MM/yyyy", use DateFormat('dd/MM/yyyy')
            final DateFormat apiDateFormat = DateFormat('yyyy-MM-dd'); // Assuming YYYY-MM-DD from API
            DateTime dueDate = apiDateFormat.parse(customer.dueDate);
            
            // Check if due date is in the future and within the next 30 days
            if (dueDate.isAfter(now) && dueDate.isBefore(thirtyDaysFromNow)) {
              upcomingDuesList.add(UpcomingDueInfo(
                  customerName: customer.customerName,
                  dueDate: DateFormat('dd MMM, yyyy').format(dueDate) // Format for display
              ));
            }
          } catch (e) {
            // Handle cases where a specific due_date might be unparseable
            debugPrint('Could not parse due date for ${customer.customerName}: ${customer.dueDate} - $e');
            // Optionally add to a list of problematic entries or show a generic entry
            // For now, we skip it if unparseable
          }
        }
        upcomingDuesList.sort((a, b) => DateFormat('dd MMM, yyyy').parse(a.dueDate).compareTo(DateFormat('dd MMM, yyyy').parse(b.dueDate)));


        // Process Top 3 Insurance Providers
        final Map<String, int> insurerCounts = {};
        for (var customer in allCustomers) {
          if (customer.insuranceProvider.isNotEmpty && customer.insuranceProvider != 'N/A') {
            insurerCounts[customer.insuranceProvider] = (insurerCounts[customer.insuranceProvider] ?? 0) + 1;
          }
        }
        final sortedInsurers = insurerCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final List<String> topInsurersList = sortedInsurers.take(3).map((e) => e.key).toList();

        // Process Top 3 Car Models
        final Map<String, int> carModelCounts = {};
        for (var customer in allCustomers) {
           if (customer.carModel.isNotEmpty && customer.carModel != 'N/A') {
            carModelCounts[customer.carModel] = (carModelCounts[customer.carModel] ?? 0) + 1;
           }
        }
        final sortedCarModels = carModelCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final List<String> topCarModelsList = sortedCarModels.take(3).map((e) => e.key).toList();

        setState(() {
          _dashboardData = AdminDashboardProcessedData(
            upcomingDues: upcomingDuesList,
            topInsurers: topInsurersList,
            topCarModels: topCarModelsList,
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
        _dashboardData = AdminDashboardProcessedData(upcomingDues: [], topInsurers: [], topCarModels: []);
        _isLoading = false;
        // Optionally set a message like "No customer data found to process."
      });
    }
  }

  // Moved _buildErrorWidget inside the State class
  Widget _buildErrorWidget(String message, bool isNetworkError, Color iconColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              color: isNetworkError ? Colors.orange[600] : Colors.red[600],
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
              message, // This will now show "Server currently not working..." when appropriate
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (isNetworkError || message.contains("Server currently not working")) // Show retry for server issues too
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _fetchAndProcessDashboardData, // Correctly calls the method
              ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Colors.green[700]!;
    final Color lightGreenBackground = Colors.green[50]!;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget(_errorMessage!, _isNetworkError, primaryGreen)
              : _dashboardData == null // Should ideally not happen if processing logic is sound
                  ? const Center(child: Text('No data processed or available.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // First Row of Cards
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: DashboardCard(
                                  title: 'Upcoming Dues',
                                  icon: Icons.notification_important_rounded,
                                  iconColor: Colors.orange[600]!,
                                  content: _buildUpcomingDuesContent(
                                      _dashboardData!.upcomingDues, primaryGreen),
                                  backgroundColor: lightGreenBackground,
                                  borderColor: primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DashboardCard(
                                  title: 'Top 3 Insurance Providers',
                                  icon: Icons.business_center_rounded,
                                  iconColor: Colors.blue[600]!,
                                  content: _buildTopListContent(
                                      _dashboardData!.topInsurers.isNotEmpty
                                          ? _dashboardData!.topInsurers
                                          : ['No provider data'], 
                                      primaryGreen),
                                  backgroundColor: lightGreenBackground,
                                  borderColor: primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DashboardCard(
                                  title: 'Top 3 Car Models',
                                  icon: Icons.directions_car_filled_rounded,
                                  iconColor: Colors.purple[600]!,
                                  content: _buildTopListContent(
                                      _dashboardData!.topCarModels.isNotEmpty
                                          ? _dashboardData!.topCarModels
                                          : ['No model data'], 
                                      primaryGreen),
                                  backgroundColor: lightGreenBackground,
                                  borderColor: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24), // Increased spacing between rows

                          // Second Row of Cards
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: DashboardCard(
                                  title: 'Recently Paid',
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: Colors.green[600]!,
                                  content: Text(
                                    // This part still needs backend data or logic if you want to display something meaningful
                                    'Data for "Recently Paid" not yet implemented.',
                                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                                    textAlign: TextAlign.center,
                                  ),
                                  backgroundColor: lightGreenBackground,
                                  borderColor: primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DashboardCard(
                                  title: 'Due Days Past Unpaid',
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: Colors.red[600]!,
                                  content: Text(
                                     // This part still needs backend data or logic
                                    'Data for "Past Unpaid" not yet implemented.',
                                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                                    textAlign: TextAlign.center,
                                  ),
                                  backgroundColor: lightGreenBackground,
                                  borderColor: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAndProcessDashboardData,
        tooltip: 'Refresh Data',
        backgroundColor: primaryGreen,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildUpcomingDuesContent(List<UpcomingDueInfo> dues, Color textColor) {
    if (dues.isEmpty) {
      return Text(
        'No upcoming dues in the next 30 days.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: Colors.grey[700]),
      );
    }
    // Make the card taller by ensuring its content takes up space.
    // A ListView or Column with multiple items will achieve this.
    return Column(
      mainAxisSize: MainAxisSize.min, // Important for card height to wrap content
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // Example: "5 Policies Due Soon:"
          '${dues.length} ${dues.length == 1 ? "Policy" : "Policies"} Due Soon:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        // If the list can be long, consider ConstrainedBox + ListView
        // For a few items, Column is fine.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 150, // Adjust max height as needed to control card size
          ),
          child: ListView.builder(
            shrinkWrap: true, // Important if inside another scroll view or Column
            itemCount: dues.length,
            itemBuilder: (context, index) {
              final due = dues[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        due.customerName,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      due.dueDate, // This is now the formatted date string
                      style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopListContent(List<String> items, Color textColor) {
    if (items.isEmpty || (items.length == 1 && (items[0] == 'No provider data' || items[0] == 'No model data'))) {
       return Text(
        items.isNotEmpty ? items[0] : 'No data available.', // Show specific placeholder
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
      children: List.generate(items.length > 3 ? 3 : items.length, (index) { // Limit to top 3
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
        transform: _isHovered ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: DottedBorder(
          color: widget.borderColor.withOpacity(_isHovered ? 1.0 : 0.7),
          strokeWidth: _isHovered ? 2.5 : 1.5,
          borderType: BorderType.RRect,
          radius: const Radius.circular(18),
          dashPattern: const [8, 6], // Adjust dash pattern (dash length, space length)
          padding: EdgeInsets.zero, // DottedBorder handles padding via its child
          child: Container(
            padding: const EdgeInsets.all(16.0), // Increased padding for larger feel
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(17), // Slightly less than DottedBorder radius
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
                Center(child: widget.content), // Center the main content of the card
              ],
            ),
          ),
        ),
      ),
    );
  }
}