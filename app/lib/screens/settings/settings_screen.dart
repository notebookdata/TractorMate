import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../database/app_database.dart';
import '../reports/reports_screen.dart';
import '../analytics/analytics_screen.dart';
import 'user_management_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const _keyLanguage = 'app_language';

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) => LanguageNotifier());

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_keyLanguage) ?? 'en';
    state = Locale(lang);
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang);
    state = Locale(lang);
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _testingConnection = false;
  String? _connectionResult;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _loadLastSync();
  }

  Future<void> _loadServerUrl() async {
    final url = await ref.read(apiServiceProvider).getBaseUrl();
    _urlCtrl.text = url;
  }

  Future<void> _loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('last_sync_time');
    if (ts != null) setState(() => _lastSync = DateTime.tryParse(ts));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final locale = ref.watch(languageProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings / ಸೆಟ್ಟಿಂಗ್ಸ್')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    radius: 28,
                    child: Text(
                      (authState.username ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authState.username ?? 'User',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(authState.role ?? 'user',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Language section
          _SectionHeader('Language / ಭಾಷೆ'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.language, color: AppTheme.primary),
                  const SizedBox(width: 16),
                  const Text('App Language', style: TextStyle(fontSize: 16)),
                  const Spacer(),
                  SegmentedButton<String>(
                    selected: {locale.languageCode},
                    onSelectionChanged: (v) => ref.read(languageProvider.notifier).setLanguage(v.first),
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'kn', label: Text('ಕನ್ನಡ')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sync section
          _SectionHeader('Sync / ಸಿಂಕ್'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync, color: AppTheme.primary),
                  title: const Text('Sync Status'),
                  trailing: Text(
                    _syncLabel(syncStatus),
                    style: TextStyle(color: _syncColor(syncStatus), fontWeight: FontWeight.bold),
                  ),
                ),
                if (_lastSync != null)
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.grey),
                    title: const Text('Last Sync / ಕೊನೆಯ ಸಿಂಕ್'),
                    trailing: Text(
                      _lastSync!.toLocal().toString().substring(0, 16),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(syncServiceProvider).sync();
                      _loadLastSync();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now / ಈಗ ಸಿಂಕ್ ಮಾಡಿ'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Server URL section
          _SectionHeader('Server / ಸರ್ವರ್'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      prefixIcon: Icon(Icons.dns),
                      hintText: 'http://YOUR_SERVER_IP/tractormate-api',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(apiServiceProvider).updateBaseUrl(_urlCtrl.text.trim());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Server URL updated')),
                              );
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testingConnection ? null : _testConnection,
                          icon: _testingConnection
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check),
                          label: const Text('Test'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        ),
                      ),
                    ],
                  ),
                  if (_connectionResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _connectionResult!,
                      style: TextStyle(
                        color: _connectionResult!.contains('success') ? AppTheme.paid : AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Management (Admin only, Web only)
          if (kIsWeb && authState.role == 'admin') ...[
            _SectionHeader('User Management / ಬಳಕೆದಾರ ನಿರ್ವಹಣೆ'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.manage_accounts, color: AppTheme.primary),
                title: const Text('Manage Users'),
                subtitle: const Text('Add, edit, delete users'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Analytics & Reports (Admin only)
          if (authState.role == 'admin') ...[
            _SectionHeader('Analytics & Reports / ವಿಶ್ಲೇಷಣೆ ಮತ್ತು ವರದಿ'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bar_chart, color: AppTheme.primary),
                    title: const Text('Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Charts • ಗ್ರಾಫ್ • ವಿಶ್ಲೇಷಣೆ'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: AppTheme.primary),
                    title: const Text('Generate Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: const Text('PDF • ಹಂಚಿಕೊಳ್ಳಿ • Print'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Reset Database (Admin only, Web only)
          if (kIsWeb && authState.role == 'admin') ...[
            _SectionHeader('⚠️ Danger Zone / ಅಪಾಯದ ವಲಯ'),
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Reset All Data',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Delete all customers, rentals, expenses, and drivers. This cannot be undone!',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () => _confirmResetDatabase(context),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // About
          _SectionHeader('About / ಬಗ್ಗೆ'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.agriculture, color: AppTheme.primary),
                  title: Text('TractorMate'),
                  trailing: Text('v1.0.0', style: TextStyle(color: Colors.grey)),
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.grey),
                  title: Text('Tractor Rent & Expense Tracker'),
                  subtitle: Text('ಟ್ರ್ಯಾಕ್ಟರ್ ಬಾಡಿಗೆ ಮತ್ತು ಖರ್ಚು ಟ್ರ್ಯಾಕರ್'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, color: AppTheme.danger),
            label: const Text('Logout / ಹೊರಗೆ ಹೋಗಿ',
                style: TextStyle(color: AppTheme.danger, fontSize: 17)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              side: const BorderSide(color: AppTheme.danger),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });
    await ref.read(apiServiceProvider).updateBaseUrl(_urlCtrl.text.trim());
    final ok = await ref.read(apiServiceProvider).checkHealth();
    setState(() {
      _testingConnection = false;
      _connectionResult = ok ? 'Connection success!' : 'Connection failed. Check URL.';
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?\nಲಾಗ್ ಔಟ್ ಮಾಡಲು ಖಚಿತವಾಗಿ ಬಯಸುವಿರಾ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _confirmResetDatabase(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Reset All Data?'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All Customers\n'
          '• All Rentals\n'
          '• All Expenses\n'
          '• All Drivers\n'
          '• All Attendance Records\n\n'
          'This action CANNOT be undone!\n\n'
          'User accounts will remain intact.\n\n'
          'ಇದು ಎಲ್ಲಾ ಗ್ರಾಹಕರು, ಬಾಡಿಗೆ, ಖರ್ಚುಗಳು ಮತ್ತು ಚಾಲಕರನ್ನು ಶಾಶ್ವತವಾಗಿ ಅಳಿಸುತ್ತದೆ!',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Resetting database...'),
                    ],
                  ),
                ),
              );
              
              try {
                await ref.read(apiServiceProvider).resetAllData();
                
                // Clear local database as well
                final db = AppDatabase();
                await db.transaction(() async {
                  await db.delete(db.driverAttendancesTable).go();
                  await db.delete(db.driversTable).go();
                  await db.delete(db.rentalsTable).go();
                  await db.delete(db.expensesTable).go();
                  await db.delete(db.customersTable).go();
                });
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('✓ Success'),
                      content: const Text('All data has been cleared successfully!'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Error'),
                      content: Text('Failed to reset data: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Delete All Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _syncLabel(SyncStatus s) {
    switch (s) {
      case SyncStatus.synced: return 'Synced ✓';
      case SyncStatus.syncing: return 'Syncing...';
      case SyncStatus.pending: return 'Pending';
      case SyncStatus.error: return 'Error';
    }
  }

  Color _syncColor(SyncStatus s) {
    switch (s) {
      case SyncStatus.synced: return AppTheme.paid;
      case SyncStatus.syncing: return Colors.blue;
      case SyncStatus.pending: return AppTheme.partial;
      case SyncStatus.error: return AppTheme.danger;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
