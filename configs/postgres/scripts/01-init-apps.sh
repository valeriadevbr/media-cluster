#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until pg_isready -U "$POSTGRES_USER"; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

# Helper function to initialize app databases and user
init_app_db() {
  local APP_NAME=$1
  local APP_PASSWORD=$2

  if [ -z "$APP_PASSWORD" ]; then
    echo "⚠️ Skipping $APP_NAME: Password variable not set"
    return
  fi

  echo "🚀 Initializing $APP_NAME..."

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Create databases if they don't exist
    SELECT 'CREATE DATABASE ${APP_NAME}_main'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_NAME}_main')\gexec

    SELECT 'CREATE DATABASE ${APP_NAME}_logs'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_NAME}_logs')\gexec

    -- Create user if it doesn't exist
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${APP_NAME}') THEN
        CREATE USER ${APP_NAME} WITH PASSWORD '${APP_PASSWORD}';
      END IF;
    END
    \$\$;

    -- Revoke default privileges from public
    REVOKE CONNECT ON DATABASE ${APP_NAME}_main FROM public;
    REVOKE CONNECT ON DATABASE ${APP_NAME}_logs FROM public;

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE ${APP_NAME}_main TO ${APP_NAME};
    GRANT ALL PRIVILEGES ON DATABASE ${APP_NAME}_logs TO ${APP_NAME};

    -- Setup schema privileges for main db
    \c ${APP_NAME}_main
    REVOKE ALL ON SCHEMA public FROM public;
    GRANT ALL ON SCHEMA public TO ${APP_NAME};
    GRANT ALL ON SCHEMA public TO ${APP_NAME};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${APP_NAME};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${APP_NAME};

    -- Setup schema privileges for logs db
    \c ${APP_NAME}_logs
    REVOKE ALL ON SCHEMA public FROM public;
    GRANT ALL ON SCHEMA public TO ${APP_NAME};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${APP_NAME};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${APP_NAME};
EOSQL
}

# Initialize Applications
init_app_db "lidarr" "$LIDARR_DB_PASSWORD"
init_app_db "sonarr" "$SONARR_DB_PASSWORD"
init_app_db "radarr" "$RADARR_DB_PASSWORD"
init_app_db "prowlarr" "$PROWLARR_DB_PASSWORD"

echo "✅ All initializations completed!"
