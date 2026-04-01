import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_provider.dart';

final uploadProvider = Provider((ref) => UploadService(ref));

class UploadService {
  final Ref _ref;
  UploadService(this._ref);

  Future<Map<String, dynamic>?> uploadFile(XFile file, String type) async {
    final dio = _ref.read(dioProvider);
    
    final bytes = await file.readAsBytes();
    final multipartFile = MultipartFile.fromBytes(bytes, filename: file.name);

    final formData = FormData.fromMap({
      'file': multipartFile,
      'file_type': type,
    });

    try {
      final response = await dio.post('/api/files/upload', data: formData);
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<XFile?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 2048,
    );
    return pickedFile;
  }
}
