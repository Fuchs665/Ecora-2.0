# Ecora — Piano di lavoro operativo
**Approvato:** 28 luglio 2026 · **Strategia:** prima i locali → poi lo Store → poi gli utenti
**Documenti collegati:** `docs/AUDIT_2026-07-28.md` · `docs/ecora-design-system.html`

---

## Stato avanzamento

| Blocco | Stato | Note |
|---|---|---|
| 0.1 · CLAUDE.md allineato | ✅ fatto | assunzione di dominio e divieti presenti |
| 0.2 · `.env.example` ripulito | ✅ fatto | |
| A.1 · Revoca accesso anonimo | ✅ fatto | `0014_revoke_anon_events.sql`, verificato |
| A.2 · Dipendenze inutilizzate | ✅ fatto | `flutter_map`, `latlong2`, `geolocator` tolte da `pubspec.yaml` e `pubspec.lock` (commit 4a02143); nel manifest Android resta solo `POST_NOTIFICATIONS`. Verificato il 30/09/2026. |
| B.1 · Design system | ✅ v2 nel tema | Direzione "Club privato" (combinazione 7 + copertina Luce, scelta il 30/09/2026). Specifica: design system "Ecora" su claude.ai; tavole della dashboard gestore nella tela "Dashboard gestore Ecora". In `lib/theme.dart` colori, caratteri (Bodoni Moda, Hanken Grotesk), `EcoraDepth`; `test/theme_test.dart` controlla i contrasti. `docs/ecora-design-system.html` descrive la v1 ed è superato. Le schermate con colori scritti a mano si migrano nei blocchi C e D. |
| C.1 · Fascia metriche + abbonamento declassato | ✅ fatto | Tavola "Serate". Riempimento medio calcolato solo sulle serate concluse. La lista mostra solo le serate del gestore (prima c'erano anche quelle degli altri locali). Nuovo stile `EcoraTextStyles.metric`, da riportare nel design system. |
| B.4 · Bug ordine operazioni | ✅ fatto | La scheda candidato si chiude solo a salvataggio riuscito (approva, rifiuta e blocca); durante l'attesa pulsanti spenti e dialogo non chiudibile, in caso di errore il messaggio resta nel dialogo. |
| B.3 · Copy onesto | ✅ fatto | Tolte 8 promesse false (anonimato end-to-end, dispositivo mai registrato, nickname/località nascosti, indirizzo e GPS svelati solo dopo approvazione, alta affidabilità, età fissa a 30, "Organizzati: 45"). Età, assenze e affidabilità nascoste finché B.2 non porta dati veri. `test/honest_copy_test.dart` impedisce che le frasi tornino. |
| B.2a · Migrazione età e presenze | ✅ scritta, **da applicare** | `supabase/migrations/0015_presenze_e_eta.sql`: `profiles.birth_year` (18+, immutabile dopo il primo salvataggio, leggibile dagli iscritti), tabella `event_attendance` (lettura solo al gestore della serata), `mark_attendance()` (solo gestore della serata, solo approvati, da inizio serata a +7 giorni), `get_guest_reliability()` (presenze/assenze su tutti i locali, solo per sé o per i gestori a cui l'utente si è candidato). Provata su Postgres locale: `supabase/tests/0015_presenze_e_eta_test.sql`. Da applicare dal SQL Editor prima di B.2b/B.2c. |
| B.2b · Età in registrazione | ✅ fatto, **richiede 0015 applicata** | Anno di nascita obbligatorio in registrazione (18+, per le coppie del più giovane), salvato anche nei metadati auth per il flusso con conferma email. I clienti iscritti prima lo inseriscono una volta al primo accesso (`BirthYearScreen`). Età vera in scheda candidato, lista richieste e profilo. `birth_year` è in `kProfileSelectColumns`: senza la migrazione 0015 il login fallisce. |
| B.2c, C.2 → E.4 | ⬜ da fare | |

---

## Assunzioni dichiarate

Due decisioni sono state prese per te, sulla base della strategia "prima i locali". Se non sei d'accordo, dillo prima di iniziare la fase relativa — cambiano lo scope.

1. **No-show reale, non rimosso.** Sulla scheda candidato si è scelta la strada ricca: implementare davvero il conteggio delle assenze invece di togliere il campo. Motivo: è l'unico dato che solo Ecora può avere — la reputazione dell'ospite tra locali diversi — ed è il singolo argomento di vendita più forte verso i gestori. Costa un blocco in più, vale l'intera trattativa.
2. **I gestori sono locali commerciali con indirizzo pubblico.** Tutta la fase A si appoggia a questa assunzione. Va scritta nel `CLAUDE.md` e ancorata alla verifica gestore (`is_verified`, oggi presente ma inutilizzato), altrimenti si rompe in silenzio il giorno in cui un gestore pubblica un evento a casa propria.

---

## Metodo di lavoro

Vale per ogni blocco, senza eccezioni:

1. Un blocco alla volta. Mai due in parallelo sullo stesso file.
2. Claude Code presenta **prima il piano** (file toccati + approccio) e aspetta approvazione.
3. Diff sempre visionato prima del commit.
4. Commit solo a `flutter analyze` pulito e `flutter test` verde.
5. Le migration SQL sono transazionali, idempotenti, e non toccano policy fuori scope.

---

## FASE 0 — Igiene (30 minuti, da fare subito)

**0.1 · Allineare il CLAUDE.md.**
Oggi dichiara che `kPrivacyPolicyUrl` è un placeholder `example.com` e che il link non è cliccabile: entrambe le cose sono risolte. Un CLAUDE.md che mente manda l'agente a "sistemare" ciò che è già a posto. Da aggiungere nello stesso passaggio: l'assunzione "solo locali commerciali", e il divieto di toccare RLS o codice pagamenti senza segnalazione esplicita.

**0.2 · Ripulire `.env.example`** dal residuo `GEMINI_API_KEY` / "AI Studio".

---

## FASE A — Chiusure di sicurezza (SQL, nessun impatto UI)

Indipendente dal design: si può eseguire in parallelo, o mentre si aspetta un feedback sui mockup.

**A.1 · Revoca accesso anonimo agli eventi** — *prompt già fornito, blocco 7.1*
`revoke execute … from anon` su `get_events_with_stats()`, `events_select_published` ristretta ad `authenticated`. L'app non legge mai gli eventi prima del login: da verificare come prima cosa, prima di toccare SQL.

**A.2 · Rimozione dipendenze inutilizzate** — *prompt già fornito, blocco 7.2*
`geolocator`, `flutter_map`, `latlong2` mai usate. Verificare col manifest unito se iniettano `ACCESS_FINE_LOCATION`: se sì, è un rischio di sospensione Play Data Safety.

---

## FASE B — Onestà del prodotto

Blocca la demo ai locali. Nessuna quantità di restyling compensa un dato falso.

**B.1 · Fondamenta del design system.**
`theme.dart` sono 67 righe: cinque colori e quattro builder. Tutto il resto — tipografia, spaziature, raggi, ombre, durate delle animazioni — è hardcoded nelle schermate. **Va fatto prima di ogni altro lavoro visivo**, altrimenti ogni blocco successivo ri-hardcoda e il restyling costa il triplo. Include: scala tipografica completa in `ThemeData`, token di spaziatura, font custom (Playfair Display + Inter), `CardTheme`/`DialogTheme`/`SnackBarTheme` centralizzati.

**B.2 · No-show ed età reali.** Diviso in B.2a (migrazione), B.2b (età in registrazione), B.2c (presenze in dashboard e scheda candidato).
Migration: colonna `birth_year` su `profiles`. Le assenze NON sono una colonna di `profiles` (ogni utente può aggiornare la propria riga e le azzererebbe): si salva la presenza di ogni ospite approvato in `event_attendance`, scritta solo dal gestore host tramite RPC, e i conteggi si calcolano da lì. UI: campo età obbligatorio in registrazione; nella dashboard gestore, dopo la data dell'evento, una lista "chi è venuto?" con toggle presente/assente che incrementa il contatore. La scheda candidato smette di mostrare numeri inventati.

**B.3 · Copy onesto.** Tre bugie da correggere:
- `main.dart:1074` — «Anonimato assoluto end-to-end. L'identità del tuo dispositivo non viene mai registrata» (falso: `device_tokens`, e nessuna cifratura E2E)
- `gestore_dashboard.dart:901` — «Indirizzo della Location Privata (Svelato solo dopo l'approvazione)» (falso: `location_name` è pubblico)
- Il claim «Partecipante ad ALTA AFFIDABILITÀ» va condizionato a dati veri (dipende da B.2)

**B.4 · Bug ordine operazioni.** `_reviewRequest` (`gestore_dashboard.dart:430`) fa `Navigator.pop()` prima dell'await: in caso di errore il dialogo è già chiuso e l'utente vede un messaggio su una lista immutata.

---

## FASE C — La dashboard che vende

Questa è la schermata della demo commerciale. Ordine per ritorno sull'investimento.

**C.1 · Fascia metriche + abbonamento declassato.**
Tre numeri sotto l'intestazione, prima di ogni altra cosa: richieste ricevute nel mese, tasso di riempimento medio, ospiti confermati sul prossimo evento. Tutti calcolabili da `requestsNotifier` + `eventsNotifier`, zero query nuove. La card abbonamento scende sotto e, quando attiva, diventa una riga discreta.

**C.2 · Empty state e skeleton.**
Quattro fetch asincrone in `initState` e nessun indicatore: alla prima apertura — cioè durante la demo — il gestore vede un titolo seguito dal vuoto. Skeleton shimmer in caricamento, empty state con CTA diretta alla creazione del primo evento.

**C.3 · Vocabolario unificato + label di navigazione visibili.**
Oggi: Tavoli, Consolle, Ispettore, Scudo, Stanze del Club, Creatore, Incontro Riservato, Protocollo d'Ingresso. Da sostituire con parole normali: tutto. "Tavoli" diventa "Serate", come nella tela "Dashboard gestore Ecora" (deciso il 30/09/2026; l'intestazione della dashboard lo usa già da C.1). Le quattro icone della bottom nav sono mute e due di esse sono scudi.
**Nota del Release Manager:** questa ripulitura risolve gratis anche il rischio di posizionamento sulla scheda Play Store. Va fatta una volta sola, con entrambi gli obiettivi in mente.

**C.4 · Navigazione e FAB rifatti.**
Via l'item invisibile con `Opacity(0)`, via il cerotto `index: _selectedTab == 2 ? 0 : _selectedTab`, via i due hit target sovrapposti. `BottomAppBar` con `notchMargin`, oppure — meglio — "Crea evento" come pulsante primario in cima alla dashboard, dove sta l'azione che genera fatturato.

**C.5 · Card delle serate come da tavola.**
Nella tavola "Serate" la lista diventa una card "Prossima serata" (copertina, posti, richieste da valutare con "Valuta", al posto del banner rosso) e una lista "In programma" con il tassello della data. Restano fuori finché non ci sono i dati: posti divisi in coppie/donne/uomini (oggi esiste solo `max_guests`) e il pulsante "Porta" per il check-in.

---

## FASE D — Rifinitura percepita

Il miglior rapporto effort/percezione dell'intero piano. Dopo la fase C, un pomeriggio ciascuna.

**D.1 · Movimento.** `AnimatedSwitcher` tra i tab, `Hero` sulle copertine verso `EventDetailsPage`, `AnimatedContainer` sulle card che cambiano stato, `HapticFeedback.lightImpact()` su approva/rifiuta.

**D.2 · Materiali.** Cache delle immagini di rete, placeholder disegnato in `CustomPaint` al posto della foto Unsplash hardcoded (`models.dart:131`), contrasti e dimensioni minime dei testi (oggi molti a 9-11px su grigio), coerenza dello slider "coppie" con i profili singoli.

---

## FASE E — Blocker Store

Da affrontare **dopo** la validazione nei locali, **prima** della pubblicazione. Ognuno di questi, da solo, causa il rigetto.

| | Voce | Riferimento |
|---|---|---|
| E.1 | Cancellazione account, in-app **e** da web | Google Play (2024), Apple 5.1.1(v), GDPR art. 17 |
| E.2 | Segnalazione contenuti e utenti + rimozione entro 24h | Apple 1.2, Google UGC |
| E.3 | Termini di Servizio / EULA (oggi l'utente accetta un documento inesistente) | Apple, UGC |
| E.4 | Hardening: re-lock biometrico, FLAG_SECURE, `allowBackup=false`, signOut globale, consenso 18+ scritto lato server | Audit A.1–A.5 |

**Vincolo di calendario da non dimenticare:** con un account sviluppatore personale creato dopo novembre 2023, Google Play richiede un test chiuso con **almeno 12 tester per 14 giorni consecutivi** prima di poter richiedere l'accesso alla produzione. I dodici gestori della fase "promozione nei locali" sono contemporaneamente i primi partner commerciali e il requisito Google: vanno messi sul canale di closed testing fin da subito, non dopo.

---

## Ordine consigliato

```
0.1 → 0.2 → A.1 → A.2 → B.1 → B.2 → B.3 → B.4
   → C.1 → C.2 → C.3 → C.4 → C.5 → D.1 → D.2
   → [demo ai locali + closed testing 12 tester]
   → E.1 → E.2 → E.3 → E.4 → pubblicazione
```

B.1 è il collo di bottiglia: tutto il lavoro visivo a valle dipende da un design system che oggi non esiste.
