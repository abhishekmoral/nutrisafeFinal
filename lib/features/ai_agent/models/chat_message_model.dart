class ChatMessageModel {
  ChatMessageModel({
    required this.isUser,
    required this.content,
    required this.createdAt,
    this.safetyLevel,
    this.isError = false,
  });

  final bool isUser;
  final String content;
  final DateTime createdAt;
  final String? safetyLevel; // null | urgent | emergency
  final bool isError;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final metadata = (json['metadata'] as Map?) ?? const {};
    return ChatMessageModel(
      isUser: json['role'] == 'user',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      safetyLevel: metadata['safety_level'] as String?,
    );
  }
}
