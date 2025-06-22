import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../endpoints.dart';
import '../parsing/date_parsing.dart';

class DueDateLineChart extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function() onDateRangePressed;
  final bool isExpanded;
  final Function() onExpandPressed;

  const DueDateLineChart({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangePressed,
    this.isExpanded = false,
    required this.onExpandPressed,
  }) : super(key: key);

  @override
  State<DueDateLineChart> createState() => _DueDateLineChartState();
}

class _DueDateLineChartState extends State<DueDateLineChart> {
  List<DueDateData> _allData = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(DueDateLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch data if date range changes
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse(Endpoints.getAllEndpoint))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        // Process all data and create due date distribution
        final Map<String, int> dueDateCounts = <String, int>{};
        final DateFormat keyFormat = DateFormat('yyyy-MM-dd');

        debugPrint(
            'Raw API Response: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
        debugPrint('Processing ${jsonData.length} records for line chart');

        for (int i = 0; i < jsonData.length; i++) {
          final Map<String, dynamic> customer =
              jsonData[i] as Map<String, dynamic>;

          debugPrint('Processing record $i: ${customer.keys.toList()}');

          // Parse the due date - try different possible field names
          String? dueDateString;
          if (customer.containsKey('dueDate')) {
            dueDateString = customer['dueDate'] as String?;
          } else if (customer.containsKey('due_date')) {
            dueDateString = customer['due_date'] as String?;
          } else if (customer.containsKey('renewalDate')) {
            dueDateString = customer['renewalDate'] as String?;
          } else if (customer.containsKey('renewal_date')) {
            dueDateString = customer['renewal_date'] as String?;
          }

          debugPrint('Found due date string: $dueDateString');

          if (dueDateString != null && dueDateString.isNotEmpty) {
            // Try parsing the date directly as YYYY-MM-DD first
            DateTime? dueDate;
            try {
              if (dueDateString.contains('T')) {
                // ISO format
                dueDate = DateTime.parse(dueDateString);
              } else if (dueDateString.contains('-') &&
                  dueDateString.length >= 10) {
                // YYYY-MM-DD format
                dueDate = DateTime.parse(dueDateString.substring(0, 10));
              } else {
                // Use the parsing utility as fallback
                dueDate = tryParseDate(dueDateString);
              }
            } catch (e) {
              debugPrint('Error parsing date $dueDateString: $e');
              dueDate = tryParseDate(dueDateString);
            }

            if (dueDate != null) {
              final String dateKey = keyFormat.format(dueDate);
              dueDateCounts[dateKey] = (dueDateCounts[dateKey] ?? 0) + 1;
              debugPrint(
                  'Successfully processed due date: $dateKey, count now: ${dueDateCounts[dateKey]}');
            } else {
              debugPrint('Failed to parse due date: $dueDateString');
            }
          } else {
            debugPrint('No due date found in record $i');
          }
        }

        // Convert to DueDateData objects
        final List<DueDateData> allData = dueDateCounts.entries.map((entry) {
          final date = keyFormat.parse(entry.key);
          final count = entry.value;
          return DueDateData(date: date, count: count);
        }).toList();

        // Sort by date
        allData.sort((a, b) => a.date.compareTo(b.date));

        debugPrint('Total processed data points: ${allData.length}');
        if (allData.isNotEmpty) {
          debugPrint(
              'Date range in data: ${allData.first.date} to ${allData.last.date}');
        }

        setState(() {
          _allData = allData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } on SocketException {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildLineChart(
      List<DueDateData> dailyData,
      int maxCount,
      ThemeData theme,
      Color lineColor,
      Color gradientColor,
      Color dotColor,
      Color backgroundColor,
      Color subtitleColor,
      Color gridColor,
      Color borderColor) {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.colorScheme.primary,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final int index = spot.x.toInt();
                if (index < 0 || index >= dailyData.length) {
                  return null;
                }

                final date = dailyData[index].date;
                final count = dailyData[index].count;

                return LineTooltipItem(
                  '${DateFormat('EEE, MMM d, yyyy').format(date)}\n$count ${count == 1 ? 'customer' : 'customers'} on this day',
                  TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isExpanded
                        ? 16
                        : 14, // Larger font when expanded
                  ),
                );
              }).toList();
            },
            tooltipMargin: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
          ),
          handleBuiltInTouches: true,
          touchSpotThreshold: 20,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxCount > 10 ? maxCount / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: gridColor,
              strokeWidth: 1,
              dashArray: [5, 5], // Dotted lines
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize:
                  widget.isExpanded ? 60 : 50, // More space when expanded
              interval: dailyData.length > 10
                  ? (dailyData.length / 5).ceil().toDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= dailyData.length) {
                  return const SizedBox();
                }

                final date = dailyData[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM d').format(date),
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: widget.isExpanded
                              ? 13
                              : 11, // Larger font when expanded
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Add day of week for better context
                      Text(
                        DateFormat('E')
                            .format(date), // Day of week (e.g., Mon, Tue)
                        style: TextStyle(
                          color: subtitleColor.withOpacity(0.8),
                          fontSize: widget.isExpanded
                              ? 11
                              : 9, // Larger font when expanded
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'Daily Customers',
              style: TextStyle(
                color: subtitleColor,
                fontSize:
                    widget.isExpanded ? 14 : 12, // Larger font when expanded
              ),
            ),
            axisNameSize:
                widget.isExpanded ? 30 : 25, // More space when expanded
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize:
                  widget.isExpanded ? 50 : 40, // More space when expanded
              interval: maxCount > 10 ? maxCount / 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                if (value % 1 == 0 || maxCount > 20) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: widget.isExpanded
                            ? 13
                            : 11, // Larger font when expanded
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1),
            left: BorderSide(color: borderColor, width: 1),
          ),
        ),
        minX: 0,
        maxX: (dailyData.length - 1).toDouble(),
        minY: 0,
        maxY: dailyData.isEmpty
            ? 10
            : (dailyData.map((e) => e.count).reduce(max) * 1.2)
                .toDouble(), // Add some space at the top
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(dailyData.length, (index) {
              return FlSpot(
                index.toDouble(),
                dailyData[index].count.toDouble(),
              );
            }),
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: widget.isExpanded ? 4 : 3, // Thicker line when expanded
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius:
                      widget.isExpanded ? 5 : 4, // Larger dots when expanded
                  color: dotColor,
                  strokeWidth: 2,
                  strokeColor: backgroundColor,
                );
              },
              checkToShowDot: (spot, barData) {
                // Show dots at regular intervals or for important points
                return dailyData.length <= 10 ||
                    spot.x.toInt() % ((dailyData.length / 5).ceil()) == 0 ||
                    spot.x.toInt() == dailyData.length - 1;
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: gradientColor,
              gradient: LinearGradient(
                colors: [
                  gradientColor,
                  gradientColor.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height:
            widget.isExpanded ? MediaQuery.of(context).size.height - 100 : 350,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height:
            widget.isExpanded ? MediaQuery.of(context).size.height - 100 : 350,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Debug print to check if data is being received
    debugPrint(
        'DueDateLineChart build: received ${_allData.length} data points');
    debugPrint('Date range in chart: ${widget.startDate} to ${widget.endDate}');

    // Filter data based on the selected date range - ensure we traverse ALL data
    final List<DueDateData> filteredData = [];

    debugPrint('Starting to filter data...');
    debugPrint('Filter range: ${widget.startDate} to ${widget.endDate}');
    debugPrint('Available data points: ${_allData.length}');

    for (int i = 0; i < _allData.length; i++) {
      final item = _allData[i];

      // More detailed date comparison
      final bool isAfterStart = !item.date.isBefore(widget.startDate);
      final bool isBeforeEnd = !item.date.isAfter(widget.endDate);
      final bool isInRange = isAfterStart && isBeforeEnd;

      debugPrint(
          'Item $i: date=${item.date.toString().substring(0, 10)}, count=${item.count}');
      debugPrint(
          '  - After start (${widget.startDate.toString().substring(0, 10)}): $isAfterStart');
      debugPrint(
          '  - Before end (${widget.endDate.toString().substring(0, 10)}): $isBeforeEnd');
      debugPrint('  - In range: $isInRange');

      if (isInRange) {
        filteredData.add(item);
        debugPrint('  ✓ Added to filtered data');
      } else {
        debugPrint('  ✗ Filtered out');
      }
    }

    debugPrint('After filtering: ${filteredData.length} data points remain');

    // Sort the filtered data by date
    filteredData.sort((a, b) => a.date.compareTo(b.date));

    // Create a complete date range with 0 values for missing dates
    final List<DueDateData> dailyData = [];
    final Map<String, int> dataMap = {};
    final DateFormat keyFormat = DateFormat('yyyy-MM-dd');

    // Convert filtered data to a map for quick lookup
    for (var item in filteredData) {
      final String dateKey = keyFormat.format(item.date);
      dataMap[dateKey] = item.count;
    }

    // Generate all dates in the range
    DateTime currentDate = DateTime(
        widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final DateTime endDate =
        DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);

    debugPrint('Filling date range from $currentDate to $endDate');

    while (!currentDate.isAfter(endDate)) {
      final String dateKey = keyFormat.format(currentDate);
      final int count = dataMap[dateKey] ?? 0; // Use 0 if no data for this date

      dailyData.add(DueDateData(date: currentDate, count: count));
      debugPrint('Added date: $dateKey with count: $count');

      currentDate = currentDate.add(const Duration(days: 1));
    }

    final ThemeData theme = Theme.of(context);
    final Color lineColor = theme.colorScheme.primary;
    final Color gradientColor = theme.colorScheme.primary.withOpacity(0.2);
    final Color dotColor = theme.colorScheme.secondary;
    final Color backgroundColor = theme.colorScheme.surface;
    final Color textColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final Color subtitleColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final Color gridColor = theme.colorScheme.onSurface.withOpacity(0.1);
    final Color borderColor = theme.colorScheme.onSurface.withOpacity(0.2);

    // Find the maximum count for scaling
    final int maxCount =
        dailyData.isEmpty ? 1 : dailyData.map((e) => e.count).reduce(max);

    debugPrint('Final daily data has ${dailyData.length} points');
    if (dailyData.isNotEmpty) {
      debugPrint(
          'First point: ${dailyData.first.date} - ${dailyData.first.count}');
      debugPrint(
          'Last point: ${dailyData.last.date} - ${dailyData.last.count}');

      // Show a few sample points to verify the data
      for (int i = 0; i < dailyData.length && i < 5; i++) {
        debugPrint(
            'Sample point $i: ${dailyData[i].date.toString().substring(0, 10)} - ${dailyData[i].count}');
      }
    }

    debugPrint('Rendering DueDateLineChart container');

    return Container(
      height:
          widget.isExpanded ? MediaQuery.of(context).size.height - 100 : 350,
      width: widget.isExpanded ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Renewals Trend',
                style: TextStyle(
                  fontSize:
                      widget.isExpanded ? 24 : 18, // Larger font when expanded
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.date_range,
                        color: theme.colorScheme.primary),
                    tooltip: 'Select Date Range',
                    onPressed: widget.onDateRangePressed,
                  ),
                  IconButton(
                    icon: Icon(
                      widget.isExpanded
                          ? Icons.close_fullscreen
                          : Icons.open_in_full,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip:
                        widget.isExpanded ? 'Collapse View' : 'Expand View',
                    onPressed: widget.onExpandPressed,
                  ),
                ],
              ),
            ],
          ),
          // Display selected date range
          Text(
            'Range: ${DateFormat('dd MMM, yyyy').format(widget.startDate)} - ${DateFormat('dd MMM, yyyy').format(widget.endDate)}',
            style: TextStyle(
              fontSize:
                  widget.isExpanded ? 14 : 12, // Larger font when expanded
              color: subtitleColor,
            ),
          ),
          // Legend for the chart
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: widget.isExpanded
                      ? 14
                      : 12, // Larger indicator when expanded
                  height: widget.isExpanded ? 14 : 12,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Daily renewals',
                  style: TextStyle(
                    fontSize: widget.isExpanded
                        ? 13
                        : 11, // Larger font when expanded
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildLineChart(
                dailyData,
                maxCount,
                theme,
                lineColor,
                gradientColor,
                dotColor,
                backgroundColor,
                subtitleColor,
                gridColor,
                borderColor),
          ),
        ],
      ),
    );
  }
}

class DueDateData {
  final DateTime date;
  final int count;

  DueDateData({
    required this.date,
    required this.count,
  });
}
