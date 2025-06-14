import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

class SearchFilter extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function() onClearSearch;
  final String searchQuery;
  final String hintText;
  final List<String> filterOptions;
  final Function(String) onFilterChanged;
  final String selectedFilter;

  const SearchFilter({
    super.key,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.searchQuery,
    this.hintText = 'Search by ID, Name, or Vehicle Number...',
    this.filterOptions = const ['All', 'ID', 'Name', 'Vehicle Number'],
    required this.onFilterChanged,
    required this.selectedFilter,
  });

  @override
  State<SearchFilter> createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  bool _isSearchFocused = false;
  bool _isDropdownOpen = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);

    // Initialize animation controller for dropdown icon rotation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation =
        Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final containerColor = isDarkMode ? colorScheme.surface : Colors.white;
    final borderColor = isDarkMode
        ? colorScheme.onSurface.withOpacity(0.2)
        : Colors.grey.shade300;
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.grey.withOpacity(0.15);
    final hintTextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500;
    final iconColor = isDarkMode
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey.shade600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar Section
          Row(
            children: [
              // Search Input Field
              Expanded(
                flex: 3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 48, // Fixed height to match filter box
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: _isSearchFocused ? primaryColor : borderColor,
                      width: _isSearchFocused ? 2.0 : 1.0,
                    ),
                    boxShadow: _isSearchFocused
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {
                        _isSearchFocused = hasFocus;
                      });
                    },
                    child: TextField(
                      controller: _searchController,
                      onChanged: widget.onSearchChanged,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: hintTextColor,
                          fontSize: 14,
                        ),
                        prefixIcon: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.search_rounded,
                            color: _isSearchFocused ? primaryColor : iconColor,
                            size: 20,
                          ),
                        ),
                        suffixIcon: widget.searchQuery.isNotEmpty
                            ? TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 300),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.cancel_rounded,
                                        color: iconColor,
                                        size: 18,
                                      ),
                                      splashRadius: 20,
                                      onPressed: () {
                                        _searchController.clear();
                                        widget.onClearSearch();
                                      },
                                    ),
                                  );
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Filter Dropdown
              Expanded(
                flex: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 48, // Fixed height to match search box
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: _isDropdownOpen ? primaryColor : borderColor,
                      width: _isDropdownOpen ? 2.0 : 1.0,
                    ),
                    boxShadow: _isDropdownOpen
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // Customize dropdown menu theme
                      popupMenuTheme: PopupMenuThemeData(
                        color: containerColor,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                          value: widget.selectedFilter,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              widget.onFilterChanged(newValue);
                            }
                            setState(() {
                              _isDropdownOpen = false;
                            });
                            _animationController.reverse();
                          },
                          onTap: () {
                            setState(() {
                              _isDropdownOpen = true;
                            });
                            _animationController.forward();
                          },
                          menuMaxHeight: 300,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 8,
                          dropdownColor: containerColor,
                          alignment: Alignment.center,
                          items: widget.filterOptions
                              .map<DropdownMenuItem<String>>(
                            (String value) {
                              final bool isSelected =
                                  value == widget.selectedFilter;
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 8.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor.withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? primaryColor.withOpacity(0.2)
                                                : isDarkMode
                                                    ? Colors.grey.shade800
                                                    : Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            _getFilterIcon(value),
                                            size: 14,
                                            color: isSelected
                                                ? primaryColor
                                                : iconColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            value,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? primaryColor
                                                  : isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: primaryColor,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: RotationTransition(
                              turns: _rotationAnimation,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color:
                                    _isDropdownOpen ? primaryColor : iconColor,
                                size: 20,
                              ),
                            ),
                          ),
                          isExpanded: true,
                          isDense: true,
                          itemHeight:
                              48, // Must be at least 48 (kMinInteractiveDimension)
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 0),
                          underline: Container(), // Remove any underline
                          selectedItemBuilder: (BuildContext context) {
                            return widget.filterOptions
                                .map<Widget>((String value) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        _getFilterIcon(value),
                                        size: 14,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          }),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Search Results Info
          if (widget.searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.selectedFilter == 'All'
                            ? 'Searching for items containing "${widget.searchQuery}" in any field'
                            : 'Searching for exact match "${widget.searchQuery}" in ${widget.selectedFilter}',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        widget.onClearSearch();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: primaryColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                      label: Text(
                        'Clear',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filterType) {
    switch (filterType) {
      case 'All':
        return Icons.dashboard_rounded;
      case 'ID':
        return Icons.qr_code_rounded;
      case 'Name':
        return Icons.person_rounded;
      case 'Vehicle Number':
        return Icons.directions_car_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }
}

// Additional utility class for advanced search functionality
class SearchFilterUtils {
  static List<T> filterList<T>(
    List<T> items,
    String searchQuery,
    String filterType,
    String Function(T) getId,
    String Function(T) getName,
    String Function(T) getVehicleNumber,
  ) {
    if (searchQuery.isEmpty) return items;

    final query = searchQuery.toLowerCase().trim();

    return items.where((item) {
      switch (filterType) {
        case 'ID':
          // For ID, show only exact ID matches
          return getId(item).toLowerCase() == query;
        case 'Name':
          // For Name, show only exact name matches
          return getName(item).toLowerCase() == query;
        case 'Vehicle Number':
          // For Vehicle Number, show only exact vehicle number matches
          return getVehicleNumber(item).toLowerCase() == query;
        case 'All':
        default:
          // For 'All', allow partial matching in any field
          return getId(item).toLowerCase().contains(query) ||
              getName(item).toLowerCase().contains(query) ||
              getVehicleNumber(item).toLowerCase().contains(query);
      }
    }).toList();
  }

  // Utility method to get a RichText widget with highlighted search term
  static RichText highlightSearchTermRichText(String text, String searchQuery,
      TextStyle baseStyle, TextStyle highlightStyle) {
    if (searchQuery.isEmpty) {
      return RichText(text: TextSpan(text: text, style: baseStyle));
    }

    final query = searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();

    if (!lowerText.contains(query)) {
      return RichText(text: TextSpan(text: text, style: baseStyle));
    }

    final List<TextSpan> spans = [];
    int startIndex = 0;
    int searchIndex;

    // Find all occurrences of the search query and create TextSpans
    while ((searchIndex = lowerText.indexOf(query, startIndex)) != -1) {
      // Add text before the match
      if (searchIndex > startIndex) {
        spans.add(TextSpan(
          text: text.substring(startIndex, searchIndex),
          style: baseStyle,
        ));
      }

      // Add the highlighted match
      spans.add(TextSpan(
        text: text.substring(searchIndex, searchIndex + query.length),
        style: highlightStyle,
      ));

      startIndex = searchIndex + query.length;
    }

    // Add any remaining text
    if (startIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(startIndex),
        style: baseStyle,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  // Original method kept for backward compatibility
  static String highlightSearchTerm(String text, String searchQuery) {
    if (searchQuery.isEmpty) return text;

    final query = searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    if (!lowerText.contains(query)) return text;

    final startIndex = lowerText.indexOf(query);
    final endIndex = startIndex + query.length;

    return text.substring(0, startIndex) +
        '**${text.substring(startIndex, endIndex)}**' +
        text.substring(endIndex);
  }
}
