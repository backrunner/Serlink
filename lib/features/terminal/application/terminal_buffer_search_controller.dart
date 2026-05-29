import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class TerminalSearchResult {
  const TerminalSearchResult({
    required this.matchCount,
    required this.currentIndex,
  });

  const TerminalSearchResult.empty() : matchCount = 0, currentIndex = -1;

  final int matchCount;
  final int currentIndex;

  int get displayIndex => currentIndex == -1 ? 0 : currentIndex + 1;
}

class TerminalBufferSearchController {
  TerminalBufferSearchController({
    required this.terminal,
    required this.controller,
    this.highlightColor = const Color(0x6658A6FF),
  });

  final Terminal terminal;
  final TerminalController controller;
  final Color highlightColor;
  final List<TerminalHighlight> _highlights = [];
  final List<_SearchMatch> _matches = [];

  String _query = '';
  int _currentIndex = -1;

  TerminalSearchResult search(String query) {
    _clearHighlights(clearQuery: false);
    _query = query;

    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      _query = '';
      return const TerminalSearchResult.empty();
    }

    final queryLower = normalizedQuery.toLowerCase();
    final buffer = terminal.buffer;
    for (var y = 0; y < buffer.height; y += 1) {
      final lineText = buffer.lines[y].getText();
      final lineLower = lineText.toLowerCase();
      var start = 0;
      while (start < lineLower.length) {
        final index = lineLower.indexOf(queryLower, start);
        if (index == -1) {
          break;
        }
        final end = index + normalizedQuery.length;
        if (end <= buffer.viewWidth) {
          final highlight = controller.highlight(
            p1: buffer.createAnchor(index, y),
            p2: buffer.createAnchor(end, y),
            color: highlightColor,
          );
          _highlights.add(highlight);
          _matches.add(_SearchMatch(y: y, start: index, end: end));
        }
        start = index + normalizedQuery.length;
      }
    }

    _currentIndex = _matches.isEmpty ? -1 : 0;
    _selectCurrent();
    return _result;
  }

  TerminalSearchResult next() {
    if (_matches.isEmpty) {
      return _result;
    }
    _currentIndex = (_currentIndex + 1) % _matches.length;
    _selectCurrent();
    return _result;
  }

  TerminalSearchResult previous() {
    if (_matches.isEmpty) {
      return _result;
    }
    _currentIndex = (_currentIndex - 1) % _matches.length;
    if (_currentIndex < 0) {
      _currentIndex = _matches.length - 1;
    }
    _selectCurrent();
    return _result;
  }

  TerminalSearchResult refresh() {
    if (_query.isEmpty) {
      return const TerminalSearchResult.empty();
    }
    return search(_query);
  }

  void clear() {
    _clearHighlights(clearQuery: true);
  }

  TerminalSearchResult get _result {
    return TerminalSearchResult(
      matchCount: _matches.length,
      currentIndex: _currentIndex,
    );
  }

  void _selectCurrent() {
    if (_currentIndex == -1 || _currentIndex >= _matches.length) {
      controller.clearSelection();
      return;
    }
    final match = _matches[_currentIndex];
    final buffer = terminal.buffer;
    controller.setSelection(
      buffer.createAnchor(match.start, match.y),
      buffer.createAnchor(match.end, match.y),
      mode: SelectionMode.line,
    );
  }

  void _clearHighlights({required bool clearQuery}) {
    for (final highlight in _highlights) {
      highlight.dispose();
    }
    _highlights.clear();
    _matches.clear();
    _currentIndex = -1;
    controller.clearSelection();
    if (clearQuery) {
      _query = '';
    }
  }
}

class _SearchMatch {
  const _SearchMatch({required this.y, required this.start, required this.end});

  final int y;
  final int start;
  final int end;
}
