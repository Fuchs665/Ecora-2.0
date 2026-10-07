# Cancellazione account su richiesta via email

Procedura per chi non può usare l'app né il form di
[elimina-account.html](../docs/elimina-account.html): password dimenticata o
email mai confermata (Blocco E.1c). Termine promesso sulla pagina: **30 giorni**
dalla conferma.

Tocca auth e dati personali: si fa solo dalla dashboard Supabase, mai
condividendo la service role.

## 1. Verifica dell'identità

1. La richiesta deve arrivare **dall'indirizzo email dell'account**.
2. Il mittente di un'email si può falsificare: rispondi allo stesso indirizzo
   chiedendo di confermare la richiesta ("Rispondi CONFERMO per eliminare
   l'account Ecora collegato a questo indirizzo"). Si procede solo dopo la
   risposta da quell'indirizzo.
3. Se l'indirizzo non corrisponde a nessun account (passo 2), rispondi che
   non risulta alcun account con quell'email.

## 2. Trova l'uid

Dashboard → Authentication → Users → cerca l'email → copia lo **User UID**.
Annotalo per i passi successivi (qui sotto `<UID>`).

## 3. File nello Storage

SQL Editor:

```sql
select * from public.account_deletion_files('<UID>');
```

Per ogni riga: Storage → bucket indicato → seleziona il file indicato in
`path` → Delete. (La galleria è la cartella `<UID>` del bucket
`profile_photos`: si può cancellare la cartella intera.)

## 4. Dati nel database

SQL Editor:

```sql
select public.delete_account_data('<UID>');
```

Restituisce il ruolo e i conteggi. Annota il ruolo (`cliente` o `gestore`).

## 5. Utente auth

Dashboard → Authentication → Users → l'utente → Delete user.

Va fatto **dopo** il passo 4: il cascade da `auth.users` cancellerebbe anche
le serate passate di un gestore e le presenze dei suoi ospiti, che la
funzione invece archivia in forma anonima.

## 6. Registro anonimo

SQL Editor (ruolo del passo 4):

```sql
insert into public.account_deletions (role, channel) values ('<RUOLO>', 'email');
```

## 7. Verifica e risposta

1. Esegui la query c) della sezione VERIFICA in fondo a
   `supabase/migrations/0016_cancellazione_account.sql`: tutte le righe a 0.
2. Rispondi all'utente che l'account è stato eliminato. Ai gestori ricorda
   che l'abbonamento Google Play va disdetto da Google Play.
3. Cancella lo scambio di email dalla casella, se non serve per altro.
