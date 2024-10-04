/// Parses a [rawDouble] `String` to a `double`.
///
/// The [rawDouble] might include a unit (`px`, `em`, `ex`, `pt`, or `rem`)
/// which is stripped off before parsing to a `double`.
///
/// If [tryParse] is true, it attempts to parse the string and returns `null` on failure.
/// Passing `null` for [rawDouble] will return `null`.
double? parseDouble(String? rawDouble, {bool tryParse = false}) {
  if (rawDouble == null) return null;

  // Use a more efficient approach to replace multiple units at once using a regular expression.
  rawDouble = rawDouble.replaceAll(RegExp(r'(px|em|ex|rem|pt)$'), '').trim();

  // Try parsing the string as a double, returning null or throwing on failure
  return tryParse ? double.tryParse(rawDouble) : double.parse(rawDouble);
}
