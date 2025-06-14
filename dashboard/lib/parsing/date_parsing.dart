import 'package:intl/intl.dart';

/// Parses an ISO 8601 formatted date string (e.g., "2024-12-22T00:00:00.000Z")
/// and returns a formatted date string in the format "yyyy-MM-dd".
///
/// If the input is null or empty, returns an empty string.
/// If parsing fails, returns the original string.
String parseIsoDateToYYYYMMDD(String? isoDateString) {
  if (isoDateString == null || isoDateString.isEmpty) {
    return '';
  }

  try {
    final DateTime dateTime = DateTime.parse(isoDateString);
    return formatDateToYYYYMMDD(dateTime);
  } catch (e) {
    // If parsing fails, return the original string
    return isoDateString;
  }
}

/// Formats a DateTime object to a string in the format "yyyy-MM-dd".
///
/// If the input is null, returns an empty string.
String formatDateToYYYYMMDD(DateTime? dateTime) {
  if (dateTime == null) {
    return '';
  }

  final DateFormat formatter = DateFormat('yyyy-MM-dd');
  return formatter.format(dateTime);
}

/// Attempts to parse a string date in various formats and returns a DateTime object.
///
/// Supports formats:
/// - ISO 8601 (e.g., "2024-12-22T00:00:00.000Z")
/// - yyyy-MM-dd (e.g., "2024-12-22")
/// - dd.MM.yyyy (e.g., "22.12.2024")
/// - dd/MM/yyyy (e.g., "22/12/2024")
///
/// Returns null if parsing fails.
DateTime? tryParseDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) {
    return null;
  }

  // Try parsing as ISO 8601
  try {
    return DateTime.parse(dateString);
  } catch (_) {
    // Continue to other formats
  }

  // Try common formats
  final List<DateFormat> formats = [
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd.MM.yyyy'),
    DateFormat('dd/MM/yyyy'),
  ];

  for (final format in formats) {
    try {
      return format.parse(dateString);
    } catch (_) {
      // Try next format
    }
  }

  return null;
}
