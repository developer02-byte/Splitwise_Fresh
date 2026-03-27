import 'package:flutter/material.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';

class InviteShareSheet {
  static void show(BuildContext context, {required String groupName, required String token}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXL)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kSpacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: kSpacingL),
              Text(groupName, style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Invite friends to this group', style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: kSpacingXL),
              
              // Mock QR Code Block
              Container(
                padding: const EdgeInsets.all(kSpacingL),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadiusL),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(kRadiusM),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.grey.shade800),
                            const SizedBox(height: 8),
                            Text('Scan to Join', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpacingXL),
              
              const Text('Or share link', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: kSpacingM),
              
              // Share Link Button Row
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(kRadiusM),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: kSpacingM),
                        child: Text(
                          'splitease://invite/$token',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(kRadiusM)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: AppColors.success, content: Text('✓ Link copied to clipboard')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: kSpacingM),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        // Native share sheet logic
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening native Share Sheet...')));
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share Link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacingL),
            ],
          ),
        ),
      ),
    );
  }
}
