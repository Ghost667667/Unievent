import 'dart:convert';
import 'dart:math';

/// Encodes and validates the payload stored in a QR ticket.
///
/// Payload format: `UNIEVENT|<eventId>|<registrationId>|<code>`.
/// The random code is what the server checks; the IDs let the scanner work
/// offline by matching against its locally cached registration list.
class TicketCodec {
  TicketCodec._();

  static const String prefix = 'UNIEVENT';
  static const int codeLength = 16;
  static const String _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I

  static final Random _rng = Random.secure();

  /// Generates a random, unguessable ticket code.
  static String generateCode() {
    return List.generate(
      codeLength,
      (_) => _alphabet[_rng.nextInt(_alphabet.length)],
    ).join();
  }

  static String encode({
    required String eventId,
    required String registrationId,
    required String code,
  }) =>
      '$prefix|$eventId|$registrationId|$code';

  /// Returns null if the payload is not a UniEvent ticket.
  static TicketPayload? decode(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length != 4 || parts[0] != prefix) return null;
    if (parts.any((p) => p.isEmpty)) return null;
    if (parts[3].length != codeLength) return null;
    return TicketPayload(
      eventId: parts[1],
      registrationId: parts[2],
      code: parts[3],
    );
  }

  /// Short, human-readable ticket number shown under the QR (e.g. `#A7K2-Q9`).
  static String shortNumber(String code) {
    if (code.length < 6) return '#$code';
    return '#${code.substring(0, 4)}-${code.substring(4, 6)}';
  }

  /// Base64 of the payload, used for the Google Calendar description link.
  static String toBase64(String payload) => base64Url.encode(utf8.encode(payload));
}

class TicketPayload {
  const TicketPayload({
    required this.eventId,
    required this.registrationId,
    required this.code,
  });

  final String eventId;
  final String registrationId;
  final String code;
}
