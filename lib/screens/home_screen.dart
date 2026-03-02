import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_profile_provider.dart';
import '../models/health_profile.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(healthProfileProvider);
    ref.watch(doctorModeProvider); // watch for reactivity

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D1B2A), Color(0xFF1565C0), Color(0xFF2D9CDB)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(top: -30, right: -30, child: _circle(180, Colors.white.withOpacity(0.05))),
                    Positioned(bottom: -20, left: -20, child: _circle(120, Colors.white.withOpacity(0.04))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.mintGreen.withOpacity(0.3),
                              child: Text(profile.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Good ${_greeting()}!', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              Text(profile.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            ]),
                          ]),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.shield_rounded, color: AppColors.mintGreen, size: 16),
                              const SizedBox(width: 6),
                              Text(profile.hashedId, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Mode toggle
                _ModeToggle(),
                const SizedBox(height: 24),

                // Health vitals card
                _VitalsCard(profile: profile),
                const SizedBox(height: 20),

                // Quick actions
                Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: const [
                    _QuickActionCard(icon: Icons.map_rounded, label: 'Find Hospital', color: AppColors.primary, tabIndex: 1),
                    _QuickActionCard(icon: Icons.document_scanner_rounded, label: 'Scan Rx', color: AppColors.mintGreen, tabIndex: 2),
                    _QuickActionCard(icon: Icons.qr_code_rounded, label: 'QR Passport', color: Color(0xFF7B2FBE), tabIndex: 3),
                    _QuickActionCard(icon: Icons.local_pharmacy_rounded, label: 'Pharmacy', color: AppColors.warning, tabIndex: 4),
                  ],
                ),
                const SizedBox(height: 20),

                // Digital prescription vault
                _PrescriptionVault(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _ModeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoctorMode = ref.watch(doctorModeProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: _toggleBtn('Patient View', !isDoctorMode, Icons.person_rounded, () => ref.read(doctorModeProvider.notifier).state = false, context)),
        Expanded(child: _toggleBtn('Doctor View', isDoctorMode, Icons.medical_services_rounded, () => ref.read(doctorModeProvider.notifier).state = true, context)),
      ]),
    );
  }

  Widget _toggleBtn(String label, bool active, IconData icon, VoidCallback onTap, BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primary : AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  final HealthProfile profile;
  const _VitalsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF2D9CDB)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Health Vitals', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 16),
        Row(children: [
          _vital('🩸', '${profile.lastGlucoseReading}', 'mg/dL', 'Glucose'),
          _divider(),
          _vital('❤️', '78', 'BPM', 'Heart Rate'),
          _divider(),
          _vital('💊', '3', 'Today', 'Medicines'),
        ]),
      ]),
    );
  }

  Widget _vital(String emoji, String value, String unit, String label) {
    return Expanded(child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        TextSpan(text: ' $unit', style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ])),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]));
  }

  Widget _divider() => Container(width: 1, height: 48, color: Colors.white.withOpacity(0.2));
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int tabIndex;
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate via bottom nav — raise to root
        final navState = context.findAncestorStateOfType<_MainShellState>();
        navState?.setTab(tabIndex);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ]),
      ),
    );
  }
}

class _PrescriptionVault extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescription = ref.watch(digitalPrescriptionProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text('Digital Vault', style: Theme.of(context).textTheme.titleMedium),
        ]),
        const SizedBox(height: 12),
        if (prescription == null)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 8),
              Text('No prescriptions yet', style: TextStyle(color: AppColors.textSecondary)),
              Text('Doctor will push one during consultation', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          ))
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.mintGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.mintGreen.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified_rounded, color: AppColors.mintGreen, size: 16),
                const SizedBox(width: 6),
                const Text('Verified Digital Prescription', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.mintGreen)),
              ]),
              const SizedBox(height: 8),
              Text(prescription, style: const TextStyle(fontSize: 13, height: 1.5)),
            ]),
          ),
      ]),
    );
  }
}

// Export the state so QuickActionCard can navigate
class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void setTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) => widget.build(context, _currentIndex, setTab);
}

class MainShell extends StatefulWidget {
  final Widget Function(BuildContext, int, void Function(int)) build;
  const MainShell({super.key, required this.build});

  @override
  State<MainShell> createState() => _MainShellState();
}
