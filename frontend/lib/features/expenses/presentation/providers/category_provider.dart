import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class CategoryModel {
  final int id;
  final String name;
  final String icon;

  CategoryModel({required this.id, required this.name, required this.icon});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String,
    );
  }
}

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() async {
    return _fetchCategories();
  }

  Future<List<CategoryModel>> _fetchCategories() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/api/categories');
    if (res.data['success'] == true) {
      final list = res.data['data'] as List<dynamic>;
      return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(CategoriesNotifier.new);

final topCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/categories/top');
  if (res.data['success'] == true) {
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
});
