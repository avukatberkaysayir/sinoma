"""Creates word_suggestions table in Supabase via Management API."""
import json
import sys
try:
    import requests
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    import requests

ACCESS_TOKEN = ""   # set SUPABASE_ACCESS_TOKEN env var before running
PROJECT_REF = "pqyceostpukueydwuiut"
SERVICE_ROLE_KEY = ""  # set SUPABASE_SERVICE_ROLE_KEY env var before running

SQL = """
CREATE TABLE IF NOT EXISTS word_suggestions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  word TEXT NOT NULL,
  suggested_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE word_suggestions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone can suggest" ON word_suggestions;
CREATE POLICY "anyone can suggest" ON word_suggestions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "anyone can read suggestions" ON word_suggestions;
CREATE POLICY "anyone can read suggestions" ON word_suggestions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "anyone can delete suggestions" ON word_suggestions;
CREATE POLICY "anyone can delete suggestions" ON word_suggestions
  FOR DELETE USING (true);
"""

def run_sql_via_management_api():
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }
    resp = requests.post(url, headers=headers, json={"query": SQL}, timeout=30)
    print(f"Management API status: {resp.status_code}")
    print(resp.text[:500])
    return resp.status_code < 300

def test_insert():
    """Test that the table works by inserting and deleting a test row."""
    url = f"https://pqyceostpukueydwuiut.supabase.co/rest/v1/word_suggestions"
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    resp = requests.post(url, headers=headers, json={"word": "__test__"}, timeout=10)
    print(f"Insert test: HTTP {resp.status_code}")
    if resp.status_code in (200, 201):
        data = resp.json()
        row_id = data[0]["id"]
        # Delete test row
        del_resp = requests.delete(
            f"{url}?id=eq.{row_id}",
            headers=headers, timeout=10
        )
        print(f"Delete test row: HTTP {del_resp.status_code}")
        print("Table is working correctly.")
        return True
    else:
        print(f"Error: {resp.text[:300]}")
        return False

if __name__ == "__main__":
    print("Creating word_suggestions table...")
    ok = run_sql_via_management_api()
    if ok:
        print("\nTesting table...")
        test_insert()
    else:
        print("Management API failed. Trying direct insert to see if table already exists...")
        test_insert()
