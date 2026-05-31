import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import 'terminal_font_discovery.dart';

enum SerlinkTerminalThemeId { serlinkDark, serlinkLight, highContrast }

class TerminalDisplaySettings {
  const TerminalDisplaySettings({
    this.themeId = SerlinkTerminalThemeId.serlinkDark,
    this.fontFamily = defaultTerminalFontFamily,
    this.fontSize = 13,
    this.lineHeight = 1.2,
    this.scrollbackLines = 10000,
  });

  final SerlinkTerminalThemeId themeId;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final int scrollbackLines;

  Map<String, Object?> toJson() {
    return {
      'themeId': themeId.name,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'scrollbackLines': scrollbackLines,
    };
  }

  factory TerminalDisplaySettings.fromJson(Map<String, Object?> json) {
    return TerminalDisplaySettings(
      themeId: _themeIdFromJson(json['themeId']),
      fontFamily: switch (json['fontFamily']) {
        final String value when value.trim().isNotEmpty => value,
        _ => defaultTerminalFontFamily,
      },
      fontSize: _doubleFromJson(json['fontSize'], fallback: 13),
      lineHeight: _doubleFromJson(json['lineHeight'], fallback: 1.2),
      scrollbackLines: _intFromJson(json['scrollbackLines'], fallback: 10000),
    );
  }

  TerminalDisplaySettings copyWith({
    SerlinkTerminalThemeId? themeId,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    int? scrollbackLines,
  }) {
    return TerminalDisplaySettings(
      themeId: themeId ?? this.themeId,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TerminalDisplaySettings &&
        other.themeId == themeId &&
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.scrollbackLines == scrollbackLines;
  }

  @override
  int get hashCode =>
      Object.hash(themeId, fontFamily, fontSize, lineHeight, scrollbackLines);

  TerminalStyle get textStyle {
    return _SerlinkTerminalStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: terminalFontFallbackFamilies(fontFamily),
      fontSize: fontSize,
      height: lineHeight,
      glyphOverhangReserve: _glyphOverhangReserveFor(fontFamily, fontSize),
    );
  }

  TerminalTheme get terminalTheme {
    return switch (themeId) {
      SerlinkTerminalThemeId.serlinkDark => _serlinkDarkTheme,
      SerlinkTerminalThemeId.serlinkLight => _serlinkLightTheme,
      SerlinkTerminalThemeId.highContrast => _highContrastTheme,
    };
  }
}

class _SerlinkTerminalStyle extends TerminalStyle {
  const _SerlinkTerminalStyle({
    required super.fontFamily,
    required super.fontFamilyFallback,
    required super.fontSize,
    required super.height,
    required this.glyphOverhangReserve,
  });

  final double glyphOverhangReserve;

  @override
  TextStyle toTextStyle({
    Color? color,
    Color? backgroundColor,
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) {
    return super
        .toTextStyle(
          color: color,
          backgroundColor: backgroundColor,
          bold: bold,
          italic: italic,
          underline: underline,
        )
        .copyWith(letterSpacing: glyphOverhangReserve);
  }
}

double _glyphOverhangReserveFor(String fontFamily, double fontSize) {
  final enhancedGlyphFont =
      terminalFontFamilyHasEnhancedGlyphs(fontFamily) ||
      normalizeTerminalFontFamily(fontFamily) == defaultTerminalFontFamily;
  if (!enhancedGlyphFont) {
    return 0;
  }
  // Some Nerd Font and Powerline glyphs paint a hair outside their measured
  // advance. xterm paints terminal cells independently, so a tiny extra advance
  // keeps icons from being shaved by the next cell without making all columns
  // look over-wide.
  return (fontSize * 0.06).clamp(0.6, 1.0).toDouble();
}

SerlinkTerminalThemeId _themeIdFromJson(Object? value) {
  if (value is! String) {
    return SerlinkTerminalThemeId.serlinkDark;
  }
  for (final themeId in SerlinkTerminalThemeId.values) {
    if (themeId.name == value) {
      return themeId;
    }
  }
  return SerlinkTerminalThemeId.serlinkDark;
}

double _doubleFromJson(Object? value, {required double fallback}) {
  return switch (value) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v) ?? fallback,
    _ => fallback,
  };
}

int _intFromJson(Object? value, {required int fallback}) {
  return switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };
}

abstract interface class TerminalDisplaySettingsRepository {
  Future<TerminalDisplaySettings?> read();
  Future<void> save(TerminalDisplaySettings settings);
  Future<void> delete();
}

abstract interface class TerminalHostDisplaySettingsRepository {
  Future<TerminalDisplaySettings?> readForHost(HostId hostId);
  Future<void> saveForHost(HostId hostId, TerminalDisplaySettings settings);
  Future<void> deleteForHost(HostId hostId);
}

class EncryptedTerminalDisplaySettingsRepository
    implements
        TerminalDisplaySettingsRepository,
        TerminalHostDisplaySettingsRepository {
  EncryptedTerminalDisplaySettingsRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedTerminalDisplaySettingsRepository._(this._vault, this._records);

  static const recordType = 'terminal_settings';
  static const hostProfileRecordType = 'terminal_profile';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<TerminalDisplaySettings?> read() async {
    final envelope = await _records.read(_terminalDisplaySettingsRecordId);
    if (envelope == null) {
      return null;
    }
    return _decode(envelope);
  }

  @override
  Future<void> save(TerminalDisplaySettings settings) async {
    final envelope = await _vault.encryptRecord(
      id: _terminalDisplaySettingsRecordId,
      type: recordType,
      plaintext: utf8.encode(jsonEncode(settings.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<void> delete() async {
    await _records.delete(_terminalDisplaySettingsRecordId);
  }

  @override
  Future<TerminalDisplaySettings?> readForHost(HostId hostId) async {
    final envelope = await _records.read(_terminalHostProfileRecordId(hostId));
    if (envelope == null) {
      return null;
    }
    return _decode(envelope);
  }

  @override
  Future<void> saveForHost(
    HostId hostId,
    TerminalDisplaySettings settings,
  ) async {
    final envelope = await _vault.encryptRecord(
      id: _terminalHostProfileRecordId(hostId),
      type: hostProfileRecordType,
      plaintext: utf8.encode(jsonEncode(settings.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<void> deleteForHost(HostId hostId) async {
    await _records.delete(_terminalHostProfileRecordId(hostId));
  }

  Future<TerminalDisplaySettings> _decode(VaultRecordEnvelope envelope) async {
    final plaintext = await _vault.decryptRecord(envelope);
    return TerminalDisplaySettings.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }
}

final _terminalDisplaySettingsRecordId = VaultRecordId(
  'terminal:display_settings',
);

VaultRecordId _terminalHostProfileRecordId(HostId hostId) {
  return VaultRecordId('terminal:profile:${hostId.value}');
}

extension SerlinkTerminalThemeLabel on SerlinkTerminalThemeId {
  String get label {
    return switch (this) {
      SerlinkTerminalThemeId.serlinkDark => 'Serlink Dark',
      SerlinkTerminalThemeId.serlinkLight => 'Serlink Light',
      SerlinkTerminalThemeId.highContrast => 'High Contrast',
    };
  }
}

const _serlinkDarkTheme = TerminalTheme(
  cursor: Color(0xFF2DD4BF),
  selection: Color(0x552DD4BF),
  foreground: Color(0xFFE6EDF3),
  background: Color(0xFF0E1116),
  black: Color(0xFF0E1116),
  red: Color(0xFFFF7B72),
  green: Color(0xFF7EE787),
  yellow: Color(0xFFFFD33D),
  blue: Color(0xFF58A6FF),
  magenta: Color(0xFFD2A8FF),
  cyan: Color(0xFF76E3EA),
  white: Color(0xFFE6EDF3),
  brightBlack: Color(0xFF6E7681),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFF56D364),
  brightYellow: Color(0xFFE3B341),
  brightBlue: Color(0xFF79C0FF),
  brightMagenta: Color(0xFFBC8CFF),
  brightCyan: Color(0xFF39C5CF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0x99FFD33D),
  searchHitBackgroundCurrent: Color(0xFF2DD4BF),
  searchHitForeground: Color(0xFF0E1116),
);

const _serlinkLightTheme = TerminalTheme(
  cursor: Color(0xFF0D9488),
  selection: Color(0x330D9488),
  foreground: Color(0xFF24292F),
  background: Color(0xFFFFFFFF),
  black: Color(0xFF24292F),
  red: Color(0xFFCF222E),
  green: Color(0xFF1A7F37),
  yellow: Color(0xFF9A6700),
  blue: Color(0xFF0969DA),
  magenta: Color(0xFF8250DF),
  cyan: Color(0xFF1B7C83),
  white: Color(0xFFFFFFFF),
  brightBlack: Color(0xFF57606A),
  brightRed: Color(0xFFA40E26),
  brightGreen: Color(0xFF116329),
  brightYellow: Color(0xFF7D4E00),
  brightBlue: Color(0xFF0550AE),
  brightMagenta: Color(0xFF6639BA),
  brightCyan: Color(0xFF3192AA),
  brightWhite: Color(0xFFF6F8FA),
  searchHitBackground: Color(0x99FFE17D),
  searchHitBackgroundCurrent: Color(0xFF0969DA),
  searchHitForeground: Color(0xFFFFFFFF),
);

const _highContrastTheme = TerminalTheme(
  cursor: Color(0xFFFFFFFF),
  selection: Color(0x88FFFFFF),
  foreground: Color(0xFFFFFFFF),
  background: Color(0xFF000000),
  black: Color(0xFF000000),
  red: Color(0xFFFF5F5F),
  green: Color(0xFF5FFF87),
  yellow: Color(0xFFFFFF5F),
  blue: Color(0xFF5FAFFF),
  magenta: Color(0xFFFF87FF),
  cyan: Color(0xFF5FFFFF),
  white: Color(0xFFFFFFFF),
  brightBlack: Color(0xFF808080),
  brightRed: Color(0xFFFF8787),
  brightGreen: Color(0xFF87FFAF),
  brightYellow: Color(0xFFFFFF87),
  brightBlue: Color(0xFF87C8FF),
  brightMagenta: Color(0xFFFFAFFF),
  brightCyan: Color(0xFF87FFFF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFFFFF00),
  searchHitBackgroundCurrent: Color(0xFFFF5F5F),
  searchHitForeground: Color(0xFF000000),
);
