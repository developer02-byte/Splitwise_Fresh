import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

final globalSearchProvider = FutureProvider.family<Map<String, List<dynamic>>, String>((ref, query) async {
  if (query.length < 2) return {'groups': [], 'friends': [], 'expenses': []};

  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/search', queryParameters: {'q': query});

  if (response.data['success'] == true) {
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'groups': data['groups'] as List<dynamic>,
      'friends': data['friends'] as List<dynamic>,
      'expenses': data['expenses'] as List<dynamic>,
    };
  }
  return {'groups': [], 'friends': [], 'expenses': []};
});
