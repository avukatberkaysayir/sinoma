-- Sprint 6: Stripe payment integration
-- Stores the Stripe customer ID so we can open the billing portal and handle subscription cancellation webhooks.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;

CREATE INDEX IF NOT EXISTS idx_users_stripe_customer
  ON public.users (stripe_customer_id)
  WHERE stripe_customer_id IS NOT NULL;
