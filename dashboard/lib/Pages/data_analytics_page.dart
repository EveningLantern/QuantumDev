import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../Utils/due_date_line_chart.dart'; // Import the new chart widget

// Data model (similar to Customer model)
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
    String? rawDueDate = json['due_date'] as String?; // Get the raw due date string

    // Print the raw due_date to help identify its format
    debugPrint('Raw due_date from API: $rawDueDate');

    if (rawDueDate == null || rawDueDate.isEmpty) {
      debugPrint('due_date is null or empty, defaulting to now.');
      parsedDueDate = DateTime.now();
    } else {
      try {
        // Attempt 1: "dd.MM.yyyy" (as per example "17.05.2025")
        parsedDueDate = DateFormat('dd.MM.yyyy').parse(rawDueDate);
      } catch (e1) {
        debugPrint('Failed to parse "$rawDueDate" with dd.MM.yyyy: $e1');
        try {
          // Attempt 2: Standard ISO 8601 parsing (e.g., "2023-10-26T10:00:00Z" or "2023-10-26")
          parsedDueDate = DateTime.parse(rawDueDate);
        } catch (e2) {
          debugPrint('Failed to parse "$rawDueDate" with ISO 8601: $e2');
          try {
            // Attempt 3: "dd/MM/yyyy" (common alternative)
            parsedDueDate = DateFormat('dd/MM/yyyy').parse(rawDueDate);
          } catch (e3) {
            debugPrint('Error parsing due_date "$rawDueDate" with all attempted formats (dd.MM.yyyy, ISO, dd/MM/yyyy): $e1, $e2, $e3. Defaulting to now.');
            parsedDueDate = DateTime.now(); // Fallback if all parsing fails
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
  List<DataPoint> _filteredData = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTimeRange? _selectedDateRange;

  final String _apiUrl = 'http://localhost:3000/getAll';

  @override
  void initState() {
    super.initState();
    // Initialize with a default date range, e.g., this month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0), // Last day of current month
    );
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(Uri.parse(_apiUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          _allData = jsonData.map((item) => DataPoint.fromJson(item)).toList();
          _applyDateFilter(); // Apply initial filter
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${response.statusCode} ${response.reasonPhrase}';
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

  void _applyDateFilter() {
    if (_selectedDateRange == null) {
      _filteredData = List.from(_allData); // No filter applied
    } else {
      _filteredData = _allData.where((point) {
        // Ensure dueDate is compared correctly with the DateTimeRange
        // The end of DateTimeRange is exclusive for the day, so add 1 day or compare carefully
        final start = _selectedDateRange!.start;
        final end = _selectedDateRange!.end.add(const Duration(days: 1)); // Make end date inclusive for the whole day
        return !point.dueDate.isBefore(start) && point.dueDate.isBefore(end);
      }).toList();
    }
    setState(() {}); // Trigger rebuild with filtered data
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) { // Optional: Theme the picker
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _applyDateFilter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Analytics Dashboard'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date Range',
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
              : _allData.isEmpty
                  ? const Center(child: Text('No data available to display.'))
                  : _buildDashboardContent(),
    );
  }

  Widget _buildDashboardContent() {
    final dateFormat = DateFormat('dd MMM yyyy');
    String dateRangeText = 'All Dates';
    if (_selectedDateRange != null) {
      dateRangeText = '${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Displaying data for: $dateRangeText',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Existing Line Chart
          Text(
            'Users vs. Due Date (Filtered Range)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green[700]),
            textAlign: TextAlign.center,
          ),
          Container(
            height: 300,
            padding: const EdgeInsets.only(top: 16),
            child: _buildLineChart(_filteredData), // This uses _filteredData
          ),
          const SizedBox(height: 30),

          // New DueDateLineChart for the next 10 days
          Text(
            'Upcoming Due Dates (Next 10 Days)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.deepPurple[700]), // Different title color
            textAlign: TextAlign.center,
          ),
          Container(
            height: 300,
            padding: const EdgeInsets.only(top: 16, bottom: 16), // Added bottom padding
            child: DueDateLineChart(allDataPoints: _allData), // Pass _allData here
          ),
          const SizedBox(height: 30),
          
          // Layout for Pie Charts (e.g., Row for wider screens, Column for narrower)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) { // Example breakpoint
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildInsurerPieChartCard(_filteredData)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildModelPieChartCard(_filteredData)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildInsurerPieChartCard(_filteredData),
                    const SizedBox(height: 20),
                    _buildModelPieChartCard(_filteredData),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<DataPoint> data) {
    if (data.isEmpty) return const Center(child: Text('No data for selected range.'));

    // Process data for line chart: Group by due date, count users
    Map<DateTime, int> usersByDueDate = {};
    for (var point in data) {
      // Normalize dueDate to ignore time for grouping by day
      DateTime day = DateTime(point.dueDate.year, point.dueDate.month, point.dueDate.day);
      usersByDueDate[day] = (usersByDueDate[day] ?? 0) + 1;
    }

    if (usersByDueDate.isEmpty) return const Center(child: Text('No user activity in selected range.'));

    // Step 1: Get entries from the map and sort them by date
    List<MapEntry<DateTime, int>> sortedEntries = usersByDueDate.entries.toList();
    sortedEntries.sort((a, b) => a.key.compareTo(b.key)); // Sort by date

    // Step 2: Map sorted entries to FlSpot objects
    List<FlSpot> spots = sortedEntries
        .asMap() 
        .entries 
        .map((indexedEntry) {
          return FlSpot(
            indexedEntry.key.toDouble(), 
            indexedEntry.value.value.toDouble() 
          );
        })
        .toList();

    double minY = 0;
    // Ensure spots is not empty before calling reduce
    double maxY = spots.isEmpty ? 5 : spots.map((s) => s.y).reduce((a,b) => a > b ? a : b) * 1.2; 
    if (maxY == 0 && spots.isNotEmpty) maxY = 5; // Handle case where all counts are 0 but spots exist
    if (spots.isEmpty && maxY == 0) maxY = 5; // Ensure maxY is not 0 if spots is empty.


    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                // 'value' is the x-coordinate of the spot, which is its index in sortedEntries.
                final int index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  // Use the date from the 'sortedEntries' list at this index.
                  final DateTime date = sortedEntries[index].key;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4, // Add some space
                    child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
              interval: spots.length > 10 ? (spots.length / 5).ceilToDouble() : 1, // Adjust interval, use ceil
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.green.shade300)),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green[600],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildInsurerPieChartCard(List<DataPoint> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Users by Insurer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green[700]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200, // Fixed height for pie chart
              child: _buildPieChart(data, (point) => point.insurer),
            ),
          ],
        ),
      ),
    );
  }

   Widget _buildModelPieChartCard(List<DataPoint> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Users by Vehicle Model',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green[700]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200, // Fixed height for pie chart
              child: _buildPieChart(data, (point) => point.model),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPieChart(List<DataPoint> data, String Function(DataPoint) getCategory) {
    if (data.isEmpty) return const Center(child: Text('No data.'));

    Map<String, int> distribution = {};
    for (var point in data) {
      String category = getCategory(point);
      distribution[category] = (distribution[category] ?? 0) + 1;
    }
     if (distribution.isEmpty) return const Center(child: Text('No distribution data.'));

    List<PieChartSectionData> sections = [];
    final List<Color> pieColors = [
      Colors.blue.shade400, Colors.red.shade400, Colors.orange.shade400,
      Colors.purple.shade400, Colors.yellow.shade600, Colors.teal.shade400,
      Colors.pink.shade300, Colors.lightGreen.shade500, Colors.cyan.shade400,
      Colors.amber.shade500,
    ];
    int colorIndex = 0;

    double total = distribution.values.fold(0, (sum, item) => sum + item).toDouble();
    if (total == 0) return const Center(child: Text('No items to display in chart.'));

    // Create a list from entries
    List<MapEntry<String, int>> sortedEntries = distribution.entries.toList();
    // Sort the list in place
    sortedEntries.sort((a, b) => b.value.compareTo(a.value)); // Sort by value descending

    // Now use the sorted list
    sortedEntries
      .take(8) // Take top N categories to avoid clutter, plus an "Others"
      .toList() // Convert the Iterable from take(8) back to a List
      .asMap().forEach((index, entry) {
        final percentage = (entry.value / total) * 100;
        sections.add(PieChartSectionData(
          color: pieColors[colorIndex++ % pieColors.length],
          value: entry.value.toDouble(),
          title: '${entry.key.split(" ").map((e) => e.length > 5 ? e.substring(0,3)+"." : e).join(" ")}\n${percentage.toStringAsFixed(1)}%', // Abbreviate long names
          radius: 80,
          titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
          titlePositionPercentageOffset: 0.6,
        ));
      });
    
    // Handle "Others" if there are more categories than displayed
    // Use the already sorted list for consistency if needed, or re-evaluate based on original distribution
    if (distribution.length > 8) {
        double othersValue = 0;
        // Iterate over the original distribution entries, skip the top 8 that were taken from sortedEntries
        // This requires knowing which ones were the top 8.
        // A simpler way is to sum up all values from the original distribution
        // and subtract the sum of the top 8 values already processed.

        double sumOfTop8 = 0;
        sortedEntries.take(8).forEach((entry) {
            sumOfTop8 += entry.value;
        });
        othersValue = total - sumOfTop8;


        if (othersValue > 0) {
            final percentage = (othersValue / total) * 100;
            sections.add(PieChartSectionData(
                color: Colors.grey.shade400,
                value: othersValue,
                title: 'Others\n${percentage.toStringAsFixed(1)}%',
                radius: 80,
                titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                titlePositionPercentageOffset: 0.6,
            ));
        }
    }


    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Handle touch events if needed
          },
        ),
      ),
    );
  }
}