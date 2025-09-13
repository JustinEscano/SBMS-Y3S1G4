class ChatMessage {
  final String id;
  final String content;
  final String type; // 'user' or 'assistant' instead of bool isUser
  final DateTime timestamp;
  final String? conversationId;
  final List<Source>? sources;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.conversationId,
    this.sources,
    this.isLoading = false,
  });

  // Helper getter for convenience
  bool get isUser => type == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      type: json['type'] ?? 'user',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toString()),
      conversationId: json['conversation_id'],
      sources: json['sources'] != null
          ? List<Source>.from(json['sources'].map((x) => Source.fromJson(x)))
          : null,
      isLoading: json['is_loading'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'conversation_id': conversationId,
      'sources': sources?.map((x) => x.toJson()).toList(),
      'is_loading': isLoading,
    };
  }
}

class Source {
  final String pageContent;
  final SourceMetadata metadata;

  Source({
    required this.pageContent,
    required this.metadata,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      pageContent: json['page_content'] ?? '',
      metadata: SourceMetadata.fromJson(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page_content': pageContent,
      'metadata': metadata.toJson(),
    };
  }
}

class SourceMetadata {
  final String timestamp;
  final int occupancyCount;
  final double energyKwh;
  final double powerTotal;
  final double temperature;
  final double humidity;
  final String docHash;

  SourceMetadata({
    required this.timestamp,
    required this.occupancyCount,
    required this.energyKwh,
    required this.powerTotal,
    required this.temperature,
    required this.humidity,
    required this.docHash,
  });

  factory SourceMetadata.fromJson(Map<String, dynamic> json) {
    return SourceMetadata(
      timestamp: json['timestamp'] ?? '',
      occupancyCount: json['occupancy_count'] ?? 0,
      energyKwh: (json['energy_kwh'] ?? 0).toDouble(),
      powerTotal: (json['power_total'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      docHash: json['doc_hash'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'occupancy_count': occupancyCount,
      'energy_kwh': energyKwh,
      'power_total': powerTotal,
      'temperature': temperature,
      'humidity': humidity,
      'doc_hash': docHash,
    };
  }
}