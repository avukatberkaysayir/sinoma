class SupabaseOptions {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'REPLACE_WITH_SUPABASE_URL',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'REPLACE_WITH_SUPABASE_ANON_KEY',
  );
}
