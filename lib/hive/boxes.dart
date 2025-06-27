import 'package:chat_gemini/constant.dart';
import 'package:chat_gemini/hive/setting.dart';
import 'package:chat_gemini/hive/user_model.dart';
import 'package:hive/hive.dart';

import 'chat_history.dart';

class Boxes {
  static Box<ChatHistory> getChatHistoryBox() =>
      Hive.box<ChatHistory>(Constant.chatHistoryBox);
  static Box<UserModel> getUserModelBox() =>
      Hive.box<UserModel>(Constant.userModelBox);
  static Box<Settings> getSettingsBox() =>
      Hive.box<Settings>(Constant.settingsBox);
}
