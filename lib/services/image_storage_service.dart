import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import '../utils/logger.dart';

abstract class ImageStorageService {
  Future<String> saveImage(File imageFile);
  Future<String> saveImageBytes(Uint8List bytes, String extension);
  Future<void> deleteImage(String relativePath);
  Future<File?> getImage(String relativePath);
  Future<String> getFullPath(String relativePath);
  Future<Uint8List?> getImageBytes(String relativePath);
}

class LocalImageStorageService implements ImageStorageService {
  static const String _imagesFolder = 'images';
  static const int _maxDimension = 1920;
  static const int _jpegQuality = 80;

  @override
  Future<String> saveImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();
    return saveImageBytes(bytes, extension);
  }

  @override
  Future<String> saveImageBytes(Uint8List bytes, String extension) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/$_imagesFolder');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Compress image
    final compressed = await _compressImage(bytes);

    // Generate unique filename
    final filename = '${const Uuid().v4()}.jpg';
    final relativePath = '$_imagesFolder/$filename';
    final fullPath = '${appDir.path}/$relativePath';

    // Save file
    final file = File(fullPath);
    await file.writeAsBytes(compressed);

    AppLogger.info('ImageStorageService: Saved image to $relativePath');
    return relativePath;
  }

  @override
  Future<void> deleteImage(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/$relativePath';
    final file = File(fullPath);

    if (await file.exists()) {
      await file.delete();
      AppLogger.info('ImageStorageService: Deleted image at $relativePath');
    }
  }

  @override
  Future<File?> getImage(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/$relativePath';
    final file = File(fullPath);

    if (await file.exists()) {
      return file;
    }
    return null;
  }

  @override
  Future<String> getFullPath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  @override
  Future<Uint8List?> getImageBytes(String relativePath) async {
    final file = await getImage(relativePath);
    if (file != null) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize if too large
    img.Image resized = image;
    if (image.width > _maxDimension || image.height > _maxDimension) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: _maxDimension);
      } else {
        resized = img.copyResize(image, height: _maxDimension);
      }
    }

    // Encode as JPEG with compression
    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }
}
