-- 027_lock_hsk_level.sql
-- Security (2026-08-01 audit): hsk_level was writable straight from the client
-- (updateHskLevel → users.update), so a user could set any level 1..6 (or an
-- out-of-range value) and unlock content / skew the level leaderboard filter.
-- Lock it in the same trigger as is_premium/ai_credits/diamonds, and route the
-- legitimate HSK-placement write through a validating RPC.

CREATE OR REPLACE FUNCTION public.protect_sensitive_user_cols()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF auth.role() = 'service_role'
     OR COALESCE(auth.jwt() ->> 'email', '') = 'berkaysayir@gmail.com'
     OR current_setting('app.credit_rpc', true) = '1'
     OR current_setting('app.hsk_rpc', true) = '1' THEN
    RETURN NEW;
  END IF;
  NEW.is_premium := OLD.is_premium;
  NEW.ai_credits := OLD.ai_credits;
  NEW.diamonds   := OLD.diamonds;
  NEW.hsk_level  := OLD.hsk_level;
  RETURN NEW;
END;
$function$;

-- Validating writer: level must be 1..6; only the caller's own row.
CREATE OR REPLACE FUNCTION public.set_hsk_level(p_level integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  new_level integer;
BEGIN
  IF p_level IS NULL OR p_level < 1 OR p_level > 6 THEN
    RAISE EXCEPTION 'hsk_level out of range (1..6)' USING ERRCODE = 'P0001';
  END IF;
  PERFORM set_config('app.hsk_rpc', '1', true);
  UPDATE public.users SET hsk_level = p_level
  WHERE id = auth.uid() RETURNING hsk_level INTO new_level;
  IF new_level IS NULL THEN RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0001'; END IF;
  RETURN new_level;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_hsk_level(integer) TO authenticated;
