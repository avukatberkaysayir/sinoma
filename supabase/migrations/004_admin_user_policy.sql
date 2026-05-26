-- Sprint 9: Admin can update any user row (premium toggle, credit grants)
-- Regular users can still only update their own row via the existing policy.

CREATE POLICY "Admin can update all users"
  ON public.users FOR UPDATE TO authenticated
  USING  ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com')
  WITH CHECK ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com');
