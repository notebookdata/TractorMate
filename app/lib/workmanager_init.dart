import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return true;
  });
}

Future<void> initWorkmanager() async {
  await Workmanager().initialize(_callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'tractormate_sync',
    'syncTask',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
