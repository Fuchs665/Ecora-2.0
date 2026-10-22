# Ecora — Piano di lavoro operativo
**Approvato:** 28 luglio 2026 · **Aggiornato:** 22 ottobre 2026 · **Strategia:** prima i locali → poi lo Store → poi gli utenti
**Documenti collegati:** `docs/AUDIT_2026-07-28.md` · `docs/ecora-design-system.html` · "Ecora · Piano di lancio, costi e ricavi" e "Ecora tra i concorrenti" su claude.ai (privati)

---

## Stato avanzamento

| Blocco | Stato | Note |
|---|---|---|
| 0.1 · CLAUDE.md allineato | ✅ fatto | assunzione di dominio e divieti presenti |
| 0.2 · `.env.example` ripulito | ✅ fatto | |
| A.1 · Revoca accesso anonimo | ✅ fatto | `0014_revoke_anon_events.sql`, verificato |
| A.2 · Dipendenze inutilizzate | ✅ fatto | `geolocator`, `flutter_map`, `latlong2` rimosse da `pubspec.yaml` nel commit 4a02143 |
| B.1 · Design system | ✅ v2 nel tema | Direzione "Club privato" (combinazione 7 + copertina Luce, scelta il 30/09/2026). Specifica: design system "Ecora" su claude.ai; tavole della dashboard gestore nella tela "Dashboard gestore Ecora". In `lib/theme.dart` colori, caratteri (Bodoni Moda, Hanken Grotesk), `EcoraDepth`; `test/theme_test.dart` controlla i contrasti. `docs/ecora-design-system.html` descrive la v1 ed è superato. Le schermate con colori scritti a mano si migrano nei blocchi C e D. |
| B.2 → E.4 | ⬜ da fare | Rinumerati come task T01–T26 nella sezione "Piano di lancio" qui sotto |

---

## Piano di lancio (22 ottobre 2026)

Dopo l'analisi dei concorrenti il piano è diventato una lista di task, **una chat per task**. Obiettivo: lancio Android il **1 febbraio 2027** (3 sessioni a settimana), città pilota **Firenze**. Sviluppo da solo, account Play personale (quindi test chiuso con almeno 12 tester per 14 giorni, da aprire entro il 1 dicembre).

Regola per il modello: Opus 5.5 per tutto ciò che tocca RLS, login o pagamenti; Sonnet 5.5 per le schermate; Haiku 5.5 per i testi; Fable 5.1 solo per T21. Le chat di codice si aprono sul PC Windows, dove c'è Flutter.

| # | Task | Origine | Modello · effort | Dopo |
|---|---|---|---|---|
| **Fase 1** | **Dati veri e verifica dei locali** | | | |
| T01 | Verifica dei locali: `is_verified` applicato, P.IVA o codice fiscale dell'associazione, indirizzo pubblico, badge. Tocca RLS | concorrenti #1 | Opus 5.5 · high | — |
| T02 | Assenze ed età vere. Tocca RLS | B.2 | Opus 5.5 · high | — |
| T03 | Badge "Verificato dal locale" dopo la prima presenza confermata. Tocca RLS | concorrenti #2 | Opus 5.5 · high | T02 |
| T04 | Coordinate approssimate per chi non è approvato all'evento. Tocca RLS | audit C1 | Opus 5.5 · high | — |
| T05 | Testi onesti e via il filtro "raggio" calcolato da Firenze fissa | B.3, audit A6 | Sonnet 5.5 · medium | T02 |
| T06 | Ordine delle operazioni in `_reviewRequest` | B.4 | Sonnet 5.5 · low | — |
| **Fase 2** | **La dashboard che vende** | | | |
| T07 | Fascia metriche, abbonamento in basso | C.1 | Sonnet 5.5 · medium | T02 |
| T08 | Skeleton ed empty state | C.2 | Sonnet 5.5 · medium | — |
| T09 | Vocabolario unico ed etichette di navigazione | C.3 | Sonnet 5.5 · medium | — |
| T10 | Navigazione e "Crea evento" | C.4 | Sonnet 5.5 · medium | T09 |
| T11 | Copertine Luce al posto di Unsplash, colori v2 in tutte le schermate | D.2 | Sonnet 5.5 · high | — |
| T12 | Movimento e haptic | D.1 | Sonnet 5.5 · medium | T10 |
| **Fase 3** | **Requisiti Store e sicurezza** | | | |
| T13 | `supabase_flutter` 2.x. Tocca login | audit igiene | Opus 5.5 · high | T12 |
| T14 | Cancellazione account in app e da web, foto in Storage comprese. Tocca login | E.1, audit C2 | Opus 5.5 · high | T13 |
| T15 | Segnalazioni e moderazione trasparente (motivo, ricorso, 24h). Tocca RLS | E.2, audit C3, concorrenti #3 | Opus 5.5 · high | T13 |
| T16 | Termini di servizio | E.3, audit C4 | Opus 5.5 · medium | — |
| T17 | Consenso 18+ scritto dal server, errore creazione profilo visibile. Tocca login | audit A1, A2 | Opus 5.5 · high | T13 |
| T18 | Re-lock biometrico, FLAG_SECURE, `allowBackup=false`, signOut globale. Tocca login | E.4, audit A3–A5 | Opus 5.5 · high | T13 |
| T19 | Privacy policy (Nominatim, cancellazione) e Data Safety | audit M8 | Sonnet 5.5 · medium | T14 |
| T20 | Test su `data_service.dart` e regressione ruolo gestore | audit M9 | Sonnet 5.5 · high | T13 |
| T21 | Attacco simulato alle API (agente `supabase-rls-auditor`) | concorrenti #4 | Fable 5.1 · high | T14–T18 |
| T22 | Scheda Store: testi, screenshot neutri, target 18+ | concorrenti #5 | Haiku 5.5 · low | T11 |
| **Fase 4** | **Dopo il lancio** | | | |
| T23 | Pass d'ingresso QR | concorrenti #7 | Opus 5.5 · high | lancio |
| T24 | Link condivisibile della serata | concorrenti #8 | Opus 5.5 · high | lancio |
| T25 | Profilo di coppia collegato. Tocca login | concorrenti #9 | Opus 5.5 · high | lancio |
| T26 | Versione iOS | — | Sonnet 5.5 · high | lancio |

Le sezioni qui sotto restano il riferimento per il contenuto dei blocchi B–E.

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

**B.2 · No-show ed età reali.**
Migration: colonne `birth_year` (o `age`) e `no_shows` su `profiles`, con `no_shows` scrivibile solo dal gestore host tramite RPC dedicata. UI: campo età obbligatorio in registrazione; nella dashboard gestore, dopo la data dell'evento, una lista "chi è venuto?" con toggle presente/assente che incrementa il contatore. La scheda candidato smette di mostrare numeri inventati.

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
Oggi: Tavoli, Consolle, Ispettore, Scudo, Stanze del Club, Creatore, Incontro Riservato, Protocollo d'Ingresso. Da tenere: "Tavoli". Da sostituire con parole normali: tutto il resto. Le quattro icone della bottom nav sono mute e due di esse sono scudi.
**Nota del Release Manager:** questa ripulitura risolve gratis anche il rischio di posizionamento sulla scheda Play Store. Va fatta una volta sola, con entrambi gli obiettivi in mente.

**C.4 · Navigazione e FAB rifatti.**
Via l'item invisibile con `Opacity(0)`, via il cerotto `index: _selectedTab == 2 ? 0 : _selectedTab`, via i due hit target sovrapposti. `BottomAppBar` con `notchMargin`, oppure — meglio — "Crea evento" come pulsante primario in cima alla dashboard, dove sta l'azione che genera fatturato.

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
T01 → T06 (Fase 1) → T07 → T12 (Fase 2)
   → [demo ai locali di Firenze + test chiuso dal 1 dicembre]
   → T13 → T22 (Fase 3) → richiesta di pubblicazione → lancio
   → T23 → T26 (Fase 4)
```

B.1 è chiuso: il design system v2 è nel tema, il resto del lavoro visivo lo usa.
