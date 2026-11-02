import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/event.dart';

/// Google Maps: opens turn-by-turn directions to the venue.
class MapsService {
  /// APU campus default pin (Jalan Teknologi 5, Taman Teknologi Malaysia).
  static const double apuLat = 2.9218;
  static const double apuLng = 101.6565;

  Future<bool> openDirections(Event event) {
    final Uri uri;
    if (event.hasLocation) {
      uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${event.latitude},${event.longitude}',
        'travelmode': 'walking',
      });
    } else {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${event.venue}, Asia Pacific University, Kuala Lumpur',
      });
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Google Calendar: opens a pre-filled "add event" page. This uses the public
/// calendar render endpoint so it works with no OAuth client configured. The
/// README describes swapping in the Calendar API if write access is wanted.
class CalendarService {
  Future<bool> addToGoogleCalendar(Event event, {String? ticketNumber}) {
    String fmt(DateTime d) {
      final u = d.toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
    }

    final details = StringBuffer(event.description);
    if (ticketNumber != null) {
      details.write(
        '\n\nUniEvent ticket $ticketNumber — show the QR code in '
        'My Events at check-in.',
      );
    }
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates': '${fmt(event.startTime)}/${fmt(event.endTime)}',
      'details': details.toString(),
      'location': event.venue,
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Forecast for the event day from Open-Meteo (free, no API key).
class WeatherForecast {
  const WeatherForecast({
    required this.maxTempC,
    required this.minTempC,
    required this.rainChance,
    required this.weatherCode,
  });

  final double maxTempC;
  final double minTempC;
  final int rainChance;
  final int weatherCode;

  String get summary {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode <= 48) return 'Foggy';
    if (weatherCode <= 67) return 'Rain';
    if (weatherCode <= 77) return 'Snow';
    if (weatherCode <= 82) return 'Rain showers';
    return 'Thunderstorm';
  }

  bool get rainLikely => rainChance >= 50 || weatherCode >= 61;
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Returns null when the date is outside Open-Meteo's 16-day window or the
  /// request fails; callers simply hide the weather card.
  Future<WeatherForecast?> forecastFor(Event event) async {
    final lat = event.latitude ?? MapsService.apuLat;
    final lng = event.longitude ?? MapsService.apuLng;
    final day = event.startTime;
    final daysAhead = day.difference(DateTime.now()).inDays;
    if (daysAhead < 0 || daysAhead > 15) return null;

    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'Asia/Kuala_Lumpur',
      'start_date': date,
      'end_date': date,
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;
      return WeatherForecast(
        maxTempC: (daily['temperature_2m_max'][0] as num).toDouble(),
        minTempC: (daily['temperature_2m_min'][0] as num).toDouble(),
        rainChance: ((daily['precipitation_probability_max'][0] ?? 0) as num).toInt(),
        weatherCode: (daily['weather_code'][0] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Sandbox payment. No real money moves — this simulates a card/e-wallet
/// checkout and returns a reference. Replace with a real provider SDK
/// (e.g. Stripe, Billplz) behind the same interface to go live.
class PaymentResult {
  const PaymentResult({required this.success, this.reference, this.error});
  final bool success;
  final String? reference;
  final String? error;
}

class SandboxPaymentService {
  static const String label = 'SANDBOX — no real payment is taken';
  static const List<String> methods = ['Sandbox card', 'Sandbox e-wallet'];

  /// Card number ending in `0000` is treated as a declined card so the
  /// failure path can be demonstrated.
  Future<PaymentResult> pay({
    required double amountRm,
    required String method,
    String? cardLastDigits,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (amountRm <= 0) {
      return const PaymentResult(success: false, error: 'Nothing to pay.');
    }
    if (cardLastDigits == '0000') {
      return const PaymentResult(
        success: false,
        error: 'Card declined by the sandbox (test number ending 0000).',
      );
    }
    final rnd = Random();
    final ref = 'SBX-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}'
        '-${rnd.nextInt(9999).toString().padLeft(4, '0')}';
    return PaymentResult(success: true, reference: ref);
  }
}
