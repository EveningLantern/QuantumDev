import 'package:flutter/material.dart';
import 'package:dashboard/Pages/admin_dashboard_page.dart';
import 'package:dashboard/Pages/view_in_excel_page.dart';
import 'package:dashboard/Pages/data_analytics_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  void toggleTheme() {
    setState(() => isDarkMode = !isDarkMode);
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
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;

  const HomePage({super.key, required this.isDark, required this.toggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          child: Image.asset(
                            'assets/app_logo.jpg',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
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
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const ThemeToggleButton({
    Key? key,
    required this.isDark,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onToggle,
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
            child: Center(
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
                          Icons.dark_mode_rounded,
                          key: const ValueKey('moon'),
                          color: Colors.indigo,
                          size: 24,
                        )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(delay: 2.seconds, duration: 1.seconds)
                          .animate()
                          .rotate(duration: 1.seconds, begin: 0, end: 0.05)
                          .then()
                          .rotate(duration: 1.seconds, begin: 0.05, end: 0)
                      : Icon(
                          Icons.light_mode_rounded,
                          key: const ValueKey('sun'),
                          color: Colors.amber,
                          size: 24,
                        )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(delay: 2.seconds, duration: 1.seconds)
                          .animate()
                          .rotate(
                              duration: 4.seconds, curve: Curves.easeInOut)),
            ),
          ),
        ),
      ),
    );
  }
}
