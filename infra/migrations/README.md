# JAYEK database migrations

Fresh databases are initialized from `infra/schema.sql`. Incremental changes after the baseline belong here and are applied in lexical order by `infra/scripts/migrate.sh`.

The runner records applied filenames in `schema_migrations` and is safe to rerun. Never edit an already-applied migration; add a new one.
