// Two-line calculator display, a CustomPainter port of the dozenal calculator's
// TwoLineDisplay adapted to base-24 glyphs and this tool's token set:
//   - upper line: the editable expression (left-aligned, with a cursor),
//   - lower line: the result (right-aligned) with an overline over the period.
//
// Display states (as in the dozenal calculator):
//   A) exact, finite          — no marker,
//   B) f64 fallback           — leading "≈",
//   C) period > maxPeriod     — raised-dot cluster at overline height,
//   + width-truncation        — trailing baseline "…", period clamped.
//
// Digits render as bidozenal glyphs or as conventional 0-9/A-N characters
// (the `glyphMode` toggle).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'digits.dart';
import 'evaluator.dart';
import 'glyphs.dart';
import 'result.dart';

class BidozenalDisplay extends StatelessWidget {
  const BidozenalDisplay({
    super.key,
    required this.input,
    required this.cursorPos,
    required this.result,
    required this.glyphMode,
    required this.memoryActive,
    required this.angleModeLabel,
  });

  final List<Tok> input;
  final int cursorPos;

  /// null → incomplete expression, the result line stays blank.
  final BidozResult? result;
  final bool glyphMode;
  final bool memoryActive;
  final String angleModeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF101010),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: CustomPaint(
        painter: _DisplayPainter(
          input: input,
          cursorPos: cursorPos,
          result: result,
          glyphMode: glyphMode,
          memoryActive: memoryActive,
          angleModeLabel: angleModeLabel,
          main: scheme.onSurface,
          muted: scheme.onSurfaceVariant,
          op: scheme.primary,
          accent: scheme.tertiary,
          error: scheme.error,
        ),
      ),
    );
  }
}

class _DisplayPainter extends CustomPainter {
  _DisplayPainter({
    required this.input,
    required this.cursorPos,
    required this.result,
    required this.glyphMode,
    required this.memoryActive,
    required this.angleModeLabel,
    required this.main,
    required this.muted,
    required this.op,
    required this.accent,
    required this.error,
  });

  final List<Tok> input;
  final int cursorPos;
  final BidozResult? result;
  final bool glyphMode;
  final bool memoryActive;
  final String angleModeLabel;
  final Color main, muted, op, accent, error;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = (size.height * 0.06).clamp(2.0, 10.0);
    final lineH = (size.height - gap) / 2;
    _paintInputLine(canvas, Rect.fromLTWH(0, 0, size.width, lineH));
    final resultRect = Rect.fromLTWH(0, lineH + gap, size.width, lineH);
    final r = result;
    if (r != null) {
      if (r.isError) {
        _paintError(canvas, resultRect, r.error!);
      } else {
        _paintResultLine(canvas, resultRect, r);
      }
    }
    _paintIndicators(canvas, size);
  }

  // ---- input line --------------------------------------------------------

  void _paintInputLine(Canvas canvas, Rect rect) {
    final laid = [for (final t in input) _layoutInputTok(t, rect.height)];
    var x = rect.left;
    for (var i = 0; i < laid.length; i++) {
      if (i == cursorPos) _drawCursor(canvas, x, rect.top, rect.height);
      laid[i].paint(canvas, Offset(x, rect.top), rect.height);
      x += laid[i].width;
    }
    if (cursorPos >= laid.length) _drawCursor(canvas, x, rect.top, rect.height);
  }

  // ---- result line -------------------------------------------------------

  void _paintResultLine(Canvas canvas, Rect rect, BidozResult result) {
    final laid = <_Laid>[];
    if (result.approx) laid.add(_textCell('≈', rect.height, muted));
    if (result.negative) laid.add(_textCell('−', rect.height, main));
    for (final d in result.intDigits) {
      laid.add(_digitCell(d, rect.height, main));
    }
    final hasFrac = result.preDigits.isNotEmpty || result.period.isNotEmpty;
    if (hasFrac) laid.add(_textCell('.', rect.height, main));
    for (final d in result.preDigits) {
      laid.add(_digitCell(d, rect.height, main));
    }
    var periodStart = result.period.isEmpty ? null : laid.length;
    var periodLen = result.period.length;
    for (final d in result.period) {
      laid.add(_digitCell(d, rect.height, accent));
    }

    var totalW = laid.fold<double>(0.0, (a, t) => a + t.width);

    // State-C raised dots (period capped) sit at overline height after the
    // period; width-truncation adds a baseline "…". Reserve their width.
    final dotsTp = result.periodCapped ? _ellipsis(rect.height) : null;
    var suffixW = dotsTp?.width ?? 0.0;

    var truncated = false;
    while (totalW + suffixW > rect.width && laid.length > 1) {
      totalW -= laid.removeLast().width;
      truncated = true;
      if (periodStart != null) {
        if (laid.length <= periodStart) {
          periodStart = null;
          periodLen = 0;
        } else if (laid.length < periodStart + periodLen) {
          periodLen = laid.length - periodStart;
        }
      }
    }
    final truncTp = truncated ? _ellipsis(rect.height) : null;
    if (truncTp != null) {
      suffixW += truncTp.width;
      while (totalW + suffixW > rect.width && laid.length > 1) {
        totalW -= laid.removeLast().width;
        if (periodStart != null && laid.length < periodStart + periodLen) {
          periodLen = laid.length < periodStart ? 0 : laid.length - periodStart;
          if (periodLen == 0) periodStart = null;
        }
      }
    }

    var x = rect.right - totalW - suffixW;
    final positions = <double>[];
    for (var i = 0; i < laid.length; i++) {
      positions.add(x);
      laid[i].paint(canvas, Offset(x, rect.top), rect.height);
      x += laid[i].width;
    }

    final overlineY = rect.top + _overlineYOffset(rect.height);
    if (periodStart != null && periodLen > 0) {
      final endIdx = periodStart + periodLen - 1;
      if (endIdx < positions.length) {
        canvas.drawLine(
          Offset(positions[periodStart] + 1.5, overlineY),
          Offset(positions[endIdx] + laid[endIdx].width - 1.5, overlineY),
          Paint()
            ..color = accent
            ..strokeWidth = 1.4,
        );
      }
    }

    // State-C dots (raised) then truncation "…" (baseline).
    if (dotsTp != null) {
      final r = rect.height * 0.025;
      final dx = r * 3.6;
      final cx = x + dotsTp.width / 2;
      final paint = Paint()..color = accent;
      for (var i = -1; i <= 1; i++) {
        canvas.drawCircle(Offset(cx + i * dx, overlineY), r, paint);
      }
      x += dotsTp.width;
    }
    if (truncTp != null) {
      truncTp.paint(canvas, Offset(x, rect.top + (rect.height - truncTp.height) / 2));
    }
  }

  void _paintError(Canvas canvas, Rect rect, String msg) {
    final tp = TextPainter(
      text: TextSpan(
        text: msg,
        style: TextStyle(
          color: error,
          fontSize: rect.height * 0.36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    tp.paint(canvas,
        Offset(rect.right - tp.width, rect.top + (rect.height - tp.height) / 2));
  }

  void _paintIndicators(Canvas canvas, Size size) {
    if (memoryActive) {
      _indicator('M', const Color(0xFFFFD700), const Offset(0, 0), canvas);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: angleModeLabel,
        style: const TextStyle(color: Color(0xFFB4B4B4), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width, 0));
  }

  void _indicator(String s, Color c, Offset at, Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  void _drawCursor(Canvas canvas, double x, double yTop, double h) {
    canvas.drawRect(
      Rect.fromLTWH(x, yTop + h * 0.18, 1.5, h * 0.64),
      Paint()..color = error,
    );
  }

  // ---- cell layout -------------------------------------------------------

  static const double _qRatio = 0.18;
  double _q(double lineH) => lineH * _qRatio;
  double _overlineYOffset(double lineH) => lineH / 2 - 2 * _q(lineH) - 4.0;

  _Laid _layoutInputTok(Tok t, double lineH) {
    return switch (t) {
      DigitTok d => _digitCell(d.value, lineH, main),
      DotTok() => _textCell('.', lineH, muted),
      OpTok o => _textCell(o.op.symbol, lineH, op),
      LParenTok() => _textCell('(', lineH, muted),
      RParenTok() => _textCell(')', lineH, muted),
      FuncTok f => _textCell(f.id.label, lineH, op),
      ConstTok c => _textCell(c.id.label, lineH, main),
      RatLitTok r => _textCell(r.label, lineH, accent),
    };
  }

  _Laid _digitCell(int value, double lineH, Color color) {
    if (!glyphMode) {
      return _textCell(bidozenalChar(value), lineH, color);
    }
    final q = _q(lineH);
    final cell = q * 2 + 6;
    return _Laid(cell, (canvas, offset, h) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      paintBidozenalGlyph(
        canvas,
        value,
        Offset(offset.dx + cell / 2, offset.dy + h / 2),
        q,
        paint,
      );
    });
  }

  _Laid _textCell(String text, double lineH, Color color) {
    final tp = _textPainter(text, lineH * 0.42, color);
    return _Laid(tp.width + 5, (canvas, offset, h) {
      tp.paint(canvas, Offset(offset.dx + 2.5, offset.dy + (h - tp.height) / 2));
    });
  }

  TextPainter _ellipsis(double lineH) => _textPainter('…', lineH * 0.42, muted);

  @override
  bool shouldRepaint(covariant _DisplayPainter old) =>
      !listEquals(old.input, input) ||
      old.cursorPos != cursorPos ||
      old.result != result ||
      old.glyphMode != glyphMode ||
      old.memoryActive != memoryActive ||
      old.angleModeLabel != angleModeLabel;
}

class _Laid {
  _Laid(this.width, this.paint);
  final double width;
  final void Function(Canvas, Offset, double lineH) paint;
}

TextPainter _textPainter(String text, double fontSize, Color color) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
