import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/oracle_screen.dart';
import 'screens/qr_passport_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'screens/pharmacy_screen.dart';
import 'screens/blood_donation_screen.dart';
import 'providers/health_profile_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await NotificationService().initialize();
  runApp(const ProviderScope(child: CarelytixApp()));
}

class CarelytixApp extends StatelessWidget {
  const CarelytixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carelytix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppEntry(),
    );
  }
}

// ─── App Entry: Splash → Login → Main ─────────────────────────────────────────
class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;
  bool _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onComplete: () => setState(() => _splashDone = true));
    }
    if (!_loggedIn) {
      return LoginScreen(
          onLoginSuccess: () => setState(() => _loggedIn = true));
    }
    return _MainNav(
        onLogout: () => setState(() {
              _loggedIn = false;
            }));
  }
}

// ─── Main Navigation ──────────────────────────────────────────────────────────
class _MainNav extends ConsumerStatefulWidget {
  final VoidCallback onLogout;
  const _MainNav({required this.onLogout});
  @override
  ConsumerState<_MainNav> createState() => _MainNavState();
}

class _MainNavState extends ConsumerState<_MainNav>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<_NavItem> _items = const [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.map_outlined, Icons.map_rounded, 'Map'),
    _NavItem(Icons.document_scanner_outlined, Icons.document_scanner_rounded,
        'Oracle'),
    _NavItem(Icons.water_drop_outlined, Icons.water_drop_rounded, 'Donate'),
    _NavItem(Icons.qr_code_outlined, Icons.qr_code_rounded, 'Passport'),
    _NavItem(Icons.local_pharmacy_outlined, Icons.local_pharmacy_rounded,
        'Pharmacy'),
  ];

  void setTab(int i) => setState(() => _currentIndex = i);

  @override
  Widget build(BuildContext context) {
    final isDoctorMode = ref.watch(doctorModeProvider);

    Widget body;
    if (isDoctorMode && _currentIndex == 0) {
      body = const DoctorDashboardScreen();
    } else {
      final screens = [
        const HomeScreen(),
        const MapScreen(),
        const OracleScreen(),
        const BloodDonationScreen(),
        const QrPassportScreen(),
        const PharmacyScreen(),
      ];
      body = screens[_currentIndex];
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
            key: ValueKey(_currentIndex + (isDoctorMode ? 100 : 0)),
            child: body),
      ),
      bottomNavigationBar: _buildBottomNav(isDoctorMode),
    );
  }

  Widget _buildBottomNav(bool isDoctorMode) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Doctor mode indicator
          if (isDoctorMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              color: AppColors.deepNavy,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('DOCTOR MODE ACTIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onLogout,
                  child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Logout',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 10))),
                ),
              ]),
            ),
          NavigationBar(
            height: 60,
            selectedIndex: _currentIndex,
            onDestinationSelected: setTab,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primary.withOpacity(0.1),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: _items
                .map((item) => NavigationDestination(
                      icon: Icon(item.icon, size: 22),
                      selectedIcon: Icon(item.selectedIcon,
                          color: AppColors.primary, size: 22),
                      label: item.label,
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}
