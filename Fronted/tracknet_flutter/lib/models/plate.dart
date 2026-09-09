/// OCR candidates are review suggestions only; never accepted automatically.
class PlateRecognition {
  static final format = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$');
  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  static bool valid(String raw) => format.hasMatch(normalize(raw));
  static const _digit = {'O': '0', 'I': '1', 'B': '8', 'S': '5', 'Z': '2'};
  static const _letter = {'0': 'O', '1': 'I', '8': 'B', '5': 'S', '2': 'Z'};
  static Set<String> reviewCandidates(String raw) {
    final input = normalize(raw);
    final result = <String>{};
    for (final district in [1, 2]) {
      for (final series in [1, 2]) {
        if (input.length != 2 + district + series + 4) continue;
        final out = StringBuffer();
        for (var i = 0; i < input.length; i++) {
          final numeric =
              (i >= 2 && i < 2 + district) || i >= 2 + district + series;
          out.write((numeric ? _digit : _letter)[input[i]] ?? input[i]);
        }
        if (format.hasMatch(out.toString())) result.add(out.toString());
      }
    }
    return result;
  }
}
