class AppMessage {
  final int? id;
  final String title;
  final String body;
  final String data;
  final DateTime receivedAt;
  final bool isRead;

  const AppMessage({
    this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'received_at': receivedAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory AppMessage.fromMap(Map<String, dynamic> map) {
    return AppMessage(
      id: map['id'] as int?,
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      data: map['data']?.toString() ?? '',
      receivedAt: DateTime.tryParse(map['received_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: (map['is_read'] as int? ?? 0) == 1,
    );
  }
}
