import 'package:flutter/material.dart';
import '../widgets/drag_handle.dart';
import '../widgets/settings_screen.dart';
import '../widgets/tool_nav.dart';

/// Gemeinsames Skelett für alle Tools: AppBar, Drawer-Slot, Wide/Narrow-
/// Layout, Drag-Handles für Panel-Breiten, optionales Referenz-Panel
/// (Theorie / Glossar / Symbole / Beispiele etc.).
///
/// Ein Tool liefert nur `controls` und `canvas` als Widgets, plus optional
/// `reference: ToolReference(...)`. Alles andere (Layout, Toggles,
/// Schließen-Knopf, Mobile-Vollbildroute) macht der Scaffold.
class ToolScaffold extends StatefulWidget {
  const ToolScaffold({
    super.key,
    required this.title,
    required this.controls,
    required this.canvas,
    this.reference,
    this.narrowControlsHeight = 280,
  });

  final String title;
  final Widget controls;
  final Widget canvas;
  final ToolReference? reference;

  /// Höhe des Controls-Bereichs unter dem Canvas im Narrow-Layout.
  /// Default 280 reicht für 3–6 Eingaben; größere Tools (z.B. Grat/Kehl
  /// mit 13 Eingaben) wählen 320–360.
  final double narrowControlsHeight;

  @override
  State<ToolScaffold> createState() => _ToolScaffoldState();
}

class _ToolScaffoldState extends State<ToolScaffold> {
  // Layout-Konstanten — geteilt über alle Tools, damit das Wide/Narrow-
  // Verhalten konsistent ist.
  static const double _wideBreakpoint = 700;
  static const double _initialControlsWidth = 360;
  static const double _initialReferenceWidth = 460;
  static const double _minControlsWidth = 260;
  static const double _minReferenceWidth = 320;

  double _controlsWidth = _initialControlsWidth;
  double _referenceWidth = _initialReferenceWidth;
  bool _referenceVisible = false;

  String get _referenceTooltip {
    final tabs = widget.reference?.tabs;
    if (tabs == null || tabs.isEmpty) return 'Referenz';
    return tabs.length == 1 ? tabs.first.label : 'Referenz';
  }

  @override
  Widget build(BuildContext context) {
    final hasReference = widget.reference != null &&
        widget.reference!.tabs.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        // Tool selection lives in the bar itself — no leading hamburger.
        automaticallyImplyLeading: false,
        titleSpacing: 4,
        title: const ToolSelectorBar(),
        actions: [
          if (hasReference)
            LayoutBuilder(builder: (context, _) {
              final isWide =
                  MediaQuery.of(context).size.width > _wideBreakpoint;
              return IconButton(
                tooltip: _referenceTooltip,
                icon: Icon(
                  _referenceVisible && isWide
                      ? Icons.menu_book
                      : Icons.menu_book_outlined,
                ),
                onPressed: () {
                  if (isWide) {
                    setState(() => _referenceVisible = !_referenceVisible);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          _ReferenceRoute(reference: widget.reference!),
                    ));
                  }
                },
              );
            }),
          const _OverflowMenu(),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > _wideBreakpoint;
          if (isWide) return _buildWideLayout(constraints, hasReference);
          return _buildNarrowLayout();
        },
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints, bool hasReference) {
    final referenceW = (_referenceVisible && hasReference)
        ? _referenceWidth.clamp(
            _minReferenceWidth, constraints.maxWidth * 0.6)
        : 0.0;
    final maxControls = constraints.maxWidth - 240 - referenceW;
    final controlsW = _controlsWidth.clamp(
      _minControlsWidth,
      maxControls.clamp(_minControlsWidth, double.infinity),
    );
    return Row(
      children: [
        SizedBox(width: controlsW, child: widget.controls),
        DragHandle(
          onDrag: (dx) => setState(() {
            _controlsWidth =
                (_controlsWidth + dx).clamp(_minControlsWidth, maxControls);
          }),
        ),
        Expanded(child: widget.canvas),
        if (_referenceVisible && hasReference) ...[
          DragHandle(
            onDrag: (dx) => setState(() {
              _referenceWidth = (_referenceWidth - dx).clamp(
                _minReferenceWidth,
                constraints.maxWidth * 0.6,
              );
            }),
          ),
          SizedBox(
            width: referenceW,
            child: _ReferencePanel(
              reference: widget.reference!,
              onClose: () => setState(() => _referenceVisible = false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(child: widget.canvas),
        const Divider(height: 1),
        SizedBox(height: widget.narrowControlsHeight, child: widget.controls),
      ],
    );
  }
}

/// Optionales Referenz-Panel: ein oder mehrere Tabs.
///
/// Bei einem Tab wird der Tab-Inhalt direkt unter dem Panel-Header
/// gerendert (kein TabBar). Bei mehreren Tabs erscheint TabBar +
/// TabBarView.
class ToolReference {
  const ToolReference({required this.tabs});
  final List<ReferenceTab> tabs;
}

class ReferenceTab {
  const ReferenceTab({required this.label, required this.content});
  final String label;
  final Widget content;
}

class _ReferencePanel extends StatelessWidget {
  const _ReferencePanel({required this.reference, required this.onClose});

  final ToolReference reference;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tabs = reference.tabs;
    if (tabs.length == 1) {
      return Column(
        children: [
          _PanelHeader(title: tabs.first.label, onClose: onClose),
          Expanded(child: tabs.first.content),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          _PanelHeader(title: 'Referenz', onClose: onClose),
          TabBar(
            tabs: [for (final t in tabs) Tab(text: t.label)],
            labelColor: scheme.tertiary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            indicatorColor: scheme.tertiary,
            isScrollable: tabs.length > 3,
          ),
          Expanded(
            child: TabBarView(
              children: [for (final t in tabs) t.content],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onClose});
  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// Vollbild-Route für das Referenz-Panel im Narrow-Layout.
class _ReferenceRoute extends StatelessWidget {
  const _ReferenceRoute({required this.reference});
  final ToolReference reference;

  @override
  Widget build(BuildContext context) {
    final tabs = reference.tabs;
    if (tabs.length == 1) {
      return Scaffold(
        appBar: AppBar(title: Text(tabs.first.label)),
        body: tabs.first.content,
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Referenz'),
          bottom: TabBar(
            tabs: [for (final t in tabs) Tab(text: t.label)],
            isScrollable: tabs.length > 3,
          ),
        ),
        body: TabBarView(children: [for (final t in tabs) t.content]),
      ),
    );
  }
}

/// AppBar-Überlaufmenü (⋮): Einstellungen + Über — der frühere Drawer-Fuß.
/// Liegt selbst im [HubScope] und reicht dessen Daten an den darüber gepushten
/// Einstellungs-Screen weiter.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context) {
    final scope = HubScope.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Mehr',
      onSelected: (value) {
        switch (value) {
          case 'settings':
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsScreen(
                allEntries: scope.allEntries,
                disabledIds: scope.disabledIds,
                onToggleTool: scope.onToggleTool,
              ),
            ));
          case 'about':
            showAboutDialog(
              context: context,
              applicationName: 'Geometrie-Spielzeug',
              applicationVersion: '0.1.0',
              applicationLegalese: '© Eric Naville, 2026.\n'
                  'Lizenz: CC BY-NC-SA 4.0\n'
                  '(Frei für nicht-kommerzielle Nutzung)',
              children: const [
                SizedBox(height: 12),
                Text(
                  'Quelltext und Inhalte stehen unter der Creative-Commons-'
                  'Lizenz BY-NC-SA 4.0. Du darfst sie weitergeben und '
                  'bearbeiten, solange du den Urheber nennst, sie nicht '
                  'kommerziell nutzt und Bearbeitungen unter derselben Lizenz '
                  'teilst.',
                ),
              ],
            );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.tune_outlined),
            title: Text('Einstellungen'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'about',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Über'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
