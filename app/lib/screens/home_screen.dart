import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard/dashboard_screen.dart';
import 'customers/customers_screen.dart';
import 'drivers/drivers_screen.dart';
import 'rentals/rentals_screen.dart';
import 'expenses/expenses_screen.dart';
import 'settings/settings_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';

    // Build screens list based on role
    final screens = [
      const DashboardScreen(),
      const CustomersScreen(),
      if (isAdmin) const DriversScreen(),
      const RentalsScreen(),
      const ExpensesScreen(),
      const SettingsScreen(),
    ];

    // Build navigation destinations based on role
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Customers',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Drivers',
        ),
      const NavigationDestination(
        icon: Icon(Icons.agriculture_outlined),
        selectedIcon: Icon(Icons.agriculture),
        label: 'Rentals',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Expenses',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70,
          destinations: destinations,
        ),
      ),
    );
  }
}
