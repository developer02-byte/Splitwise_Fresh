import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class CommentModel {
  final int id;
  final String? text;
  final String? userName;
  final String? avatarUrl;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    this.text,
    this.userName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      text: json['commentText'],
      userName: json['user']?['name'],
      avatarUrl: json['user']?['avatarUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class ExpenseCommentsNotifier extends FamilyAsyncNotifier<List<CommentModel>, int> {
  @override
  Future<List<CommentModel>> build(int arg) async {
    return _fetchComments();
  }

  Future<List<CommentModel>> _fetchComments() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/api/expenses/$arg/comments');
    if (res.data['success'] == true) {
      final list = res.data['data'] as List;
      return list.map((e) => CommentModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> addComment(String text) async {
    final dio = ref.read(dioProvider);
    final res = await dio.post('/api/expenses/$arg/comments', data: {'text': text});
    if (res.data['success'] == true) {
      ref.invalidateSelf();
    }
  }
}

final expenseCommentsProvider = AsyncNotifierProvider.family<ExpenseCommentsNotifier, List<CommentModel>, int>(ExpenseCommentsNotifier.new);
