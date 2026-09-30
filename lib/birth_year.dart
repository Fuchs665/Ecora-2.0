import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

// Anno di nascita (Blocco B.2b). Le stesse regole del trigger della
// migrazione 0015: il controllo qui serve a dare un messaggio chiaro prima
// di andare al database, che resta l'autorità.

const String kBirthYearLabel = "Anno di nascita (per le coppie, del più giovane)";

/// Messaggio d'errore per l'anno inserito, o null se valido. Pura.
String? birthYearError(String input, DateTime now) {
  final text = input.trim();
  if (text.isEmpty) return "Inserisci il tuo anno di nascita.";
  final year = int.tryParse(text);
  if (year == null || text.length != 4 || year < 1900) {
    return "Inserisci un anno di nascita valido, ad esempio 1990.";
  }
  if (year > now.year) {
    return "Inserisci un anno di nascita valido, ad esempio 1990.";
  }
  if (now.year - year < 18) return "Ecora è riservata ai maggiorenni.";
  return null;
}

/// Solo cifre, al massimo 4.
final List<TextInputFormatter> kBirthYearInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

/// Chiesta una volta sola, al primo accesso dopo l'aggiornamento, a chi si
/// era registrato prima che l'anno fosse obbligatorio.
class BirthYearScreen extends StatefulWidget {
  /// Salva l'anno: null se riuscito, altrimenti il messaggio d'errore.
  final Future<String?> Function(int year) onSave;
  final VoidCallback onLogout;

  const BirthYearScreen({
    Key? key,
    required this.onSave,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<BirthYearScreen> createState() => _BirthYearScreenState();
}

class _BirthYearScreenState extends State<BirthYearScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = birthYearError(_controller.text, DateTime.now());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saveError = await widget.onSave(int.parse(_controller.text.trim()));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = saveError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoraSpace.s24,
            EcoraSpace.s40,
            EcoraSpace.s24,
            EcoraSpace.s24,
          ),
          children: [
            const Text("ECORA", style: EcoraTextStyles.wordmark),
            const SizedBox(height: EcoraSpace.s24),
            Text("Un'ultima cosa", style: textTheme.displayMedium),
            const SizedBox(height: EcoraSpace.s12),
            Text(
              "I gestori vedono l'età di chi chiede di partecipare alle "
              "loro serate. Inserisci il tuo anno di nascita: si imposta "
              "una volta sola e non si può cambiare.",
              style: textTheme.bodyLarge?.copyWith(color: EcoraColors.inkMuted),
            ),
            const SizedBox(height: EcoraSpace.s24),
            TextField(
              controller: _controller,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: kBirthYearInputFormatters,
              style: textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: kBirthYearLabel,
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: EcoraSpace.s24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: "Salvataggio in corso",
                      ),
                    )
                  : const Text("Continua"),
            ),
            const SizedBox(height: EcoraSpace.s8),
            TextButton(
              onPressed: _saving ? null : widget.onLogout,
              child: const Text("Esci"),
            ),
          ],
        ),
      ),
    );
  }
}
