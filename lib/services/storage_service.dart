import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// An image chosen by the user, held in memory so the same code works on
/// Android, iOS and the web (where `dart:io` File is unavailable).
class PickedImage {
  const PickedImage({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;

  String get contentType {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

/// Uploads images (posters, product photos, receipts, avatars) to Firebase
/// Storage and returns their download URL.
class StorageService {
  StorageService({FirebaseStorage? storage, ImagePicker? picker})
      : _storageOverride = storage,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage? _storageOverride;
  final ImagePicker _picker;

  // Resolved lazily so the service can be constructed in widget tests
  // without a Firebase app.
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Opens the gallery (or camera) and returns the chosen image, or null.
  Future<PickedImage?> pickImage({bool fromCamera = false}) async {
    final x = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return null;
    return PickedImage(bytes: await x.readAsBytes(), name: x.name);
  }

  /// [folder] e.g. `posters/{eventId}`, `products/{vendorId}`, `avatars`.
  Future<String> upload(PickedImage image, String folder) async {
    final safeName = image.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = _storage.ref('$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName');
    final task = await ref.putData(
      image.bytes,
      SettableMetadata(contentType: image.contentType),
    );
    return task.ref.getDownloadURL();
  }

  Future<String?> pickAndUpload(String folder, {bool fromCamera = false}) async {
    final image = await pickImage(fromCamera: fromCamera);
    if (image == null) return null;
    return upload(image, folder);
  }
}
