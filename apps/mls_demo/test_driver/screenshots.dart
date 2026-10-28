import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('../../docs/screenshots')
    ..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      if (!['phone-overview', 'phone-eviction'].contains(name)) return false;
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return bytes.isNotEmpty;
    },
  );
}
