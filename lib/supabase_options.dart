class SupabaseOptions {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pqyceostpukueydwuiut.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_L_qwvXbTI8URLvDHWUqApg_bgVlf9s1',
  );
}
