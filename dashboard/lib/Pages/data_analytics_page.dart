import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date formatting
import '../endpoints.dart'; // Backend endpoints

// Data model for customer information
class DataPoint {
  final String id;
  final String name;
  final DateTime dueDate; // Store as DateTime for easier comparison
  final String vehicleNumber;
  final String contactNumber;
  final String model;
  final String insurer;

  DataPoint({
    required this.id,
    required this.name,
    required this.dueDate,
    required this.vehicleNumber,
    required this.contactNumber,
    required this.model,
    required this.insurer,
  });

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    DateTime parsedDueDate;
    String? rawDueDate = json['due_date'] as String?;

    if (rawDueDate == null || rawDueDate.isEmpty) {
      parsedDueDate = DateTime.now();
    } else {
      try {
        // Attempt 1: "yyyy-MM-dd" format
        parsedDueDate = DateFormat('yyyy-MM-dd').parse(rawDueDate);
      } catch (e1) {
        try {
          // Attempt 2: "dd.MM.yyyy" (as per example "17.05.2025")
          parsedDueDate = DateFormat('dd.MM.yyyy').parse(rawDueDate);
        } catch (e2) {
          try {
            // Attempt 3: Standard ISO 8601 parsing
            parsedDueDate = DateTime.parse(rawDueDate);
          } catch (e3) {
            try {
              // Attempt 4: "dd/MM/yyyy" (common alternative)
              parsedDueDate = DateFormat('dd/MM/yyyy').parse(rawDueDate);
            } catch (e4) {
              parsedDueDate = DateTime.now(); // Fallback if all parsing fails
            }
          }
        }
      }
    }

    return DataPoint(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'N/A',
      dueDate: parsedDueDate,
      vehicleNumber: json['vehicle_number'] ?? 'N/A',
      contactNumber: json['contact_number'] ?? 'N/A',
      model: json['model'] ?? 'Unknown Model',
      insurer: json['insurer'] ?? 'Unknown Insurer',
    );
  }
}

class DataAnalyticsPage extends StatefulWidget {
  const DataAnalyticsPage({super.key});

  @override
  State<DataAnalyticsPage> createState() => _DataAnalyticsPageState();
}

class _DataAnalyticsPageState extends State<DataAnalyticsPage> {
  List<DataPoint> _allData = [];
  bool _isLoading = true;
  String? _errorMessage;

  final String _apiUrl = Endpoints.getAllEndpoint;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          _allData = jsonData.map((item) => DataPoint.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load data: ${response.statusCode} ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  // Get top 10 earliest due dates from today
  List<DataPoint> getEarliestDue() {
    final now = DateTime.now();
    final sortedData = List<DataPoint>.from(_allData);

    // Filter out past due dates
    sortedData.removeWhere((item) => item.dueDate.isBefore(now));

    // Sort by due date (ascending)
    sortedData.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // Return top 10 or all if less than 10
    return sortedData.take(10).toList();
  }

  // Get most popular insurers
  List<MapEntry<String, int>> getMostPopularInsurers() {
    Map<String, int> insurerCounts = {};

    for (var point in _allData) {
      String insurer = point.insurer.isEmpty ? 'Unknown' : point.insurer;
      insurerCounts[insurer] = (insurerCounts[insurer] ?? 0) + 1;
    }

    // Convert to list and sort by count (descending)
    List<MapEntry<String, int>> sortedInsurers = insurerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedInsurers.take(10).toList();
  }

  // Get renewals for current month
  List<DataPoint> getMonthlyRenewals() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    return _allData.where((point) {
      return point.dueDate.month == currentMonth &&
          point.dueDate.year == currentYear &&
          !point.dueDate.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).primaryColor,
                  ),
                  tooltip: 'Refresh data',
                  onPressed: () {
                    _fetchData(); // Refresh all data
                  },
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text('Error: $_errorMessage',
                      style: const TextStyle(color: Colors.red)))
              : _allData.isEmpty
                  ? const Center(child: Text('No data available to display.'))
                  : _buildDashboardContent(),
    );
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Data Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Three equal boxes with 9:16 ratio
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Box 1: Earliest Due
                    Expanded(
                      child: _buildAnalyticsBox(
                        title: 'Earliest Due',
                        icon: Icons.timer,
                        content: _buildEarliestDueList(),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Box 2: Most Popular Insurer
                    Expanded(
                      child: _buildAnalyticsBox(
                        title: 'Most Popular Insurer',
                        icon: Icons.star,
                        content: _buildPopularInsurersList(),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Box 3: Monthly Renewals
                    Expanded(
                      child: _buildAnalyticsBox(
                        title: 'Monthly Renewals',
                        icon: Icons.calendar_month,
                        content: _buildMonthlyRenewalsList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsBox({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildEarliestDueList() {
    final earliestDue = getEarliestDue();

    if (earliestDue.isEmpty) {
      return const Center(child: Text('No upcoming due dates'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: earliestDue.length,
      itemBuilder: (context, index) {
        final item = earliestDue[index];
        return _buildHoverableListItem(
          title: item.name,
          subtitle: 'Due: ${DateFormat('dd MMM yyyy').format(item.dueDate)}',
          index: index,
        );
      },
    );
  }

  Widget _buildPopularInsurersList() {
    final popularInsurers = getMostPopularInsurers();

    if (popularInsurers.isEmpty) {
      return const Center(child: Text('No insurer data available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: popularInsurers.length,
      itemBuilder: (context, index) {
        final item = popularInsurers[index];
        return _buildHoverableListItem(
          title: item.key,
          subtitle: '${item.value} policies',
          index: index,
        );
      },
    );
  }

  Widget _buildMonthlyRenewalsList() {
    final monthlyRenewals = getMonthlyRenewals();

    if (monthlyRenewals.isEmpty) {
      return const Center(
        child: Text('No renewals for this month'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: monthlyRenewals.length,
      itemBuilder: (context, index) {
        final item = monthlyRenewals[index];
        return _buildHoverableListItem(
          title: item.name,
          subtitle: 'Due: ${DateFormat('dd MMM yyyy').format(item.dueDate)}',
          index: index,
        );
      },
    );
  }

  Widget _buildHoverableListItem({
    required String title,
    required String subtitle,
    required int index,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: index.isEven
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Builder(
          builder: (context) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                // Optional: Add action when item is tapped
              },
            );
          },
        ),
      ),
    );
  }
}
