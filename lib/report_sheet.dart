import 'package:flutter/material.dart';

import 'reports.dart';
import 'theme.dart';

/// Apre il foglio di segnalazione. Torna true se alla fine l'utente ha
/// anche bloccato [blockName] (il chiamante mostra la conferma e nasconde i
/// suoi contenuti), false o null altrimenti.
Future<bool?> showReportSheet(
  BuildContext context, {
  required ReportTargetType type,
  required String blockName,
  required Future<ReportResult> Function(String reason, String note) onSubmit,
  required Future<String?> Function() onBlock,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: slateSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReportSheet(
      type: type,
      blockName: blockName,
      onSubmit: onSubmit,
      onBlock: onBlock,
    ),
  );
}

/// Foglio di segnalazione (Blocco E.2b), in due momenti:
/// 1. motivo (obbligatorio) e nota facoltativa; con un errore il foglio resta
///    aperto con il messaggio e si può riprovare;
/// 2. a segnalazione inviata (o già presente) propone il blocco. Si chiude
///    con true solo a blocco riuscito; con un errore resta aperto.
/// Durante l'attesa del server il foglio non si chiude.
class ReportSheet extends StatefulWidget {
  final ReportTargetType type;
  final String blockName;
  final Future<ReportResult> Function(String reason, String note) onSubmit;
  final Future<String?> Function() onBlock;

  const ReportSheet({
    super.key,
    required this.type,
    required this.blockName,
    required this.onSubmit,
    required this.onBlock,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _note = TextEditingController();
  String? _reason;
  bool _busy = false;
  String? _error;

  /// Esito dell'invio: null finché si è nel primo momento.
  ReportResult? _result;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSubmit(reason, _note.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case ReportResult.sent:
        case ReportResult.alreadyReported:
          _result = result;
        case ReportResult.rateLimited:
          _error = kReportRateLimited;
        case ReportResult.failed:
          _error = kReportFailed;
      }
    });
  }

  Future<void> _block() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onBlock();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Widget _spinner() => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              EcoraSpace.s20,
              EcoraSpace.s20,
              EcoraSpace.s20,
              EcoraSpace.s20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(reportTitle(widget.type),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: EcoraSpace.s12),
              ...(_result == null ? _form(context) : _afterSubmit()),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _errorText() => [
        if (_error != null) ...[
          const SizedBox(height: EcoraSpace.s8),
          Text(_error!,
              style: const TextStyle(fontSize: 13, color: EcoraColors.danger)),
        ],
      ];

  List<Widget> _form(BuildContext context) {
    final reasons = kReportReasons[widget.type]!;
    return [
      const Text(kReportSubtitle,
          style: TextStyle(fontSize: 13, color: EcoraColors.inkMuted)),
      const SizedBox(height: EcoraSpace.s8),
      for (final r in reasons)
        Semantics(
          inMutuallyExclusiveGroup: true,
          checked: _reason == r.code,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            enabled: !_busy,
            leading: Icon(
              _reason == r.code
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _reason == r.code
                  ? EcoraColors.brass
                  : EcoraColors.lineControl,
            ),
            title: Text(r.label,
                style: const TextStyle(fontSize: 14, color: EcoraColors.ink)),
            onTap: () => setState(() => _reason = r.code),
          ),
        ),
      const SizedBox(height: EcoraSpace.s8),
      TextField(
        controller: _note,
        enabled: !_busy,
        minLines: 2,
        maxLines: 4,
        maxLength: kReportNoteMaxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: kReportNoteLabel),
      ),
      ..._errorText(),
      const SizedBox(height: EcoraSpace.s16),
      ElevatedButton(
        onPressed: _reason == null || _busy ? null : _submit,
        child: _busy ? _spinner() : const Text(kReportSubmit),
      ),
      const SizedBox(height: EcoraSpace.s4),
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text(kReportCancel),
      ),
    ];
  }

  List<Widget> _afterSubmit() {
    const body = TextStyle(fontSize: 14, color: EcoraColors.ink, height: 1.4);
    return [
      Text(
        _result == ReportResult.alreadyReported
            ? kReportAlreadySent
            : kReportSent,
        style: body,
      ),
      const SizedBox(height: EcoraSpace.s16),
      Text(reportBlockQuestion(widget.blockName),
          style: const TextStyle(fontSize: 14, color: EcoraColors.inkMuted)),
      ..._errorText(),
      const SizedBox(height: EcoraSpace.s16),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: EcoraColors.danger,
          foregroundColor: EcoraColors.onBrass,
        ),
        onPressed: _busy ? null : _block,
        child: _busy ? _spinner() : const Text(kReportBlock),
      ),
      const SizedBox(height: EcoraSpace.s4),
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text(kReportNoThanks),
      ),
    ];
  }
}
