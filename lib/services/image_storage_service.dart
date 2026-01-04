import 'dart:io';

import 'package:equb/services/system_log_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageStorageService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;
  final SystemLogService? _logService;

  ImageStorageService({
    FirebaseStorage? storage,
    ImagePicker? picker,
    SystemLogService? logService,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker(),
       _logService = logService;

  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1024,
        maxHeight: maxHeight ?? 1024,
        imageQuality: imageQuality ?? 85,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'ImageStorageService.pickImage',
        e.toString(),
      );
      return null;
    }
  }

  Future<String> uploadProfileImage(String userId, File file) async {
    try {
      final ref = _storage.ref().child('users/$userId/profile.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'ImageStorageService.uploadProfileImage',
        e.toString(),
      );
      rethrow;
    }
  }

  Future<String> uploadGroupBanner(String groupId, File file) async {
    try {
      final ref = _storage.ref().child('groups/$groupId/banner.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'ImageStorageService.uploadGroupBanner',
        e.toString(),
      );
      rethrow;
    }
  }
}
