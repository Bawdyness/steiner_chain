import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Theorie-Block-Modell. Die LaTeX-Quellen kommen von Pandoc-gfm und enthalten
/// Inline-Math (`$x$`) sowie Display-Math (`$$...$$` als eigener Absatz).
sealed class TheoryBlock {}

class HeaderBlock extends TheoryBlock {
  HeaderBlock(this.level, this.segments);
  final int level;
  final List<InlineSegment> segments;
}

class ParagraphBlock extends TheoryBlock {
  ParagraphBlock(this.segments);
  final List<InlineSegment> segments;
}

class ListBlock extends TheoryBlock {
  ListBlock(this.items);
  final List<List<InlineSegment>> items;
}

class DisplayMathBlock extends TheoryBlock {
  DisplayMathBlock(this.latex);
  final String latex;
}

sealed class InlineSegment {}

class TextSegment extends InlineSegment {
  TextSegment(this.text);
  final String text;
}

class MathSegment extends InlineSegment {
  MathSegment(this.latex);
  final String latex;
}

List<TheoryBlock> parseTheory(String source) {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(source.split('\n'));

  final blocks = <TheoryBlock>[];
  for (final node in nodes) {
    if (node is! md.Element) continue;
    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
        final level = int.parse(node.tag.substring(1));
        blocks.add(HeaderBlock(level, _splitInline(node.textContent)));
      case 'p':
        final text = node.textContent.trim();
        if (text.startsWith(r'$$') && text.endsWith(r'$$') && text.length >= 4) {
          blocks.add(DisplayMathBlock(text.substring(2, text.length - 2).trim()));
        } else {
          blocks.add(ParagraphBlock(_splitInline(node.textContent)));
        }
      case 'ul':
        final items = <List<InlineSegment>>[];
        for (final child in node.children ?? <md.Node>[]) {
          if (child is md.Element && child.tag == 'li') {
            items.add(_splitInline(child.textContent));
          }
        }
        blocks.add(ListBlock(items));
    }
  }
  return blocks;
}

/// Trennt Fließtext bei `$...$`-Inline-Math in abwechselnde Text- und
/// Math-Segmente. Whitespace wird auf einfache Spaces normalisiert.
List<InlineSegment> _splitInline(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final out = <InlineSegment>[];
  final regex = RegExp(r'\$([^$]+)\$');
  var pos = 0;
  for (final m in regex.allMatches(cleaned)) {
    if (m.start > pos) {
      out.add(TextSegment(cleaned.substring(pos, m.start)));
    }
    out.add(MathSegment(m.group(1)!));
    pos = m.end;
  }
  if (pos < cleaned.length) {
    out.add(TextSegment(cleaned.substring(pos)));
  }
  return out;
}

class TheoryView extends StatefulWidget {
  const TheoryView({super.key, required this.assetPath});
  final String assetPath;

  @override
  State<TheoryView> createState() => _TheoryViewState();
}

class _TheoryViewState extends State<TheoryView> {
  late Future<List<TheoryBlock>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(TheoryView old) {
    super.didUpdateWidget(old);
    if (old.assetPath != widget.assetPath) {
      _future = _load();
    }
  }

  Future<List<TheoryBlock>> _load() async {
    final content = await rootBundle.loadString(widget.assetPath);
    return parseTheory(content);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TheoryBlock>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Theorie konnte nicht geladen werden:\n${snap.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: snap.data!.length,
          itemBuilder: (context, i) => _buildBlock(context, snap.data![i]),
        );
      },
    );
  }

  Widget _buildBlock(BuildContext context, TheoryBlock block) {
    final theme = Theme.of(context);
    return switch (block) {
      HeaderBlock h => Padding(
          padding: EdgeInsets.only(top: h.level == 1 ? 18 : 14, bottom: 6),
          child: _buildInline(
            h.segments,
            baseStyle: (h.level == 1
                    ? theme.textTheme.headlineSmall
                    : h.level == 2
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.titleMedium)
                ?.copyWith(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ParagraphBlock p => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildInline(p.segments,
              baseStyle: const TextStyle(fontSize: 15, height: 1.45)),
        ),
      ListBlock l => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in l.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 8, left: 6),
                        child: Text('•', style: TextStyle(fontSize: 15)),
                      ),
                      Expanded(
                        child: _buildInline(item,
                            baseStyle: const TextStyle(fontSize: 15, height: 1.45)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      DisplayMathBlock m => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              m.latex,
              textStyle: const TextStyle(fontSize: 18),
              onErrorFallback: (err) => Text(
                'LaTeX-Fehler: ${err.message}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
    };
  }

  Widget _buildInline(List<InlineSegment> segments, {TextStyle? baseStyle}) {
    final mathStyle = baseStyle ?? const TextStyle(fontSize: 15);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final seg in segments)
            if (seg is TextSegment)
              TextSpan(text: seg.text)
            else if (seg is MathSegment)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Math.tex(
                  seg.latex,
                  textStyle: mathStyle,
                  onErrorFallback: (err) => Text(
                    seg.latex,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
