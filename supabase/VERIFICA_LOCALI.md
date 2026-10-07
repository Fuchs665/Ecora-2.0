# Verifica dei locali

Procedura per attivare, sospendere e riattivare l'account di un locale
(Blocchi V.1–V.3, migrazione `0021_gestori_verificati.sql`). Regola di
dominio (CLAUDE.md, Termini punto 4): **possono pubblicare serate solo locali
commerciali aperti al pubblico, con un indirizzo pubblico; mai abitazioni
private.** L'account del locale lo attiviamo noi, dopo averlo verificato.

Tocca ruolo e verifica (auth/RLS): tutto dalla dashboard Supabase, SQL Editor
del progetto **Ecora**. Ruolo e verifica li cambia solo `service_role`
(trigger della 0017): dal SQL Editor serve `set local role service_role`
dentro una transazione, come negli esempi. Mai condividere la service role.

Cosa decide `is_verified`:

| | verificato | non verificato o sospeso |
|---|---|---|
| creare e pubblicare serate, caricare copertine | sì (con abbonamento attivo) | no |
| serate già pubblicate | visibili agli iscritti | **invisibili** (non cancellate) |
| valutare le candidature | sì | no |
| annullare o cancellare le proprie serate | sì | sì |
| chat delle serate, presenze | sì | sì |

L'app legge lo stato all'accesso: il gestore vede l'avviso «Locale non attivo»
(o smette di vederlo) dal login o dall'avvio successivo.

## 1. Attivare un locale

Il locale si registra nell'app come un iscritto qualunque (il profilo nasce
sempre `cliente`, non verificato) e ci chiede l'attivazione.

### a) Controlla

Tutti i punti, prima di attivare:

1. **Attività commerciale:** ragione sociale e partita IVA attiva (servizio
   gratuito "Verifica partita IVA" dell'Agenzia delle Entrate, o VIES).
2. **Indirizzo pubblico del locale:** insegna o scheda pubblica (mappe, sito,
   social) allo stesso indirizzo. Non è un'abitazione: niente interno o scala
   di un condominio residenziale, niente "su invito" senza indirizzo.
3. **Chi chiede rappresenta il locale:** la richiesta arriva da un contatto
   pubblico del locale (email del dominio o indicata sul sito, numero di
   telefono pubblico richiamato da noi).
4. **Profilo coerente:** nickname e località del profilo corrispondono al
   locale.

In caso di dubbio non si attiva. Annota data, esito e chi ha verificato in un
registro privato, **fuori dal repository** (contiene dati del titolare).

### b) Attiva

Recupera l'uid in Authentication → Users (email del locale), poi:

```sql
begin;
set local role service_role;
update public.profiles
   set role = 'gestore', is_verified = true
 where id = '<USER_UID>';
commit;

select role, is_verified from public.profiles where id = '<USER_UID>';
-- atteso: gestore | true
```

Scrivi al locale che l'account è attivo: dal prossimo accesso vede la
dashboard del gestore e può abbonarsi e pubblicare.

## 2. Sospendere un locale

Quando una serata non è in un locale commerciale, per le violazioni gravi dei
Termini o se i controlli del punto 1 non valgono più.

```sql
begin;
set local role service_role;
update public.profiles set is_verified = false where id = '<USER_UID>';
commit;
```

Effetto immediato: tutte le sue serate pubblicate spariscono per gli iscritti
(restano nel database, con richieste e chat), non può pubblicarne di nuove né
valutare candidature. Il ruolo resta `gestore`.

- **Abbonamento:** la sospensione **non** lo disdice. Il rinnovo su Google Play
  continua finché il locale non lo disdice; un eventuale rimborso si decide a
  mano da Play Console (i Termini sui rimborsi per sospensione sono ancora da
  confermare, riga E.3a del piano).
- Scrivi al locale il motivo della sospensione dal suo indirizzo email
  (Authentication → Users).
- Se la serata segnalata va anche tolta per sempre, annullala
  (`MODERAZIONE.md`, passo 3b): una serata annullata non torna visibile alla
  riattivazione.

## 3. Riattivare un locale

Dopo aver ricontrollato il punto 1:

```sql
begin;
set local role service_role;
update public.profiles set is_verified = true where id = '<USER_UID>';
commit;
```

Le serate ancora `published` tornano visibili subito: se qualcuna è nel
frattempo superata o non va più mostrata, annullala prima.

## 4. Togliere il ruolo di gestore

Raro (per esempio il locale chiude): prima annulla le serate future, poi

```sql
begin;
set local role service_role;
update public.profiles
   set role = 'cliente', is_verified = false
 where id = '<USER_UID>';
commit;
```

Per eliminare l'account del tutto vale la procedura di cancellazione
(nell'app o `CANCELLAZIONE_MANUALE.md`).
