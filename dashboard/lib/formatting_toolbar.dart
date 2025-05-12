import 'package:flutter/material.dart';

class FormattingToolbar extends StatelessWidget {
  final bool isBoldActive;
  final bool isUnderlineActive;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleUnderline;
  final VoidCallback onPickHighlightColor;

  const FormattingToolbar({
    super.key,
    required this.isBoldActive,
    required this.isUnderlineActive,
    required this.onToggleBold,
    required this.onToggleUnderline,
    required this.onPickHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.format_bold),
            tooltip: 'Bold',
            color: isBoldActive
                ? Theme.of(context).colorScheme.primary
                : Colors.black87,
            onPressed: onToggleBold,
          ),
          IconButton(
            icon: const Icon(Icons.format_underline),
            tooltip: 'Underline',
            color: isUnderlineActive
                ? Theme.of(context).colorScheme.primary
                : Colors.black87,
            onPressed: onToggleUnderline,
          ),
          IconButton(
            icon: const Icon(Icons.format_color_fill),
            tooltip: 'Highlight Color',
            onPressed: onPickHighlightColor,
          ),
        ],
      ),
    );
  }
}