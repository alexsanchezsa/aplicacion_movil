/// Modelo que representa una cámara de dron disponible para streaming
class DroneCamera {
  final String id;
  final String name;
  final String streamUrl;
  final String? thumbnailUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? location;
  final String? description;
  final DroneCameraType type;

  DroneCamera({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.thumbnailUrl,
    this.isOnline = false,
    this.lastSeen,
    this.location,
    this.description,
    this.type = DroneCameraType.rtsp,
  });

  /// Crear desde JSON (para API)
  factory DroneCamera.fromJson(Map<String, dynamic> json) {
    return DroneCamera(
      id: json['id'] as String,
      name: json['name'] as String,
      streamUrl: json['streamUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      location: json['location'] as String?,
      description: json['description'] as String?,
      type: DroneCameraType.fromString(json['type'] as String?),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'streamUrl': streamUrl,
      'thumbnailUrl': thumbnailUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'location': location,
      'description': description,
      'type': type.value,
    };
  }

  /// Crear copia con propiedades modificadas
  DroneCamera copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? thumbnailUrl,
    bool? isOnline,
    DateTime? lastSeen,
    String? location,
    String? description,
    DroneCameraType? type,
  }) {
    return DroneCamera(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      location: location ?? this.location,
      description: description ?? this.description,
      type: type ?? this.type,
    );
  }
}

/// Tipos de protocolo de streaming soportados
enum DroneCameraType {
  rtsp('rtsp'),
  rtmp('rtmp'),
  hls('hls'),
  http('http'),
  mjpeg('mjpeg');

  final String value;
  const DroneCameraType(this.value);

  static DroneCameraType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'rtsp':
        return DroneCameraType.rtsp;
      case 'rtmp':
        return DroneCameraType.rtmp;
      case 'hls':
        return DroneCameraType.hls;
      case 'http':
        return DroneCameraType.http;
      case 'mjpeg':
        return DroneCameraType.mjpeg;
      default:
        return DroneCameraType.rtsp;
    }
  }
}
