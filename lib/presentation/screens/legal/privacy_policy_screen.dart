import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ConstrainedPage(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveLayout.pagePadding(context)),
          child: const _PolicyContent(),
        ),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Effective Date', 'May 2026'),
        _buildBody(
          'Sinoma ("we", "us", "our") is committed to protecting your privacy. '
          'This Privacy Policy explains how we collect, use, and safeguard your information '
          'when you use our mobile application and related services.',
        ),
        _buildSection('1. Information We Collect', null),
        _buildBullets([
          'Account data: display name, email address, profile photo (from Google Sign-In or provided by you)',
          'Learning data: HSK level, words learned, videos watched, quiz answers',
          'Usage analytics: screen views, feature interactions, session duration (Vercel Analytics)',
          'Device data: device type and browser info',
          'Purchase data: subscription status (verified server-side; we do not store payment card details)',
        ]),
        _buildSection('2. How We Use Your Information', null),
        _buildBullets([
          'To provide and personalise your learning experience',
          'To track your progress and award achievements',
          'To send streak reminders and game challenge notifications (opt-out available)',
          'To measure and improve app performance via Vercel Analytics',
          'To display relevant advertisements to free users (web-based ads)',
          'To verify premium subscriptions and prevent fraud',
        ]),
        _buildSection('3. Data Sharing', null),
        _buildBody(
          'We do not sell your personal data. We share data only with the following categories '
          'of service providers under strict data processing agreements:',
        ),
        _buildBullets([
          'Supabase (database, authentication, realtime)',
          'Vercel (hosting and analytics)',
          'Google Gemini API (AI explanations — only the word and sentence you tap are sent)',
        ]),
        _buildSection('4. Your Rights (GDPR)', null),
        _buildBody(
          'If you are located in the European Economic Area, you have the following rights '
          'under the General Data Protection Regulation (GDPR):',
        ),
        _buildBullets([
          'Right of access: request a copy of your data (use "Export My Data" in Settings)',
          'Right to erasure: request deletion of your account and all associated data (use "Delete My Account" in Settings)',
          'Right to rectification: update your display name in your profile',
          'Right to object to processing: opt out of analytics in Settings → Privacy',
          'Right to data portability: your export includes all personal data in JSON format',
        ]),
        _buildBody(
          'For GDPR requests, contact us at privacy@sinoma.app. '
          'We will respond within 30 days.',
        ),
        _buildSection('5. Data Retention', null),
        _buildBody(
          'We retain your account data for as long as your account is active. '
          'Deleted accounts are purged within 30 days. '
          'Analytics data is retained for 12 months.',
        ),
        _buildSection('6. Advertising', null),
        _buildBody(
          'A web-based subscription model is used for premium features. '
          'Premium subscribers have access to all features without restrictions.',
        ),
        _buildSection('7. Children\'s Privacy', null),
        _buildBody(
          'Sinoma is not directed at children under 13. '
          'We do not knowingly collect personal information from children under 13. '
          'If you believe a child has provided us with personal data, '
          'please contact us at privacy@sinoma.app so we can delete it.',
        ),
        _buildSection('8. Security', null),
        _buildBody(
          'All data is transmitted over HTTPS/TLS. '
          'Supabase Row Level Security (RLS) ensures each user can only read and write their own data. '
          'AI credits are modified exclusively by server-side PostgreSQL functions '
          'to prevent client-side manipulation.',
        ),
        _buildSection('9. Changes to This Policy', null),
        _buildBody(
          'We may update this Privacy Policy from time to time. '
          'When we do, we will update the "Effective Date" at the top and notify you '
          'via the app on next launch.',
        ),
        _buildSection('10. Contact', null),
        _buildBody('For privacy questions: privacy@sinoma.app'),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.onSurface,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildBullets(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: AppColors.primary, fontSize: 14)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
