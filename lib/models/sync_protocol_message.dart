import 'dart:convert';
import 'dart:typed_data';

/// A model representing a message in the sync protocol
class SyncProtocolMessage {
  final MessageType type;
  final Map<String, dynamic> payload;
  final String messageId;

  SyncProtocolMessage({
    required this.type,
    required this.payload,
    required this.messageId,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'payload': payload,
      'messageId': messageId,
    };
  }

  // Create from JSON
  factory SyncProtocolMessage.fromJson(Map<String, dynamic> json) {
    return SyncProtocolMessage(
      type: MessageType.values[json['type']],
      payload: json['payload'],
      messageId: json['messageId'],
    );
  }

  // Convert to bytes for network transmission
  Uint8List toBytes() {
    final jsonString = jsonEncode(toJson());
    final bytes = utf8.encode(jsonString);
    
    // Create a header with the message length (4 bytes)
    final header = ByteData(4)..setUint32(0, bytes.length, Endian.big);
    final headerBytes = header.buffer.asUint8List();
    
    // Combine header and message
    final result = Uint8List(headerBytes.length + bytes.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, bytes);
    
    return result;
  }

  // Create a handshake message
  factory SyncProtocolMessage.handshake(String deviceId, String deviceName, String version) {
    return SyncProtocolMessage(
      type: MessageType.handshake,
      payload: {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'version': version,
      },
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // Create an authentication message
  factory SyncProtocolMessage.authenticate(String pin) {
    return SyncProtocolMessage(
      type: MessageType.authenticate,
      payload: {
        'pin': pin,
      },
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // Create a data message
  factory SyncProtocolMessage.data(String encryptedData) {
    return SyncProtocolMessage(
      type: MessageType.data,
      payload: {
        'data': encryptedData,
      },
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // Create an acknowledgment message
  factory SyncProtocolMessage.ack(String originalMessageId, bool success, String? errorMessage) {
    return SyncProtocolMessage(
      type: MessageType.ack,
      payload: {
        'originalMessageId': originalMessageId,
        'success': success,
        'errorMessage': errorMessage,
      },
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // Create a disconnect message
  factory SyncProtocolMessage.disconnect(String reason) {
    return SyncProtocolMessage(
      type: MessageType.disconnect,
      payload: {
        'reason': reason,
      },
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}

/// Types of messages in the sync protocol
enum MessageType {
  handshake,     // Initial connection handshake
  authenticate,  // Authentication with PIN
  data,          // Encrypted data transfer
  ack,           // Acknowledgment of received message
  disconnect,    // Graceful disconnection
}
