import 'dart:developer';

import 'package:chat_gemini/api/api_service.dart';
import 'package:chat_gemini/constant.dart';
import 'package:chat_gemini/hive/chat_history.dart';
import 'package:chat_gemini/hive/setting.dart';
import 'package:chat_gemini/hive/user_model.dart';
import 'package:chat_gemini/models/message.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path;

class ChatProvider extends ChangeNotifier {
  final List<Message> _inChatMessages = [];
  final PageController _pageController = PageController();
  final List<XFile> _imagesFileList = [];

  final int _currentPage = 0;
  String _currentChatId = '';

  GenerativeModel? _model;
  GenerativeModel? _textModel;
  GenerativeModel? _visionModel;
  String _modelType = 'gemini-pro';
  bool _isLoading = false;

  List<Message> get inChatMessages => _inChatMessages;
  PageController get pageController => _pageController;
  List<XFile> get imagesFileList => _imagesFileList;
  int get currentPage => _currentPage;
  String get currentChatId => _currentChatId;
  GenerativeModel? get model => _model;
  GenerativeModel? get textModel => _textModel;
  GenerativeModel? get visionModel => _visionModel;
  String get modelType => _modelType;
  bool get isLoading => _isLoading;

  Future<void> setInChatMessages({required String chatId}) async {
    final messageFromDB = await loadMessagesFromDB(chatId: chatId);

    for (final message in messageFromDB) {
      if (!inChatMessages.contains(message)) {
        log("message Already exists in inChatMessages: ${message.messageId}");
      }
      _inChatMessages.add(message);
    }
    notifyListeners();
  }

  Future<List<Message>> loadMessagesFromDB({required String chatId}) async {
    await Hive.openBox("${Constant.chatMessageBox}/$chatId");
    final messageBox = Hive.box("${Constant.chatMessageBox}/$chatId");
    final newData =
        messageBox.keys.map((e) {
          final message = messageBox.get(e);
          final messageData = Message.fromJson(
            Map<String, dynamic>.from(message),
          );

          return messageData;
        }).toList();
    notifyListeners();
    return newData;
  }

  void setImagesFileList({required List<XFile> imagesList}) {
    _imagesFileList.addAll(imagesList);
    notifyListeners();
  }

  void setCurrentPage(int page) {
    _pageController.jumpToPage(page);
    notifyListeners();
  }

  void setCurrentChatId(String chatId) {
    _currentChatId = chatId;
    notifyListeners();
  }

  void setLoading({required bool loading}) {
    _isLoading = loading;
    notifyListeners();
  }

  String setCurrentModel({required String newModel}) {
    _modelType = newModel;
    notifyListeners();
    return newModel;
  }

  Future<void> setModel({required bool isTextOnly}) async {
    if (isTextOnly) {
      _model =
          _textModel ??
          GenerativeModel(
            model: setCurrentModel(newModel: 'gemini-pro'),
            apiKey: ApiService.apiKey,
          );
    } else {
      _model =
          _visionModel ??
          GenerativeModel(
            model: setCurrentModel(newModel: 'gemini-2.5-flash'),
            apiKey: ApiService.apiKey,
          );
    }
    notifyListeners();
  }

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
}
