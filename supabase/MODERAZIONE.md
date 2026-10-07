# Moderazione delle segnalazioni

Procedura per la coda di `public.reports` (Blocco E.2a, migrazione
`0019_segnalazioni.sql`). Vale l'impegno dichiarato nell'app: **ogni
segnalazione viene esaminata entro 24 ore**, weekend compresi.

Tocca RLS, auth e dati personali: tutto dalla dashboard Supabase (SQL Editor e
Authentication), mai condividendo la service role. L'app non legge mai la coda:
`reports` non ha nessun permesso di lettura per i client.

## 0. Quando arriva una segnalazione

Il Database Webhook su INSERT di `reports` chiama la Edge Function `push`, che
manda al telefono del moderatore "Nuova segnalazione da esaminare" (nessun
contenuto nella notifica). **La push può non arrivare** (telefono spento, token
scaduto, funzione in errore): apri la coda almeno una volta al giorno.

## 1. Leggi la coda

SQL Editor:

```sql
select * from public.reports_open;
```

Ordine: prima i casi `underage`, poi dal più vecchio. `ore_trascorse` dice
quanto manca alle 24 ore. Le colonne utili:

| colonna | cosa contiene |
|---|---|
| `target_type` | `message`, `user` o `event` |
| `reason` | il motivo scelto da chi segnala (vedi tabella sotto) |
| `note` | nota facoltativa di chi segnala (max 500 caratteri) |
| `content_snapshot` | copia del contenuto **al momento della segnalazione**: resta anche se l'autore lo cancella o cancella l'account |
| `target_user_id` | l'utente responsabile (mittente del messaggio, organizzatore della serata, profilo segnalato); vuoto se si è cancellato |
| `target_message_id` / `target_event_id` | vuoti se il contenuto è già stato cancellato |

Motivi:

| `reason` | messaggio | utente | serata |
|---|---|---|---|
| `underage` | | sembra minorenne | |
| `threats` | minacce | | |
| `harassment` | offese o molestie | offese o molestie | |
| `unwanted_sexual` | contenuto sessuale non richiesto | | |
| `inappropriate_photos` | | foto inappropriate nella galleria | |
| `fake_profile` | | profilo falso | |
| `not_a_venue` | | | non si svolge in un locale |
| `misleading` | | | serata falsa o ingannevole |
| `inappropriate_content` | | | contenuti inappropriati |
| `spam` | spam o truffa | spam o truffa | spam o truffa |
| `other` | altro | altro | altro |

Il contenuto ancora presente si guarda così (sola lettura, una riga per volta,
mai una lettura in blocco della chat):

```sql
select content, sender_id, created_at from public.messages where id = '<MESSAGE_UID>';
select title, description, location_name, status, event_date, host_id
  from public.events where id = '<EVENT_UID>';
select nickname, role, is_verified, birth_year from public.profiles where id = '<USER_UID>';
```

La galleria di un utente: Storage → `profile_photos` → cartella `<USER_UID>`
(i nomi dei file sono anche in `content_snapshot -> 'gallery'`).

## 2. Decidi

Linea di condotta, nell'ordine:

1. **`underage`, anche solo sospetto** → ban immediato (passo 3c) e
   cancellazione dei contenuti, prima di ogni altra verifica. Non si chiede una
   prova all'utente: in caso di dubbio l'account resta chiuso.
2. **Minacce, molestie, contenuti sessuali non richiesti** → cancella il
   contenuto; al secondo caso per lo stesso utente, ban.
3. **Serata non in un locale** (assunzione di dominio: i gestori sono locali
   commerciali con indirizzo pubblico) → annulla la serata e sospendi il
   locale (`VERIFICA_LOCALI.md`, punto 2), poi scrivi al gestore.
4. **Profilo falso, spam, truffa** → ban se è evidente, altrimenti cancella il
   contenuto e annota.
5. **Segnalazione infondata o ritorsiva** → chiudila come `dismissed`. Se un
   utente ne manda molte infondate, il tetto di 20 al giorno lo rallenta già;
   per i casi gravi, ban.

L'utente segnalato **non viene avvisato** di chi l'ha segnalato: nell'app è
scritto che chi segnala resta anonimo.

## 3. Agisci

### a) Cancellare un messaggio

```sql
delete from public.messages where id = '<MESSAGE_UID>';
```

La segnalazione resta, con `target_message_id` vuoto e lo snapshot come prova.

### b) Annullare una serata

```sql
update public.events set status = 'cancelled' where id = '<EVENT_UID>';
```

La serata smette di essere visibile nell'app (le policy mostrano solo
`published`). Le richieste e la chat restano: servono se l'utente contesta.
Scrivi al gestore dal suo indirizzo email (Authentication → Users).

### c) Bannare un utente

1. Dashboard → Authentication → Users → l'utente → **Ban user** (oppure
   `banned_until`): da quel momento non può più autenticarsi.
2. Chiudi le sessioni aperte: nella stessa pagina, l'azione che revoca i
   refresh token dell'utente. **Il token di accesso già emesso resta valido
   fino alla scadenza (circa 1 ora):** per questa finestra l'utente può ancora
   scrivere. Se è un caso grave (`underage`, minacce), subito dopo il ban
   cancella i suoi contenuti (passi a e b) e la riga in `device_tokens`:

   ```sql
   delete from public.device_tokens where user_id = '<USER_UID>';
   ```
3. Se è un gestore, le sue serate restano pubblicate: sospendi il locale
   (`VERIFICA_LOCALI.md`, punto 2), così spariscono subito tutte; per toglierle
   per sempre annullale anche:

   ```sql
   update public.events set status = 'cancelled'
    where host_id = '<USER_UID>' and status = 'published';
   ```
4. **Attenzione:** un utente bannato non riesce più a fare login, quindi non può
   più usare "Elimina account" nell'app né il form web (entrambi fanno un login
   con la password). Se chiede la cancellazione, si fa a mano con
   [CANCELLAZIONE_MANUALE.md](CANCELLAZIONE_MANUALE.md); l'account bannato non
   si sblocca per farlo.

Il ban non cancella i dati: è una sospensione. Non conserviamo le email degli
account cancellati, quindi **un bannato che cancella l'account può
re-registrarsi con la stessa email**: non c'è modo di impedirlo a costo zero.

### d) Chiudere la segnalazione

Sempre, anche quando non si fa nulla (`status` e `resolved_at` vanno insieme:
un vincolo impedisce di chiuderne una senza data):

```sql
update public.reports
   set status = 'actioned',      -- oppure 'dismissed' se infondata
       resolved_at = now()
 where id = '<REPORT_UID>';
```

Più segnalazioni dello stesso contenuto si chiudono insieme:

```sql
update public.reports
   set status = 'actioned', resolved_at = now()
 where status = 'open' and target_message_id = '<MESSAGE_UID>';
```

Finché una segnalazione resta aperta, chi l'ha mandata non può segnalare di
nuovo lo stesso bersaglio (vede "Hai già segnalato questo contenuto").

## 4. Filtro dei messaggi

`public.blocked_terms` contiene le parole rifiutate nella chat: confronto a
parole intere, senza distinzione fra maiuscole e minuscole. Chi scrive vede
"Il messaggio contiene termini non ammessi su Ecora." e il messaggio non viene
salvato. **La lista parte vuota.**

```sql
-- aggiungere (sempre in minuscolo, senza spazi ai bordi)
insert into public.blocked_terms (term) values ('<termine>')
  on conflict do nothing;
-- vedere la lista
select term, created_at from public.blocked_terms order by term;
-- togliere
delete from public.blocked_terms where term = '<termine>';
```

Criteri, da ricordare prima di aggiungere un termine: Ecora è un'app per adulti
e il linguaggio sessuale esplicito fra utenti consenzienti è normale, **non va
filtrato**. In lista vanno solo insulti, minacce, termini che indicano
minorenni, e i richiami tipici delle truffe. Un termine troppo generico blocca
conversazioni legittime e l'utente non capisce perché: meglio una lista corta.

Il filtro non si applica a titoli e descrizioni delle serate né ai nickname:
quelli si moderano con le segnalazioni.

## 5. Pulizia mensile (conservazione 12 mesi)

Le segnalazioni, aperte o chiuse, si conservano **12 mesi** dalla data di
creazione (dichiarato in `docs/privacy.html`). Una volta al mese, SQL Editor:

```sql
select public.purge_old_reports();
```

Restituisce quante righe ha cancellato. È l'unica operazione periodica: niente
pg_cron, niente servizi a pagamento.

## 6. Quando ci si allontana dal computer

L'impegno delle 24 ore vale ogni giorno. Se non si riesce a garantirlo per un
periodo (vacanza, malattia), le opzioni, in ordine di preferenza:

1. Delegare l'accesso al SQL Editor a una seconda persona di fiducia e passarle
   questa procedura.
2. Svuotare temporaneamente la chat dalla possibilità di scrivere non è
   previsto dal codice: non farlo a mano sul database.
3. In ultima istanza, allungare il termine dichiarato nell'app (copy in
   `lib/report_sheet.dart`) e in questo file: un termine scritto e non
   rispettato è peggio di un termine più lungo.
