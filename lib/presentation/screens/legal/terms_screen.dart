import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ConstrainedPage(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveLayout.pagePadding(context)),
          child: const _TermsContent(),
        ),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Effective Date', 'May 2026'),
        _buildBody(
          'These Terms of Service ("Terms") govern your access to and use of '
          'Sinoma ("the App"), operated by the Sinoma team. '
          'By using the App, you agree to be bound by these Terms.',
        ),
        _buildSection('1. Eligibility', null),
        _buildBody(
          'You must be at least 13 years old to use the App. '
          'By creating an account, you confirm that you meet this requirement.',
        ),
        _buildSection('2. Account', null),
        _buildBullets([
          'You are responsible for keeping your account credentials secure',
          'You may not create accounts for others without their consent',
          'We reserve the right to suspend accounts that violate these Terms',
        ]),
        _buildSection('3. Subscriptions and Purchases', null),
        _buildBody(
          'Sinoma offers a free tier with ads and a Premium subscription. '
          'Premium subscriptions are billed monthly or annually through Google Play. '
          'Subscriptions automatically renew unless cancelled at least 24 hours before the end '
          'of the current billing period. You can manage and cancel subscriptions in your '
          'Google Play account settings.',
        ),
        _buildBullets([
          'Monthly plan: \$9.99/month',
          'Annual plan: \$69.99/year (save 42%)',
          'Prices may vary by region and are subject to change with notice',
          'No refunds are provided for partially used subscription periods, except as required by law',
        ]),
        _buildSection('4. Free Tier Limitations', null),
        _buildBullets([
          'Free users receive 5 AI dictionary credits per day, refreshed at midnight UTC',
          'Additional credits can be earned by watching rewarded ads',
          'Free users may see interstitial ads between video clips',
          'Game play limits apply to free users (10 games/day per game type)',
        ]),
        _buildSection('5. Content and Intellectual Property', null),
        _buildBody(
          'YouTube video content is embedded via the official YouTube IFrame API under '
          'YouTube\'s Terms of Service. All embedded videos comply with Creative Commons '
          'licensing requirements. The App does not download or re-host YouTube content.',
        ),
        _buildBody(
          'Self-hosted video content is licensed under Creative Commons (CC-BY or CC-BY-SA). '
          'Dictionary data is based on CC-CEDICT (public domain) and official HSK word lists.',
        ),
        _buildBody(
          'App design, code, brand, and original content are owned by Sinoma. '
          'You may not copy, distribute, or create derivative works from them.',
        ),
        _buildSection('6. User-Generated Content', null),
        _buildBody(
          'You may post content to the social feed (text, achievements, scores). '
          'By posting, you grant us a non-exclusive licence to display your content within the App. '
          'You must not post content that is abusive, illegal, or violates others\' rights. '
          'We reserve the right to remove content that violates these Terms.',
        ),
        _buildSection('7. Prohibited Uses', null),
        _buildBullets([
          'Reverse-engineering, decompiling, or extracting the App\'s source code',
          'Attempting to manipulate scores, credits, or subscription status through technical means',
          'Using the App to distribute spam or unsolicited commercial messages',
          'Impersonating other users or the Sinoma team',
          'Using automated tools (bots, scripts) to interact with the App',
        ]),
        _buildSection('8. Disclaimers and Limitation of Liability', null),
        _buildBody(
          'The App is provided "as is" without warranties of any kind. '
          'We do not guarantee that the App will be uninterrupted, error-free, or accurate. '
          'Language learning outcomes depend on your individual effort and study habits.',
        ),
        _buildBody(
          'To the maximum extent permitted by law, Sinoma shall not be liable '
          'for any indirect, incidental, or consequential damages arising from your use of the App.',
        ),
        _buildSection('9. Termination', null),
        _buildBody(
          'You may delete your account at any time in Settings → Account → Delete Account. '
          'We may terminate or suspend your account for violations of these Terms. '
          'Upon termination, your right to use the App ceases immediately.',
        ),
        _buildSection('10. Governing Law', null),
        _buildBody(
          'These Terms are governed by applicable law. '
          'Any disputes shall be resolved through binding arbitration, '
          'except where prohibited by local law.',
        ),
        _buildSection('11. Changes', null),
        _buildBody(
          'We may update these Terms. Continued use of the App after notice of changes '
          'constitutes acceptance of the updated Terms.',
        ),
        _buildSection('12. Contact', null),
        _buildBody('For questions about these Terms: legal@sinoma.app'),
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
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
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
        style: const TextStyle(
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
                        style: const TextStyle(
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
