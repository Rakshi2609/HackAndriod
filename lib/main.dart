import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/oracle_screen.dart';
import 'screens/qr_passport_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'screens/pharmacy_screen.dart';
import 'providers/health_profile_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await NotificationService().initialize();
  runApp(const ProviderScope(child: AntigravityApp()));
}

class AntigravityApp extends StatelessWidget {
  const AntigravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onComplete: () => setState(() => _splashDone = true));
    }
    return const _MainNav();
  }
}

class _MainNav extends ConsumerStatefulWidget {
  const _MainNav();

  @override
  ConsumerState<_MainNav> createState() => _MainNavState();
}

class _MainNavState extends ConsumerState<_MainNav> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _fabController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDoctorMode = ref.watch(doctorModeProvider);

    // Doctor mode shows doctor dashboard instead
    if (isDoctorMode && _currentIndex == 0) {
      return _buildScaffold(const DoctorDashboardScreen());
    }

    final screens = [
      const HomeScreen(),
      const MapScreen(),
      const OracleScreen(),
      const QrPassportScreen(),
      const PharmacyScreen(),
    ];

    return _buildScaffold(screens[_currentIndex]);
  }

  Widget _buildScaffold(Widget body) {
    final isDoctorMode = ref.watch(doctorModeProvider);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_currentIndex + (isDoctorMode ? 100 : 0)), child: body),
      ),
      bottomNavigationBar: _buildBottomNav(isDoctorMode),
    );
  }

  Widget _buildBottomNav(bool isDoctorMode) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: NavigationBar(
          height: 62,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withOpacity(0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(isDoctorMode ? Icons.medical_services_outlined : Icons.home_outlined),
              selectedIcon: Icon(isDoctorMode ? Icons.medical_services_rounded : Icons.home_rounded, color: AppColors.primary),
              label: isDoctorMode ? 'Dashboard' : 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded, color: AppColors.primary),
              label: 'Map',
            ),
            const NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner_rounded, color: AppColors.primary),
              label: 'Oracle',
            ),
            const NavigationDestination(
              icon: Icon(Icons.qr_code_outlined),
              selectedIcon: Icon(Icons.qr_code_rounded, color: AppColors.primary),
              label: 'Passport',
            ),
            const NavigationDestination(
              icon: Icon(Icons.local_pharmacy_outlined),
              selectedIcon: Icon(Icons.local_pharmacy_rounded, color: AppColors.primary),
              label: 'Pharmacy',
            ),
          ],
        ),
      ),
    );
  }
}
