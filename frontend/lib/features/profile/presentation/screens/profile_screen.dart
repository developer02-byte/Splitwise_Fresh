import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'personal_analytics_screen.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Profile & Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: profileState.when(
        loading: () => const _ProfileSkeleton(),
        error: (err, _) => Center(child: Text('Failed to load profile', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        data: (profile) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Identity Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: kSpacingL),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: kSpacingM),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                    boxShadow: [
                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 24, offset: const Offset(0, 12))
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 2),
                        ),
                      const SizedBox(height: 24),
                      Text(profile.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(profile.email, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 200,
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditProfileDialog(context, ref, profile),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit Identity', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // ── Settings List ──
              _buildSectionHeader(context, 'Preferences'),
              _buildSettingsGroup(context, isDark, [
                _SettingsTile(
                  icon: Icons.payments_rounded,
                  title: 'Default Currency',
                  trailing: Text(profile.defaultCurrency, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  onTap: () => _showCurrencyPicker(context, ref, profile),
                ),
                _SettingsTile(
                  icon: Icons.public_rounded,
                  title: 'Timezone',
                  trailing: Text(profile.timezone, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  onTap: () => _showTimezonePicker(context, ref, profile),
                ),
                _SettingsTile(
                  icon: Icons.insights_rounded,
                  title: 'Personal Analytics',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalAnalyticsScreen())),
                ),
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => context.push('/notifications'),
                ),
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode',
                  trailing: Switch(
                    value: ref.watch(themeNotifierProvider) == ThemeMode.dark || 
                          (ref.watch(themeNotifierProvider) == ThemeMode.system && isDark), 
                    onChanged: (val) => ref.read(themeNotifierProvider.notifier).toggleTheme(val), 
                    activeColor: Theme.of(context).colorScheme.primary
                  ),
                  showDivider: profile.provider == 'email',
                ),
                if (profile.provider == 'email')
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () => context.push('/change-password'),
                    showDivider: false,
                  )
                else
                  _SettingsTile(
                    icon: profile.provider == 'google' ? Icons.g_mobiledata_rounded : Icons.apple_rounded,
                    title: 'Signed in with \${(profile.provider as String)[0].toUpperCase()}\${(profile.provider as String).substring(1)}',
                    trailing: const SizedBox.shrink(),
                    showDivider: false,
                  ),
              ]),

              const SizedBox(height: kSpacingL),

              _buildSectionHeader(context, 'About & Legal'),
              _buildSettingsGroup(context, isDark, [
                _SettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => context.push('/legal/privacy'),
                ),
                _SettingsTile(
                  icon: Icons.description_rounded,
                  title: 'Terms of Service',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => context.push('/legal/terms'),
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: kSpacingXL),

              // ── Account Actions ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpacingL),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  onPressed: () => _showLogoutConfirm(context, ref),
                  child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpacingL),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  onPressed: () => _showDeleteAccountConfirm(context, ref),
                  child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, bool isDark, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kSpacingL),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, dynamic profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    final emailCtrl = TextEditingController(text: profile.email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Identity', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
            const SizedBox(height: 16),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address'), enabled: false),
            const SizedBox(height: 16),
            const Text('Avatar changes take effect immediately after saving.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(profileNotifierProvider.notifier).updateProfile(newName: nameCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Identity updated')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, dynamic profile) {
    final currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'CAD', 'AUD'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Select Default Currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...currencies.map((c) => ListTile(
            title: Text(c),
            trailing: profile.defaultCurrency == c ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () {
              ref.read(profileNotifierProvider.notifier).updateProfile(newCurrency: c);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showTimezonePicker(BuildContext context, WidgetRef ref, dynamic profile) {
    final timezones = [
      'UTC', 'America/New_York', 'America/Los_Angeles', 'Europe/London', 
      'Europe/Berlin', 'Asia/Tokyo', 'Asia/Kolkata', 'Australia/Sydney'
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Timezone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...timezones.map((tz) => ListTile(
              title: Text(tz),
              trailing: profile.timezone == tz ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(profileNotifierProvider.notifier).updateProfile(newTimezone: tz);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirm(BuildContext context, WidgetRef ref) {
    final verifyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isMatch = verifyCtrl.text == 'DELETE';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Account?', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Are you sure you want to permanently delete your account? This will hide your details from friends. You must have \$0 balances across all groups to proceed.'),
                const SizedBox(height: 16),
                const Text('Type "DELETE" below to confirm:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: verifyCtrl,
                  decoration: const InputDecoration(hintText: 'DELETE', border: OutlineInputBorder()),
                  onChanged: (val) => setState(() {}),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: !isMatch ? null : () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(profileNotifierProvider.notifier).deleteAccount();
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  } catch (e) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (errCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Cannot Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: Text(e.toString()),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(errCtx), child: const Text('Understood'))
                          ],
                        )
                      );
                    }
                  }
                },
                child: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          trailing: trailing,
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        if (showDivider)
          Divider(height: 1, indent: 64, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ],
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    final highlight = isDark ? const Color(0xFF334155) : Colors.white;

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: const CircleAvatar(radius: 46)),
          const SizedBox(height: 20),
          Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 150, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 10),
          Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 100, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))),
        ],
      ),
    );
  }
}
