import 'package:flutter/material.dart';
import '../../../../core/constants/dimensions.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policy', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: kSpacingS),
            Text('Last updated: March 26, 2026', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: kSpacingL),
            Text('1. Data Collection', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpacingS),
            Text('SplitEase collects minimal personal data required to manage shared expenses. This includes your name, email, and optionally a profile picture.',
              style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: kSpacingM),
            Text('2. Data Usage', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpacingS),
            Text('Your financial data (receipts, amounts, balances) is strictly shared only with users you explicitly invite to groups or add as friends.',
              style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: kSpacingM),
            Text('3. Data Retention & Deletion', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpacingS),
            Text('You may request account deletion at any time in the app. Note that if you owe money to others, deletion is blocked until debts are settled. Once deleted, your account is purged from our active databases, though historical ledgers in other users\' groups may retain an anonymized version of your record.',
              style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terms of Service', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: kSpacingS),
            Text('Last updated: March 26, 2026', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: kSpacingL),
            Text('1. Legal Disclaimer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpacingS),
            Text('SplitEase is a ledger application intended to help groups coordinate debts. We do not act as a bank, payment processor, or money transmitter. Any payments recorded in this app are user-made statements of settlement and are not legally binding financial transfers executed by SplitEase.',
              style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: kSpacingM),
            Text('2. Acceptable Use', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpacingS),
            Text('You agree not to use SplitEase for tracking illegal transactions, harassment, or spamming invitations. Accounts violating these terms will be suspended permanently.',
              style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
