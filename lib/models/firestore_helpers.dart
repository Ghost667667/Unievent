import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared conversion helpers for Firestore maps.
DateTime? tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

Timestamp? dateToTs(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

List<String> stringList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

double toDouble(dynamic v, [double fallback = 0]) =>
    (v as num?)?.toDouble() ?? fallback;

int toInt(dynamic v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;
