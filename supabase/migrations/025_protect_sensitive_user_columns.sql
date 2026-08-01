-- 025_protect_sensitive_user_columns.sql
-- Security (2026-08-01 audit): the "Users can update own profile" RLS policy is
-- row-level, not column-level, so a signed-in user could write their own
-- is_premium / ai_credits / diamonds directly from the client
--   supabase.from('users').update({is_premium:true, ai_credits:9999}).eq('id', uid)
-- bypassing the grant/decrement RPCs entirely. This locks those value columns: a
-- normal client UPDATE can't change them (they're forced back to the old value).
--
-- Legitimate writers still work:
--   • service_role (edge functions) and the admin email bypass outright.
--   • grant_ai_credits / decrement_ai_credits are SECURITY DEFINER and set a
--     transaction-local flag the trigger honors, so credit accounting still runs.
-- hsk_level is intentionally NOT locked here — the HSK placement test writes it
-- from the client and it carries no monetary value; tightening it is a separate
-- (behavioral) change.

CREATE OR REPLACE FUNCTION public.protect_sensitive_user_cols()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Trusted writers pass through untouched.
  IF auth.role() = 'service_role'
     OR COALESCE(auth.jwt() ->> 'email', '') = 'berkaysayir@gmail.com'
     OR current_setting('app.credit_rpc', true) = '1' THEN
    RETURN NEW;
  END IF;
  -- Everyone else: value columns can't move. Silently pin them to the old value
  -- so an otherwise-valid profile update (display_name, username, …) still lands.
  NEW.is_premium := OLD.is_premium;
  NEW.ai_credits := OLD.ai_credits;
  NEW.diamonds   := OLD.diamonds;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_user_cols ON public.users;
CREATE TRIGGER protect_user_cols
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.protect_sensitive_user_cols();

-- Credit RPCs: same behavior, plus the flag that lets them past the trigger.
CREATE OR REPLACE FUNCTION public.grant_ai_credits(p_amount integer DEFAULT 10)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  new_credits     INTEGER;
  max_credits CONSTANT INTEGER := 50;
BEGIN
  PERFORM set_config('app.credit_rpc', '1', true);
  UPDATE public.users SET ai_credits = LEAST(ai_credits + p_amount, max_credits)
  WHERE id = auth.uid() RETURNING ai_credits INTO new_credits;
  IF new_credits IS NULL THEN RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0001'; END IF;
  RETURN new_credits;
END;
$function$;

CREATE OR REPLACE FUNCTION public.decrement_ai_credits()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  current_credits INTEGER;
  new_credits     INTEGER;
BEGIN
  PERFORM set_config('app.credit_rpc', '1', true);
  SELECT ai_credits INTO current_credits FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF current_credits IS NULL THEN RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0001'; END IF;
  IF current_credits <= 0 THEN RAISE EXCEPTION 'AI credit quota exceeded' USING ERRCODE = 'P0001'; END IF;
  new_credits := current_credits - 1;
  UPDATE public.users SET ai_credits = new_credits WHERE id = auth.uid();
  RETURN new_credits;
END;
$function$;
