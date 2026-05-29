class TerminalProfile {
  const TerminalProfile({
    required this.id,
    required this.name,
    required this.fontFamily,
    required this.fontSize,
    required this.scrollbackLines,
  });

  final String id;
  final String name;
  final String fontFamily;
  final double fontSize;
  final int scrollbackLines;

  static const defaultProfile = TerminalProfile(
    id: 'serlink-dark',
    name: 'Serlink Dark',
    fontFamily: 'monospace',
    fontSize: 13,
    scrollbackLines: 10000,
  );
}
