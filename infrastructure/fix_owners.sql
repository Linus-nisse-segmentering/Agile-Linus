DO $$
DECLARE
    r RECORD;
BEGIN
    -- Set owner for all tables in public schema
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I OWNER TO recipe_user;', r.tablename);
    END LOOP;

    -- Set owner for all sequences in public schema
    FOR r IN SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public' LOOP
        EXECUTE format('ALTER SEQUENCE public.%I OWNER TO recipe_user;', r.sequence_name);
    END LOOP;

    -- Set owner for the schema itself
    EXECUTE 'ALTER SCHEMA public OWNER TO recipe_user;';
END
$$;
