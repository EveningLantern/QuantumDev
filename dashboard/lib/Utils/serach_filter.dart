import 'package:flutter/material.dart';

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

class _SearchFilterState extends State<SearchFilter> {
  late TextEditingController _searchController;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: _isSearchFocused
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: _isSearchFocused ? 2.0 : 1.0,
                    ),
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
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _isSearchFocused
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade400,
                        ),
                        suffixIcon: widget.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onClearSearch();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Filter Dropdown
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.selectedFilter,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          widget.onFilterChanged(newValue);
                        }
                      },
                      items: widget.filterOptions.map<DropdownMenuItem<String>>(
                        (String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                children: [
                                  Icon(
                                    _getFilterIcon(value),
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      value,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                      ),
                      isExpanded: true,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Search Results Info
          if (widget.searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Searching for "${widget.searchQuery}" in ${widget.selectedFilter.toLowerCase()}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      widget.onClearSearch();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quick Filter Chips
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              _buildQuickFilterChip('All Records', 'All'),
              _buildQuickFilterChip('By ID', 'ID'),
              _buildQuickFilterChip('By Name', 'Name'),
              _buildQuickFilterChip('By Vehicle', 'Vehicle Number'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, String filterValue) {
    final bool isSelected = widget.selectedFilter == filterValue;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        widget.onFilterChanged(filterValue);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Theme.of(context).primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color:
            isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
    );
  }

  IconData _getFilterIcon(String filterType) {
    switch (filterType) {
      case 'All':
        return Icons.list_alt;
      case 'ID':
        return Icons.tag;
      case 'Name':
        return Icons.person;
      case 'Vehicle Number':
        return Icons.directions_car;
      default:
        return Icons.filter_list;
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
          return getId(item).toLowerCase().contains(query);
        case 'Name':
          return getName(item).toLowerCase().contains(query);
        case 'Vehicle Number':
          return getVehicleNumber(item).toLowerCase().contains(query);
        case 'All':
        default:
          return getId(item).toLowerCase().contains(query) ||
              getName(item).toLowerCase().contains(query) ||
              getVehicleNumber(item).toLowerCase().contains(query);
      }
    }).toList();
  }

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
