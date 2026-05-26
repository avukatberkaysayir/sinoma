"""Add RLS INSERT policy via Supabase Session Pooler (uses service role key as password)."""
import psycopg2

PROJECT_REF = "pqyceostpukueydwuiut"
SERVICE_ROLE_KEY = ""  # set SUPABASE_SERVICE_ROLE_KEY env var before running

SQL_CHECK = "SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'dictionary' ORDER BY policyname;"

SQL_POLICY = """
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'dictionary'
    AND policyname = 'authenticated_can_suggest'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY "authenticated_can_suggest" ON public.dictionary
      FOR INSERT TO authenticated
      WITH CHECK (hsk_level = 0)
    $sql$;
    RAISE NOTICE 'Policy created.';
  ELSE
    RAISE NOTICE 'Policy already exists.';
  END IF;
END $$;
"""

def try_pooler(region):
    host = f"aws-0-{region}.pooler.supabase.com"
    user = f"postgres.{PROJECT_REF}"
    # Session pooler uses port 5432, transaction pooler uses 6543
    for port in [5432, 6543]:
        print(f"Trying {host}:{port}...")
        try:
            conn = psycopg2.connect(
                host=host,
                port=port,
                user=user,
                password=SERVICE_ROLE_KEY,
                dbname="postgres",
                connect_timeout=10,
                sslmode="require",
            )
            print(f"Connected to {host}:{port}")
            return conn
        except Exception as e:
            print(f"  Failed: {e}")
    return None

def run():
    regions = [
        "eu-central-1",
        "us-east-1",
        "us-west-1",
        "ap-southeast-1",
        "ap-northeast-1",
    ]

    conn = None
    for region in regions:
        conn = try_pooler(region)
        if conn:
            break

    if not conn:
        print("\nAll pooler attempts failed.")
        print("Trying direct DB connection...")
        try:
            conn = psycopg2.connect(
                host=f"db.{PROJECT_REF}.supabase.co",
                port=5432,
                user="postgres",
                password=SERVICE_ROLE_KEY,
                dbname="postgres",
                connect_timeout=10,
                sslmode="require",
            )
            print("Direct DB connection succeeded!")
        except Exception as e:
            print(f"Direct DB also failed: {e}")
            return False

    cur = conn.cursor()

    # Show current policies
    print("\nCurrent RLS policies on dictionary table:")
    cur.execute(SQL_CHECK)
    rows = cur.fetchall()
    if rows:
        for row in rows:
            print(f"  {row[0]} ({row[1]}): {row[2]}")
    else:
        print("  (none)")

    # Add INSERT policy
    print("\nAdding INSERT policy...")
    cur.execute(SQL_POLICY)
    conn.commit()
    print("Done!")

    # Verify
    print("\nPolicies after migration:")
    cur.execute(SQL_CHECK)
    for row in cur.fetchall():
        print(f"  {row[0]} ({row[1]}): {row[2]}")

    cur.close()
    conn.close()
    return True

if __name__ == "__main__":
    run()
