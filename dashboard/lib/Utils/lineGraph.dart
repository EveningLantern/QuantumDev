import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class DueDateLineChart extends StatelessWidget {
  final List<DueDateData> data;
  final DateTime startDate;
  final DateTime endDate;
  final Function() onDateRangePressed;

  const DueDateLineChart({
    Key? key,
    required this.data,
    required this.startDate,
    required this.endDate,
    required this.onDateRangePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug print to check if data is being received
    debugPrint('DueDateLineChart build: received ${data.length} data points');
    debugPrint('Date range in chart: $startDate to $endDate');

    // Filter data based on the selected date range
    final List<DueDateData> filteredData = data.where((item) {
      final bool isInRange =
          !item.date.isBefore(startDate) && !item.date.isAfter(endDate);
      if (!isInRange) {
        debugPrint('Filtering out date ${item.date} - outside range');
      }
      return isInRange;
    }).toList();

    debugPrint('After filtering: ${filteredData.length} data points remain');

    // Sort the filtered data by date
    filteredData.sort((a, b) => a.date.compareTo(b.date));

    final ThemeData theme = Theme.of(context);
    final Color lineColor = theme.colorScheme.primary;
    final Color gradientColor = theme.colorScheme.primary.withOpacity(0.2);
    final Color dotColor = theme.colorScheme.secondary;

    // Find the maximum count for scaling
    final int maxCount =
        filteredData.isEmpty ? 1 : filteredData.map((e) => e.count).reduce(max);

    // Calculate cumulative counts for each date
    final List<DueDateData> cumulativeData = [];
    int runningTotal = 0;

    debugPrint(
        'Calculating cumulative data from ${filteredData.length} filtered points');

    for (var item in filteredData) {
      runningTotal += item.count;
      debugPrint(
          'Date: ${item.date}, Count: ${item.count}, Running Total: $runningTotal');
      cumulativeData.add(DueDateData(date: item.date, count: runningTotal));
    }

    debugPrint('Final cumulative data has ${cumulativeData.length} points');
    if (cumulativeData.isNotEmpty) {
      debugPrint(
          'First point: ${cumulativeData.first.date} - ${cumulativeData.first.count}');
      debugPrint(
          'Last point: ${cumulativeData.last.date} - ${cumulativeData.last.count}');
    }

    debugPrint('Rendering DueDateLineChart container');

    return Container(
      height: 350, // Increased height for better visibility
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                'Upcoming Renewals Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.date_range, color: Colors.blue),
                tooltip: 'Select Date Range',
                onPressed: onDateRangePressed,
              ),
            ],
          ),
          // Display selected date range
          Text(
            'Range: ${DateFormat('dd MMM, yyyy').format(startDate)} - ${DateFormat('dd MMM, yyyy').format(endDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          // Legend for the chart
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Cumulative renewals',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: cumulativeData.isEmpty
                ? Center(
                    child: Text(
                      'No renewal data available in selected date range',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final int index = spot.x.toInt();
                              if (index < 0 || index >= cumulativeData.length) {
                                return null;
                              }

                              final date = cumulativeData[index].date;
                              final count = cumulativeData[index].count;

                              return LineTooltipItem(
                                '${DateFormat('EEE, MMM d, yyyy').format(date)}\n$count ${count == 1 ? 'customer' : 'customers'} total',
                                TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                            color: Colors.grey[200],
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
                            reservedSize: 50, // More space for two-line labels
                            interval: cumulativeData.length > 10
                                ? (cumulativeData.length / 5).ceil().toDouble()
                                : 1,
                            getTitlesWidget: (value, meta) {
                              final int index = value.toInt();
                              if (index < 0 || index >= cumulativeData.length) {
                                return const SizedBox();
                              }

                              final date = cumulativeData[index].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('MMM d').format(date),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    // Add day of week for better context
                                    Text(
                                      DateFormat('E').format(
                                          date), // Day of week (e.g., Mon, Tue)
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 9,
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
                            'Cumulative Customers',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                          axisNameSize: 25,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: maxCount > 10 ? maxCount / 5 : 1,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox();
                              if (value % 1 == 0 || maxCount > 20) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 11,
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
                          bottom:
                              BorderSide(color: Colors.grey[300]!, width: 1),
                          left: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                      minX: 0,
                      maxX: (cumulativeData.length - 1).toDouble(),
                      minY: 0,
                      maxY: cumulativeData.isEmpty
                          ? 10
                          : (cumulativeData.last.count * 1.2)
                              .toDouble(), // Add some space at the top
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(cumulativeData.length, (index) {
                            return FlSpot(
                              index.toDouble(),
                              cumulativeData[index].count.toDouble(),
                            );
                          }),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: lineColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: dotColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                            checkToShowDot: (spot, barData) {
                              // Show dots at regular intervals or for important points
                              return cumulativeData.length <= 10 ||
                                  spot.x.toInt() %
                                          ((cumulativeData.length / 5)
                                              .ceil()) ==
                                      0 ||
                                  spot.x.toInt() == cumulativeData.length - 1;
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
                  ),
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
