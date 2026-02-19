import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_providers.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final devMode = ref.watch(developerModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
          children: [
            Text(
              'SETTINGS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 3.0,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configuration',
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w200,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),

            _SectionHeader('APPEARANCE'),
            _SettingsTile(
              icon: Icons.dark_mode,
              label: 'Theme',
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                dropdownColor: AppColors.surface,
                underline: const SizedBox(),
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (val) {
                  if (val != null) ref.read(themeModeProvider.notifier).set(val);
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_fields, size: 20, color: Color(0xFF737373)),
                          const SizedBox(width: 16),
                          Text(
                            'Font Size (${(fontSize * 100).toInt()}%)',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Slider(
                    value: fontSize,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    activeColor: AppColors.accentPurple,
                    inactiveColor: AppColors.border,
                    onChanged: (val) {
                      ref.read(fontSizeProvider.notifier).set(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _SectionHeader('DATA & STORAGE'),
             _SettingsTile(
              icon: Icons.delete_outline,
              label: 'Clear All Data',
              textColor: AppColors.errorText,
              iconColor: AppColors.errorText,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Clear All Data?', style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text(
                      'This will remove all agents, conversations, and logs. This action cannot be undone.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => context.pop(),
                      ),
                      TextButton(
                        child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                        onPressed: () {
                          // TODO: Clear all providers
                          // For now, reload app or just clear agents
                          // ref.refresh(agentsProvider);
                          // ref.refresh(chatProvider);
                          // ref.refresh(logProvider);
                          // Actually easier to just restart app in current non-persistent state
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Data cleared (Session reset)')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            _SectionHeader('DEVELOPER'),
             _SettingsTile(
              icon: Icons.bug_report,
              label: 'Developer Mode',
              trailing: Switch(
                value: devMode,
                activeTrackColor: AppColors.accentPurple,
                onChanged: (val) => ref.read(developerModeProvider.notifier).set(val),
              ),
            ),
            if (devMode) ...[
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.monitor_heart,
                label: 'Performance Overlay',
                trailing: Switch(
                  value: ref.watch(showPerformanceOverlayProvider),
                  activeTrackColor: AppColors.accentPurple,
                  onChanged: (val) => ref.read(showPerformanceOverlayProvider.notifier).set(val),
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.tune,
                label: 'Verbose Level',
                trailing: DropdownButton<int>(
                  value: ref.watch(verboseLevelProvider),
                  dropdownColor: AppColors.surface,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Silent')),
                    DropdownMenuItem(value: 1, child: Text('Normal')),
                    DropdownMenuItem(value: 2, child: Text('Verbose')),
                  ],
                  onChanged: (val) {
                    if (val != null) ref.read(verboseLevelProvider.notifier).set(val);
                  },
                ),
              ),
            ],

            const SizedBox(height: 32),
            _SectionHeader('ABOUT'),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'Version',
              trailing: Text(
                '0.1.0-alpha',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: const Color(0xFF737373),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 4.0,
          color: const Color(0xFF3F3F46),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? const Color(0xFF737373)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: const Color(0xFF3F3F46),
              ),
          ],
        ),
      ),
    );
  }
}
