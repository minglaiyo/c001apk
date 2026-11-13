import 'dart:io';

Future<String> resolveHivePath(Directory supportDirectory) async {
  return '${supportDirectory.path}/hive';
}
