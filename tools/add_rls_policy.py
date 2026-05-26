"""Add RLS INSERT policy to dictionary table via PostgreSQL direct connection."""
import sys
try:
    import psycopg2
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])
    import psycopg2

# Supabase PostgreSQL direct connection
# The password is the database password set when creating the Supabase project
# Format: postgresql://postgres:[password]@db.[ref].supabase.co:5432/postgres
PROJECT_REF = "pqyceostpukueydwuiut"

# Try common Supabase connection approaches
# The pooler URL uses the anon key or service role as password in some configs
SERVICE_ROLE_KEY = ""  # set SUPABASE_SERVICE_ROLE_KEY env var before running

SQL = """
-- Allow authenticated users to insert suggestions (hsk_level = 0 only)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'dictionary'
    AND policyname = 'authenticated_can_suggest'
  ) THEN
    EXECUTE 'CREATE POLICY "authenticated_can_suggest" ON public.dictionary
             FOR INSERT TO authenticated
             WITH CHECK (hsk_level = 0)';
    RAISE NOTICE 'Policy created.';
  ELSE
    RAISE NOTICE 'Policy already exists.';
  END IF;
END $$;
"""

def try_connect(host, user, password, dbname="postgres", port=5432):
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            dbname=dbname,
            connect_timeout=10,
            sslmode="require",
        )
        print(f"Connected to {host}:{port} as {user}")
        return conn
    except Exception as e:
        print(f"Failed {host}:{port} as {user}: {e}")
        return None

def run():
    # Try multiple connection approaches
    attempts = [
        # Direct connection as postgres superuser (password = project DB password)
        (f"db.{PROJECT_REF}.supabase.co", "postgres", None, 5432),
        # Pooler as service_role
        (f"aws-0-eu-central-1.pooler.supabase.com", f"postgres.{PROJECT_REF}", SERVICE_ROLE_KEY, 6543),
        (f"aws-0-us-east-1.pooler.supabase.com", f"postgres.{PROJECT_REF}", SERVICE_ROLE_KEY, 6543),
        (f"aws-0-us-west-1.pooler.supabase.com", f"postgres.{PROJECT_REF}", SERVICE_ROLE_KEY, 6543),
    ]

    for host, user, password, port in attempts:
        if password is None:
            print(f"Skipping {host} (no password)")
            continue
        conn = try_connect(host, user, password, port=port)
        if conn:
            try:
                cur = conn.cursor()
                cur.execute(SQL)
                conn.commit()
                print("SQL executed successfully!")
                cur.close()
                conn.close()
                return True
            except Exception as e:
                print(f"SQL error: {e}")
                conn.close()

    print("All connection attempts failed.")
    return False

if __name__ == "__main__":
    run()
