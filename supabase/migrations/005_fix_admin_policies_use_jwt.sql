-- Fix: admin RLS policies queried `auth.users`, which the `authenticated` role
-- cannot SELECT. On the users table the "Admin can update all users" policy
-- (migration 004) is OR-evaluated alongside "Users can update own profile" for
-- every UPDATE; its auth.users subquery raised `42501: permission denied for
-- table users`, so EVERY profile save failed (no `true` policy short-circuits
-- an UPDATE the way it does for dictionary/config SELECT reads).
--
-- Switch the admin check to `auth.jwt() ->> 'email'`, which reads the signed JWT
-- claim with no table access. Same security (admin-only), no auth.users grant.

-- users: admin-can-update-all (added in 004)
DROP POLICY IF EXISTS "Admin can update all users" ON public.users;
CREATE POLICY "Admin can update all users"
  ON public.users FOR UPDATE TO authenticated
  USING      ((auth.jwt() ->> 'email') = 'berkaysayir@gmail.com')
  WITH CHECK ((auth.jwt() ->> 'email') = 'berkaysayir@gmail.com');

-- dictionary: admin-only modify (FOR ALL → also evaluated on SELECT)
DROP POLICY IF EXISTS "Only admins can modify dictionary" ON public.dictionary;
CREATE POLICY "Only admins can modify dictionary"
  ON public.dictionary FOR ALL TO authenticated
  USING      ((auth.jwt() ->> 'email') = 'berkaysayir@gmail.com')
  WITH CHECK ((auth.jwt() ->> 'email') = 'berkaysayir@gmail.com');

-- app_config: admin-only modify (FOR ALL → also evaluated on SELECT)
DROP POLICY IF EXISTS "Only admins can modify config" ON public.app_config;
CREATE POLICY "Only admins can modify config"
  ON public.app_config FOR ALL TO authenticated
  USING      ((auth.jwt() ->> 'email') = 'berkaysayir@gmail.com')
  WITH CHECK ((auth.jwt() ->> 'email') = 'berkaysayir@gmail.com');

-- Note: the videos admin policies were already migrated to auth.jwt() in the
-- live DB. schema.sql is updated to the same pattern for fresh applies.
