import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BloodDonationScreen extends StatefulWidget {
  const BloodDonationScreen({super.key});
  @override
  State<BloodDonationScreen> createState() => _BloodDonationScreenState();
}

class _BloodDonationScreenState extends State<BloodDonationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String? _selectedBlood;
  bool _registered = false;
  String _myBlood = 'O+';

  final List<_Donor> _donors = [
    _Donor('Rahul M.', 'O+', 2.1, 'Available', 'Koramangala', '3 donations'),
    _Donor('Priya S.', 'AB-', 3.4, 'Available', 'Indiranagar', '7 donations'),
    _Donor('Arjun K.', 'B+', 0.8, 'Busy', 'HSR Layout', '1 donation'),
    _Donor('Meera R.', 'A+', 1.5, 'Available', 'Whitefield', '12 donations'),
    _Donor('Dev T.', 'O-', 4.2, 'Available', 'Marathahalli', '2 donations'),
    _Donor('Sneha L.', 'B-', 1.1, 'Available', 'Jayanagar', '5 donations'),
    _Donor('Karan V.', 'A-', 2.8, 'Available', 'Bellandur', '9 donations'),
  ];

  final _bgList = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<_Donor> get _filtered => _selectedBlood == null ? _donors : _donors.where((d) => d.bloodGroup == _selectedBlood).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: const Color(0xFF8B0000),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF6A0000), Color(0xFFEB5757), Color(0xFFFF8C8C)]),
                  ),
                ),
                // Decorative circles
                Positioned(top: -50, right: -50, child: _glow(220, Colors.white.withOpacity(0.05))),
                Positioned(bottom: -30, left: -40, child: _glow(160, Colors.white.withOpacity(0.04))),
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(color: Colors.white.withOpacity(0.4 * _pulseController.value + 0.2), width: 2.5),
                        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 20 + _pulseController.value * 10, spreadRadius: _pulseController.value * 4)],
                      ),
                      child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Blood Donation Hub', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const Text('Community • Care • Every Drop Counts', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                ])),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // SOS urgent card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6A0000), Color(0xFFEB5757)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Icon(Icons.sos_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🆘 URGENT: O- needed NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('City General Hospital · 0.8km · 2 units needed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📞 Connecting you to the hospital...'), backgroundColor: AppColors.danger)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Respond', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // Stats
              Row(children: [
                _statCard('247', 'Donors\nNearby', AppColors.danger, Icons.people_rounded),
                const SizedBox(width: 12),
                _statCard('12', 'Requests\nLive', AppColors.warning, Icons.campaign_rounded),
                const SizedBox(width: 12),
                _statCard('1.2K', 'Lives\nSaved', AppColors.mintGreen, Icons.favorite_rounded),
              ]),
              const SizedBox(height: 24),

              // Registration
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 400),
                crossFadeState: _registered ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: _buildRegisterCard(),
                secondChild: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.mintGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.mintGreen.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.mintGreen, size: 28),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('You are a registered donor! 🎉', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.mintGreen)),
                      Text('Blood Group: $_myBlood · Ready to save lives', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // Filter
              Row(children: [
                Text('Find Donors', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${_filtered.length} found', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _chip('All', _selectedBlood == null, () => setState(() => _selectedBlood = null), AppColors.primary),
                  ..._bgList.map((bg) => _chip(bg, _selectedBlood == bg, () => setState(() => _selectedBlood = bg), AppColors.danger)),
                ]),
              ),
              const SizedBox(height: 16),

              // Donors
              ..._filtered.map((d) => _DonorCard(donor: d)),
              const SizedBox(height: 100),
            ])),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestBlood(context),
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.sos_rounded, color: Colors.white),
        label: const Text('REQUEST BLOOD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.volunteer_activism_rounded, color: AppColors.danger, size: 20),
          SizedBox(width: 8),
          Text('Become a Donor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 6),
        const Text('One donation can save 3 lives.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: _bgList.map((bg) => GestureDetector(
          onTap: () => setState(() => _myBlood = bg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _myBlood == bg ? AppColors.danger : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _myBlood == bg ? AppColors.danger : Colors.grey.shade200),
            ),
            child: Text(bg, style: TextStyle(color: _myBlood == bg ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => setState(() => _registered = true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          icon: const Icon(Icons.favorite_rounded),
          label: const Text('Register as Donor'),
        )),
      ]),
    );
  }

  Widget _glow(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _statCard(String v, String l, Color c, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: c.withOpacity(0.09), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: c, size: 18),
      const SizedBox(height: 6),
      Text(v, style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900)),
      Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.3)),
    ]),
  ));

  Widget _chip(String label, bool sel, VoidCallback onTap, Color c) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: sel ? c : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? c : Colors.grey.shade200, width: 1.5)),
      child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
    ),
  );

  void _showRequestBlood(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🆘 Emergency Blood Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.danger)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Patient Name', prefixIcon: Icon(Icons.person_rounded))),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Hospital', prefixIcon: Icon(Icons.local_hospital_rounded))),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Units Needed (e.g. 2 units)', prefixIcon: Icon(Icons.water_drop_rounded))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🆘 Broadcast sent to 247 nearby donors!'), backgroundColor: AppColors.danger));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Broadcast to All Donors'),
            )),
          ]),
        ),
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  final _Donor donor;
  const _DonorCard({required this.donor});

  @override
  Widget build(BuildContext context) {
    final avail = donor.status == 'Available';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(child: Text(donor.bloodGroup, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 13)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(donor.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('📍 ${donor.location} · ${donor.distance}km', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('🩸 ${donor.donations}', style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: avail ? AppColors.mintGreen.withOpacity(0.1) : AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(donor.status, style: TextStyle(color: avail ? AppColors.mintGreen : AppColors.warning, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          if (avail) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📞 Contacting ${donor.name}...'), backgroundColor: AppColors.primary)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                child: const Text('Contact', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Donor {
  final String name, bloodGroup, status, location, donations;
  final double distance;
  const _Donor(this.name, this.bloodGroup, this.distance, this.status, this.location, this.donations);
}
