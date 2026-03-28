import 'package:flutter/widgets.dart';
import 'package:tanodmobile/app/app.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.initialize();
  runApp(const TanodMobileApp());
}
