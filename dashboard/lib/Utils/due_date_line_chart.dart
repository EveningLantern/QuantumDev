import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../Pages/data_analytics_page.dart'; // For DataPoint model

class DueDateLineChart extends StatelessWidget {
  final List<DataPoint> allDataPoints;
  final int numberOfDaysToShow = 10;

  DueDateLineChart({Key? key, required this.allDataPoints}) : super(key: key);

  Widget _bottomTitleWidgets(double value, TitleMeta meta, List<DateTime> xAxisDates) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    String text = '';
    final int index = value.toInt();
    if (index >= 0 && index < xAxisDates.length) {
      text = DateFormat('dd/MM').format(xAxisDates[index]);
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(text, style: style),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff67727d),
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    String text;
    if (value == 0) {
      text = '0';
    } else if (value % 1 == 0) { // Show integer values
      text = value.toInt().toString();
    } else {
      return Container(); // Don't show labels for non-integer values on Y axis for counts
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(text, style: style, textAlign: TextAlign.left),
      // reservedSize: 32, // Removed this line
    );
  }

  List<LineTooltipItem?> _getTooltipItems(List<LineBarSpot> touchedSpots, List<DateTime> xAxisDates) {
    return touchedSpots.map((LineBarSpot touchedSpot) {
      final flSpot = touchedSpot;
      if (flSpot.spotIndex < 0 || flSpot.spotIndex >= xAxisDates.length) {
        return null;
      }

      final DateTime date = xAxisDates[flSpot.spotIndex];
      final String dateText = DateFormat('dd MMM yyyy').format(date);
      final int count = flSpot.y.toInt();

      return LineTooltipItem(
        '$dateText\n',
        const TextStyle(
          color: Colors.white, // Tooltip text color
          fontWeight: FontWeight.bold,
        ),
        children: [
          TextSpan(
            text: '$count user${count == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
        textAlign: TextAlign.left,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);

    final List<DateTime> xAxisDates = List.generate(
      numberOfDaysToShow,
      (index) => startDate.add(Duration(days: index)),
    );

    final Map<DateTime, int> countsByDate = {
      for (var date in xAxisDates) date: 0,
    };

    for (final dataPoint in allDataPoints) {
      final dueDateNormalized = DateTime(dataPoint.dueDate.year, dataPoint.dueDate.month, dataPoint.dueDate.day);
      if (countsByDate.containsKey(dueDateNormalized)) {
        countsByDate[dueDateNormalized] = countsByDate[dueDateNormalized]! + 1;
      }
    }

    final List<FlSpot> spots = [];
    for (int i = 0; i < xAxisDates.length; i++) {
      final date = xAxisDates[i];
      spots.add(FlSpot(i.toDouble(), countsByDate[date]!.toDouble()));
    }

    double maxY = 5;
    if (spots.isNotEmpty) {
      final maxCount = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (maxCount > 0) {
        maxY = (maxCount * 1.2).ceilToDouble();
      }
    }
     if (maxY < 5) maxY = 5; // Ensure Y axis shows at least up to 5

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (numberOfDaysToShow - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xffe7e8ec), strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(color: Color(0xffe7e8ec), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, xAxisDates),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY / 5).ceilToDouble() > 0 ? (maxY / 5).ceilToDouble() : 1, // Dynamic interval
              getTitlesWidget: _leftTitleWidgets,
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xffe7e8ec), width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
            ),
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => _getTooltipItems(touchedSpots, xAxisDates),
            // tooltipBgColor: Colors.blueGrey.withOpacity(0.8), // Replaced this line
            getTooltipColor: (LineBarSpot spot) => Colors.blueGrey.withOpacity(0.8), // With this line
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}