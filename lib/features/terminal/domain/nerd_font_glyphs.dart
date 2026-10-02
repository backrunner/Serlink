// Private-use glyph coverage from the bundled Nerd Fonts v3.4.0 Mono face.
// Keep this table aligned with assets/fonts/jetbrains_mono_nerd when upgrading.
const _nerdFontIconRanges = <(int, int)>[
  (0xe000, 0xe00a),
  (0xe0a0, 0xe0a3),
  (0xe0b0, 0xe0c8),
  (0xe0ca, 0xe0ca),
  (0xe0cc, 0xe0d2),
  (0xe0d4, 0xe0d4),
  (0xe0d6, 0xe0d7),
  (0xe200, 0xe2a9),
  (0xe300, 0xe3e3),
  (0xe5fa, 0xe6b8),
  (0xe700, 0xe8ef),
  (0xea60, 0xea88),
  (0xea8a, 0xea8c),
  (0xea8f, 0xeac7),
  (0xeac9, 0xeac9),
  (0xeacc, 0xeb09),
  (0xeb0b, 0xeb4e),
  (0xeb50, 0xec1e),
  (0xed00, 0xefce),
  (0xf000, 0xf381),
  (0xf400, 0xf533),
  (0xf0001, 0xf1af0),
];

bool isNerdFontIconCodePoint(int codePoint) {
  if (codePoint < 0xe000) return false;
  var low = 0;
  var high = _nerdFontIconRanges.length - 1;
  while (low <= high) {
    final middle = (low + high) ~/ 2;
    final (start, end) = _nerdFontIconRanges[middle];
    if (codePoint < start) {
      high = middle - 1;
    } else if (codePoint > end) {
      low = middle + 1;
    } else {
      return true;
    }
  }
  return false;
}
