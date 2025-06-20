import 'package:flutter/material.dart';
import 'package:dashboard/Pages/admin_dashboard_page.dart';
import 'package:dashboard/Pages/view_in_excel_page.dart';
import 'package:dashboard/Pages/data_analytics_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _setTimeBasedTheme();
  }

  void _setTimeBasedTheme() {
    final now = DateTime.now();
    final hour = now.hour;

    // Set dark theme after 4 PM (16:00) and before 6 AM (06:00)
    // Light theme from 6 AM to 4 PM
    setState(() {
      isDarkMode = hour >= 16 || hour < 6;
    });
  }

  void toggleTheme() {
    setState(() => isDarkMode = !isDarkMode);
  }

  void resetToTimeBasedTheme() {
    _setTimeBasedTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard',
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? darkTheme : lightTheme,
      home: HomePage(
        isDark: isDarkMode,
        toggleTheme: toggleTheme,
        resetToTimeBasedTheme: resetToTimeBasedTheme,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;
  final VoidCallback resetToTimeBasedTheme;

  const HomePage({
    super.key,
    required this.isDark,
    required this.toggleTheme,
    required this.resetToTimeBasedTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _userImagePath = 'assets/app_logo.jpg';

  final List<Widget> _pages = [
    AdminDashboardPage(),
    ViewInExcelPage(),
    DataAnalyticsPage(),
  ];

  final List<String> _pageTitles = [
    'Admin Dashboard',
    'View in Excel',
    'Data Analytics',
  ];

  final List<IconData> _icons = [
    Icons.admin_panel_settings,
    Icons.table_chart,
    Icons.analytics,
  ];

  @override
  void initState() {
    super.initState();
    _loadUserImage();
  }

  Future<void> _loadUserImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userImagePath =
            prefs.getString('user_image_path') ?? 'assets/app_logo.jpg';
      });
    } catch (e) {
      debugPrint('Error loading user image: $e');
    }
  }

  Widget _buildImageWidget(String imagePath, double width, double height) {
    if (imagePath.startsWith('assets/')) {
      // Asset image
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/app_logo.jpg',
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      // File image
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/app_logo.jpg',
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
        );
      } else {
        // File doesn't exist, fall back to default
        return Image.asset(
          'assets/app_logo.jpg',
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh user image when switching to admin dashboard
    if (index == 0) {
      _loadUserImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) {
        // Refresh image when navigating back
        _loadUserImage();
      },
      child: Scaffold(
        body: Row(
          children: [
            Container(
              width: 70,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  ThemeToggleButton(
                    isDark: widget.isDark,
                    onToggle: widget.toggleTheme,
                    onReset: widget.resetToTimeBasedTheme,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_icons.length, (index) {
                        final isSelected = index == _selectedIndex;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: _pageTitles[index],
                            child: IconButton(
                              icon: Icon(
                                _icons[index],
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                              ),
                              onPressed: () => _onItemTapped(index),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    automaticallyImplyLeading: false,
                    title: Row(
                      children: [
                        // Circular logo image
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: _buildImageWidget(_userImagePath, 36, 36),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(_pageTitles[_selectedIndex]),
                      ],
                    ),
                  ),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const ThemeToggleButton({
    Key? key,
    required this.isDark,
    required this.onToggle,
    required this.onReset,
  }) : super(key: key);

  String _getTimeBasedTooltip() {
    final now = DateTime.now();
    final hour = now.hour;
    final isTimeBasedDark = hour >= 16 || hour < 6;

    if (isDark == isTimeBasedDark) {
      // Current theme matches time-based preference
      return isDark
          ? 'Single tap: Switch to Light Mode\nDouble tap: Reset to Auto\n(Currently: Auto Dark - Evening/Night)'
          : 'Single tap: Switch to Dark Mode\nDouble tap: Reset to Auto\n(Currently: Auto Light - Morning/Day)';
    } else {
      // User has manually overridden the time-based theme
      return isDark
          ? 'Single tap: Switch to Light Mode\nDouble tap: Reset to Auto\n(Manual Override - Auto suggests Light)'
          : 'Single tap: Switch to Dark Mode\nDouble tap: Reset to Auto\n(Manual Override - Auto suggests Dark)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final isTimeBasedDark = hour >= 16 || hour < 6;
    final isManualOverride = isDark != isTimeBasedDark;

    return Tooltip(
      message: _getTimeBasedTooltip(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onToggle,
          onDoubleTap: onReset,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            splashColor: isDark
                ? Colors.indigo.withOpacity(0.4)
                : Colors.amber.withOpacity(0.4),
            highlightColor: isDark
                ? Colors.indigo.withOpacity(0.2)
                : Colors.amber.withOpacity(0.2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.indigo.withOpacity(0.2)
                    : Colors.amber.withOpacity(0.2),
                border: isManualOverride
                    ? Border.all(
                        color: isDark ? Colors.indigo : Colors.amber,
                        width: 2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.indigo.withOpacity(0.3)
                        : Colors.amber.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: isDark
                            ? Icon(
                                Icons.light_mode_rounded,
                                key: const ValueKey('sun'),
                                color: Colors.amber,
                                size: 24,
                              )
                                .animate(
                                    onPlay: (controller) => controller.repeat())
                                .shimmer(delay: 2.seconds, duration: 1.seconds)
                                .animate()
                                .rotate(
                                    duration: 4.seconds,
                                    curve: Curves.easeInOut)
                            : Icon(
                                Icons.dark_mode_rounded,
                                key: const ValueKey('moon'),
                                color: Colors.indigo,
                                size: 24,
                              )
                                .animate(
                                    onPlay: (controller) => controller.repeat())
                                .shimmer(delay: 2.seconds, duration: 1.seconds)
                                .animate()
                                .rotate(
                                    duration: 1.seconds, begin: 0, end: 0.05)
                                .then()
                                .rotate(
                                    duration: 1.seconds, begin: 0.05, end: 0)),
                  ),
                  // Small indicator for manual override
                  if (isManualOverride)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.amber : Colors.indigo,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
