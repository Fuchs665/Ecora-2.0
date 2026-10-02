-- ============================================================================
-- Fotografia della struttura del database, una riga per oggetto, in un'unica
-- cella di testo. SOLO catalogo: nessuna riga di dati utente.
--
-- La stessa query gira:
--   - sullo staging locale, da run_chain.sh, dopo la catena 0000 -> ultima;
--   - sulla produzione, in sola lettura (connector o SQL Editor), per
--     rigenerare supabase/tests/catalogo_produzione.txt.
-- I trigger dei Database Webhooks (funzione in supabase_functions) sono
-- esclusi di proposito: i loro argomenti contengono un segreto.
-- I corpi delle funzioni sono confrontati per impronta md5 a spazi ridotti
-- (la produzione li ha con a capo Windows).
-- ============================================================================
with righe(r) as (
  -- tabelle e RLS
  select format('tabella %s rls=%s', c.relname, c.relrowsecurity)
  from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')

  -- colonne
  union all
  select format('colonna %s.%s %s null=%s default=%s',
                col.table_name, col.column_name, col.data_type,
                col.is_nullable, coalesce(col.column_default, '-'))
  from information_schema.columns col
  where col.table_schema = 'public'

  -- vincoli
  union all
  select format('vincolo %s.%s %s', c.relname, con.conname,
                pg_get_constraintdef(con.oid))
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  where c.relnamespace = 'public'::regnamespace

  -- indici
  union all
  select format('indice %s.%s %s', i.tablename, i.indexname, i.indexdef)
  from pg_indexes i
  where i.schemaname = 'public'

  -- policy (public e storage.objects)
  union all
  select format('policy %s.%s "%s" %s %s %s using=%s check=%s',
                p.schemaname, p.tablename, p.policyname, p.permissive,
                p.roles::text, p.cmd,
                coalesce(regexp_replace(p.qual, '\s+', ' ', 'g'), '-'),
                coalesce(regexp_replace(p.with_check, '\s+', ' ', 'g'), '-'))
  from pg_policies p
  where p.schemaname = 'public'
     or (p.schemaname = 'storage' and p.tablename = 'objects')

  -- permessi sulle tabelle
  union all
  select format('permesso %s %s %s', g.table_name, g.grantee,
                string_agg(g.privilege_type, ',' order by g.privilege_type))
  from information_schema.role_table_grants g
  where g.table_schema = 'public'
    and g.grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role')
  group by g.table_name, g.grantee

  -- permessi per colonna (solo dove manca il permesso sull'intera tabella)
  union all
  select format('permesso_colonne %s %s %s %s', cp.table_name, cp.grantee,
                cp.privilege_type,
                string_agg(cp.column_name, ',' order by cp.column_name))
  from information_schema.column_privileges cp
  where cp.table_schema = 'public'
    and cp.grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role')
    and not exists (
      select 1 from information_schema.role_table_grants g
      where g.table_schema = cp.table_schema and g.table_name = cp.table_name
        and g.grantee = cp.grantee and g.privilege_type = cp.privilege_type)
  group by cp.table_name, cp.grantee, cp.privilege_type

  -- funzioni di public
  union all
  select format('funzione %s(%s) -> %s secdef=%s vol=%s lang=%s config=%s acl=%s corpo=%s',
                f.proname, pg_get_function_identity_arguments(f.oid),
                pg_get_function_result(f.oid), f.prosecdef, f.provolatile,
                l.lanname, coalesce(f.proconfig::text, '-'),
                (select string_agg(a::text, ',' order by a::text)
                   from unnest(coalesce(f.proacl, acldefault('f', f.proowner))) a),
                md5(btrim(regexp_replace(f.prosrc, '\s+', ' ', 'g'))))
  from pg_proc f
  join pg_language l on l.oid = f.prolang
  where f.pronamespace = 'public'::regnamespace

  -- trigger con funzione in public (esclude i webhook)
  union all
  select format('trigger %s.%s %s', c.relname, t.tgname, pg_get_triggerdef(t.oid))
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_proc f on f.oid = t.tgfoid
  where c.relnamespace = 'public'::regnamespace
    and not t.tgisinternal
    and f.pronamespace = 'public'::regnamespace

  -- event trigger con funzione in public
  union all
  select format('event_trigger %s %s %s %s enabled=%s', e.evtname, e.evtevent,
                f.proname, coalesce(e.evttags::text, '-'), e.evtenabled)
  from pg_event_trigger e
  join pg_proc f on f.oid = e.evtfoid
  where f.pronamespace = 'public'::regnamespace

  -- realtime
  union all
  select format('pubblicazione %s %s.%s', pt.pubname, pt.schemaname, pt.tablename)
  from pg_publication_tables pt
  where pt.pubname = 'supabase_realtime'

  -- bucket dello Storage
  union all
  select format('bucket %s public=%s limite=%s mime=%s', b.id, b.public,
                coalesce(b.file_size_limit::text, '-'),
                coalesce(b.allowed_mime_types::text, '-'))
  from storage.buckets b
)
select string_agg(r, E'\n' order by r collate "C") as catalogo from righe;
