import 'package:hive_flutter/hive_flutter.dart';
part 'setting.g.dart';

@HiveType(typeId: 2)
class Settings extends HiveObject {
  @HiveField(0)
  bool darkMode = false;
  @HiveField(1)
  bool shouldSpeak = false;

  Settings({required this.darkMode, required this.shouldSpeak});
}
