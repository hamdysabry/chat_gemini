import 'dart:developer';
import 'dart:io';

import 'package:chat_gemini/api/api_service.dart';
import 'package:chat_gemini/constant.dart';
import 'package:chat_gemini/hive/chat_history.dart';
import 'package:chat_gemini/hive/setting.dart';
import 'package:chat_gemini/hive/user_model.dart';
import 'package:chat_gemini/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:uuid/uuid.dart';

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

  Future<void> sentMessage({
    required String message,
    required bool isTextOnly,
  }) async {
    await setModel(isTextOnly: isTextOnly);
    setLoading(loading: true);
    String chatId = getChatId();
    List<Content> history = [];
    history = await getHistory(chatId: chatId);
    List<String> imagesUrl = getImageUrls(isTextOnly: isTextOnly);
    final userMessage = Message(
      messageId: '',
      role: Role.user,
      message: StringBuffer(message),
      imagesUrls: imagesUrl,
      timeSent: DateTime.now(),
      chatId: chatId,
    );
    _inChatMessages.add(userMessage);
    notifyListeners();
    if (currentChatId.isEmpty) {
      setCurrentChatId(chatId);
    }
  }

  Future<void> sendMessageAndWaitForResponse({
    required String message,
    required String chatId,
    required Message userMessage,
    List<Content> history = const [],
    required bool isTextOnly,
  }) async {
    final chatSession = _model!.startChat(
      history: history.isNotEmpty || !isTextOnly ? null : history,
    );
    final content = await getContent(message: message, isTextOnly: isTextOnly);
    final assistantMessage = userMessage.copyWith(
      messageId: '',
      role: Role.assistant,
      message: StringBuffer(),
      timeSent: DateTime.now(),
    );
    _inChatMessages.add(assistantMessage);
    notifyListeners();

    chatSession
        .sendMessageStream(content)
        .asyncMap((event) {
          return event;
        })
        .listen(
          (event) {
            _inChatMessages
                .firstWhere(
                  (element) =>
                      element.messageId == assistantMessage.messageId &&
                      element.role == Role.assistant,
                )
                .message
                .write(event.text);
            notifyListeners();
          },
          onDone: () {
            setLoading(loading: false);
          },
        )
        .onError((error, stackTrace) {
          setLoading(loading: false);
          log('Error sending message: $error');
          // Handle the error
        });
  }

  Future<Content> getContent({
    required String message,

    required bool isTextOnly,
  }) async {
    if (isTextOnly) {
      return Content.text(message);
    } else {
      final imageFuture = _imagesFileList
          .map((imageFile) => imageFile.readAsBytes())
          .toList(growable: false);

      final imageByte = await Future.wait(imageFuture);
      final prompt = TextPart(message);
      final imageParts =
          imageByte
              .map((bytes) => DataPart('image/jpg', Uint8List.fromList(bytes)))
              .toList();
      return Content.model([prompt, ...imageParts]);
    }
  }

  List<String> getImageUrls({required bool isTextOnly}) {
    List<String> imagesUrl = [];
    if (isTextOnly && imagesFileList.isNotEmpty) {
      for (var image in imagesFileList) {
        imagesUrl.add(image.path);
      }
    }

    return imagesUrl;
  }

  Future<List<Content>> getHistory({required String chatId}) async {
    List<Content> history = [];
    if (currentChatId.isNotEmpty) {
      await setInChatMessages(chatId: chatId);
      for (final message in inChatMessages) {
        if (message.role == 'user') {
          history.add(Content.text(message.message.toString()));
        } else {
          history.add(Content.model([TextPart(message.message.toString())]));
        }
      }
    }
    return history;
  }

  String getChatId() {
    if (_currentChatId.isEmpty) {
      return Uuid().v4();
    }
    return _currentChatId;
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

    // Ensure subdirectories exist
    final chatMessageDir = Directory(
      '${dir.path}/${Constant.geminiDB}/chat_message',
    );
    if (!(await chatMessageDir.exists())) {
      await chatMessageDir.create(recursive: true);
    }

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
