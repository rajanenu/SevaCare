/// Strips a redundant leading "Dr"/"Dr." from a doctor's stored name, so
/// screens that prepend their own "Dr. " prefix don't end up showing
/// "Dr. Dr. Ananya Krishnan" when the name was already entered with the
/// prefix.
String stripDoctorPrefix(String name) {
  final trimmed = name.trim();
  final match = RegExp(r'^dr\.?\s+', caseSensitive: false).firstMatch(trimmed);
  if (match == null) return trimmed;
  return trimmed.substring(match.end).trim();
}
