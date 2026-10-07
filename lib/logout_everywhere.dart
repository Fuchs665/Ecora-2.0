import 'package:flutter/material.dart';

import 'theme.dart';

// "Esci da tutti i dispositivi" (Blocco E.4d, audit A3). Testi approvati
// il 07/10/2026.

const String kLogoutEverywhereEntry = "Esci da tutti i dispositivi";
const String kLogoutEverywhereBody =
    "Verrai disconnesso da Ecora su tutti i dispositivi, compreso questo. "
    "Le notifiche smetteranno di arrivare.";
const String kLogoutEverywhereConfirm = "Esci ovunque";
const String kLogoutEverywhereFailed =
    "Non è stato possibile uscire dagli altri dispositivi. Controlla la "
    "connessione e riprova.";

/// Conferma. Resta aperto finché [onConfirm] non riesce: un'azione di
/// sicurezza non deve sembrare riuscita se non lo è.
class LogoutEverywhereDialog extends StatefulWidget {
  /// null se riuscito, altrimenti il messaggio da mostrare.
  final Future<String?> Function() onConfirm;

  const LogoutEverywhereDialog({super.key, required this.onConfirm});

  @override
  State<LogoutEverywhereDialog> createState() => _LogoutEverywhereDialogState();
}

class _LogoutEverywhereDialogState extends State<LogoutEverywhereDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onConfirm();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text(kLogoutEverywhereEntry),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(kLogoutEverywhereBody),
            if (_error != null) ...[
              const SizedBox(height: EcoraSpace.s12),
              Text(
                _error!,
                style:
                    textTheme.bodyMedium?.copyWith(color: EcoraColors.danger),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(kLogoutEverywhereConfirm),
          ),
        ],
      ),
    );
  }
}
