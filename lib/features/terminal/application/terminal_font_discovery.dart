import 'dart:io';

import 'package:path/path.dart' as p;

class TerminalFontCandidate {
  const TerminalFontCandidate({
    required this.family,
    this.isNerdFont = false,
    this.isPowerline = false,
    this.isBuiltIn = false,
  });

  final String family;
  final bool isNerdFont;
  final bool isPowerline;
  final bool isBuiltIn;

  bool get hasEnhancedGlyphs => isNerdFont || isPowerline;

  bool get isSymbolOnly {
    final normalized = normalizeTerminalFontFamily(family);
    return normalized == 'symbolsnerdfont' ||
        normalized == 'symbolsnerdfontmono';
  }

  bool get isTerminalOptimized {
    final normalized = normalizeTerminalFontFamily(family);
    return normalized == defaultTerminalFontFamily ||
        normalized.contains('mono') ||
        normalized.contains('code') ||
        normalized.contains('hack') ||
        normalized.contains('meslolgs') ||
        normalized.contains('iosevkaterm') ||
        normalized.contains('sourcecodepro') ||
        normalized.contains('saucecodepro');
  }

  String get label {
    if (isNerdFont) {
      return '$family  ·  Nerd Font';
    }
    if (isPowerline) {
      return '$family  ·  Powerline';
    }
    if (isBuiltIn) {
      return '$family  ·  System';
    }
    return family;
  }
}

class TerminalFontCatalog {
  const TerminalFontCatalog({required this.fonts});

  factory TerminalFontCatalog.fallback() {
    return const TerminalFontCatalog(fonts: _fallbackFontCandidates);
  }

  final List<TerminalFontCandidate> fonts;

  bool get hasNerdFont => fonts.any((font) => font.isNerdFont);

  TerminalFontCandidate get preferredFont {
    for (final font in fonts) {
      if (font.isNerdFont && !font.isSymbolOnly && font.isTerminalOptimized) {
        return font;
      }
    }
    for (final font in fonts) {
      if (font.isPowerline && !font.isSymbolOnly && font.isTerminalOptimized) {
        return font;
      }
    }
    for (final font in fonts) {
      if (font.isNerdFont && !font.isSymbolOnly) {
        return font;
      }
    }
    for (final font in fonts) {
      if (font.isPowerline && !font.isSymbolOnly) {
        return font;
      }
    }
    return fonts.firstWhere(
      (font) => font.family == defaultTerminalFontFamily,
      orElse: () => _fallbackFontCandidates.first,
    );
  }

  String get preferredFontFamily => preferredFont.family;

  bool containsFamily(String family) {
    final normalized = normalizeTerminalFontFamily(family);
    return fonts.any(
      (font) => normalizeTerminalFontFamily(font.family) == normalized,
    );
  }

  List<TerminalFontCandidate> withCurrentFamily(String family) {
    final trimmed = family.trim();
    if (trimmed.isEmpty || containsFamily(trimmed)) {
      return fonts;
    }
    return [TerminalFontCandidate(family: trimmed), ...fonts];
  }
}

class TerminalFontDiscovery {
  const TerminalFontDiscovery({this.fontDirectories});

  final List<String>? fontDirectories;

  static TerminalFontCatalog? _cachedCatalog;

  Future<TerminalFontCatalog> discover() async {
    if (fontDirectories == null && _cachedCatalog != null) {
      return _cachedCatalog!;
    }
    final fileNames = _fontFileNames(fontDirectories ?? _defaultFontDirs());
    final detected = <TerminalFontCandidate>[];

    for (final known in _knownTerminalFonts) {
      if (_matchesKnownFont(fileNames, known)) {
        detected.add(known.candidate);
      }
    }

    for (final fileName in fileNames) {
      final family = _deriveNerdFontFamily(fileName);
      if (family != null) {
        detected.add(TerminalFontCandidate(family: family, isNerdFont: true));
      }
    }

    final catalog = TerminalFontCatalog(
      fonts: _dedupeFonts([...detected, ..._fallbackFontCandidates]),
    );
    if (fontDirectories == null) {
      _cachedCatalog = catalog;
    }
    return catalog;
  }
}

const defaultTerminalFontFamily = 'monospace';

const _fallbackFontCandidates = [
  TerminalFontCandidate(family: defaultTerminalFontFamily, isBuiltIn: true),
  TerminalFontCandidate(family: 'SF Mono'),
  TerminalFontCandidate(family: 'Menlo'),
  TerminalFontCandidate(family: 'Monaco'),
  TerminalFontCandidate(family: 'Consolas'),
  TerminalFontCandidate(family: 'JetBrains Mono'),
  TerminalFontCandidate(family: 'Cascadia Mono'),
  TerminalFontCandidate(family: 'Cascadia Code'),
  TerminalFontCandidate(family: 'Fira Code'),
  TerminalFontCandidate(family: 'Hack'),
  TerminalFontCandidate(family: 'Source Code Pro'),
  TerminalFontCandidate(family: 'DejaVu Sans Mono'),
  TerminalFontCandidate(family: 'Liberation Mono'),
  TerminalFontCandidate(family: 'Courier New'),
];

const _knownTerminalFonts = [
  _KnownTerminalFont('MesloLGS NF', isNerdFont: true),
  _KnownTerminalFont('JetBrainsMono Nerd Font', isNerdFont: true),
  _KnownTerminalFont('JetBrainsMono Nerd Font Mono', isNerdFont: true),
  _KnownTerminalFont('CaskaydiaCove Nerd Font', isNerdFont: true),
  _KnownTerminalFont('CaskaydiaCove Nerd Font Mono', isNerdFont: true),
  _KnownTerminalFont('CascadiaCode Nerd Font', isNerdFont: true),
  _KnownTerminalFont('CascadiaMono Nerd Font', isNerdFont: true),
  _KnownTerminalFont('FiraCode Nerd Font', isNerdFont: true),
  _KnownTerminalFont('FiraCode Nerd Font Mono', isNerdFont: true),
  _KnownTerminalFont('Hack Nerd Font', isNerdFont: true),
  _KnownTerminalFont('Hack Nerd Font Mono', isNerdFont: true),
  _KnownTerminalFont('Iosevka Nerd Font', isNerdFont: true),
  _KnownTerminalFont('IosevkaTerm Nerd Font', isNerdFont: true),
  _KnownTerminalFont('SauceCodePro Nerd Font', isNerdFont: true),
  _KnownTerminalFont('UbuntuMono Nerd Font', isNerdFont: true),
  _KnownTerminalFont('Symbols Nerd Font Mono', isNerdFont: true),
  _KnownTerminalFont('Menlo for Powerline', isPowerline: true),
  _KnownTerminalFont('DejaVu Sans Mono for Powerline', isPowerline: true),
  _KnownTerminalFont('Inconsolata for Powerline', isPowerline: true),
  _KnownTerminalFont('Source Code Pro for Powerline', isPowerline: true),
];

List<String> terminalFontFallbackFamilies(String primaryFamily) {
  final seen = {normalizeTerminalFontFamily(primaryFamily)};
  final candidates = [
    'Symbols Nerd Font Mono',
    'Symbols Nerd Font',
    'MesloLGS NF',
    'JetBrainsMono Nerd Font',
    'JetBrainsMono Nerd Font Mono',
    'CaskaydiaCove Nerd Font',
    'CaskaydiaCove Nerd Font Mono',
    'CascadiaCode Nerd Font',
    'CascadiaMono Nerd Font',
    'FiraCode Nerd Font',
    'Hack Nerd Font',
    'Iosevka Nerd Font',
    'SauceCodePro Nerd Font',
    'Menlo for Powerline',
    'DejaVu Sans Mono for Powerline',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'Noto Sans Mono CJK SC',
    'Noto Sans Mono CJK TC',
    'Noto Sans Mono CJK KR',
    'Noto Sans Mono CJK JP',
    'Noto Sans Mono CJK HK',
    'Noto Color Emoji',
    'Menlo',
    'Monaco',
    'Consolas',
    'Liberation Mono',
    'Courier New',
    defaultTerminalFontFamily,
    'sans-serif',
  ];
  return [
    for (final family in candidates)
      if (seen.add(normalizeTerminalFontFamily(family))) family,
  ];
}

String normalizeTerminalFontFamily(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

List<TerminalFontCandidate> _dedupeFonts(List<TerminalFontCandidate> fonts) {
  final seen = <String>{};
  final result = <TerminalFontCandidate>[];
  for (final font in fonts) {
    final normalized = normalizeTerminalFontFamily(font.family);
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    result.add(font);
  }
  return List.unmodifiable(result);
}

Set<String> _fontFileNames(List<String> directories) {
  final result = <String>{};
  for (final directoryPath in directories) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      continue;
    }
    try {
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }
        final extension = p.extension(entity.path).toLowerCase();
        if (const {'.ttf', '.otf', '.ttc', '.dfont'}.contains(extension)) {
          result.add(p.basenameWithoutExtension(entity.path));
        }
      }
    } on FileSystemException {
      // Font directories are best effort; unreadable folders should not block
      // terminal startup or settings.
    }
  }
  return result;
}

bool _matchesKnownFont(Set<String> fileNames, _KnownTerminalFont font) {
  final hints = {font.family}.map(normalizeTerminalFontFamily);
  for (final fileName in fileNames) {
    final normalizedFileName = normalizeTerminalFontFamily(fileName);
    for (final hint in hints) {
      if (normalizedFileName.contains(hint)) {
        return true;
      }
    }
  }
  return false;
}

String? _deriveNerdFontFamily(String fileName) {
  final normalized = normalizeTerminalFontFamily(fileName);
  if (!normalized.contains('nerdfont')) {
    return null;
  }
  final marker = normalized.contains('nerdfontmono')
      ? 'nerdfontmono'
      : 'nerdfont';
  final name = normalized.split(marker).first;
  if (name.isEmpty || name == 'symbols') {
    return marker == 'nerdfontmono'
        ? 'Symbols Nerd Font Mono'
        : 'Symbols Nerd Font';
  }
  final suffix = marker == 'nerdfontmono' ? ' Nerd Font Mono' : ' Nerd Font';
  return '${_restoreKnownFontPrefix(name)}$suffix';
}

String _restoreKnownFontPrefix(String normalizedPrefix) {
  return switch (normalizedPrefix) {
    'jetbrainsmono' => 'JetBrainsMono',
    'caskaydiacove' => 'CaskaydiaCove',
    'cascadiacode' => 'CascadiaCode',
    'cascadiamono' => 'CascadiaMono',
    'firacode' => 'FiraCode',
    'sourcecodepro' => 'SourceCodePro',
    'saucecodepro' => 'SauceCodePro',
    'ubuntumono' => 'UbuntuMono',
    'dejavusansmono' => 'DejaVuSansMono',
    'notosansmono' => 'NotoSansMono',
    _ => normalizedPrefix,
  };
}

List<String> _defaultFontDirs() {
  final home = Platform.environment['HOME'];
  if (Platform.isMacOS) {
    return [
      if (home != null) p.join(home, 'Library', 'Fonts'),
      '/Library/Fonts',
      '/System/Library/Fonts',
      '/System/Library/Fonts/Supplemental',
    ];
  }
  if (Platform.isWindows) {
    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final localAppData = Platform.environment['LOCALAPPDATA'];
    return [
      p.join(windir, 'Fonts'),
      if (localAppData != null)
        p.join(localAppData, 'Microsoft', 'Windows', 'Fonts'),
    ];
  }
  return [
    if (home != null) p.join(home, '.local', 'share', 'fonts'),
    if (home != null) p.join(home, '.fonts'),
    '/usr/local/share/fonts',
    '/usr/share/fonts',
  ];
}

class _KnownTerminalFont {
  const _KnownTerminalFont(
    this.family, {
    this.isNerdFont = false,
    this.isPowerline = false,
  });

  final String family;
  final bool isNerdFont;
  final bool isPowerline;

  TerminalFontCandidate get candidate {
    return TerminalFontCandidate(
      family: family,
      isNerdFont: isNerdFont,
      isPowerline: isPowerline,
    );
  }
}
