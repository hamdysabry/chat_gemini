import 'package:chat_gemini/constant.dart';
import 'package:chat_gemini/hive/chat_history.dart';
import 'package:chat_gemini/hive/setting.dart';
import 'package:chat_gemini/hive/user_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart' as path;

class ChatProvider extends ChangeNotifier {
  final List<ChatHistory> _chatHistory = [];
  UserModel? _userModel;
  Settings? _settings;

  List<ChatHistory> get chatHistory => _chatHistory;
  UserModel? get userModel => _userModel;
  Settings? get settings => _settings;

  static initHive() async {
    final dir = await path.getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.initFlutter(Constant.geminiDB);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatHistoryAdapter());
      await Hive.openBox<ChatHistory>(Constant.chatHistoryBox);
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());
      await Hive.openBox<UserModel>(Constant.userModelBox);
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SettingsAdapter());
      await Hive.openBox<Settings>(Constant.settingsBox);
    }
  }

  void setUserModel(UserModel userModel) {
    _userModel = userModel;
    notifyListeners();
  }

  void setSettings(Settings settings) {
    _settings = settings;
    notifyListeners();
  }

  void addChatHistory(ChatHistory chat) {
    _chatHistory.add(chat);
    notifyListeners();
  }

  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
  }
}
