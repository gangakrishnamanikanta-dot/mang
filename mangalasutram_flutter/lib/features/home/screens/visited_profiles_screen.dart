import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../models/profile.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../services/home_service.dart';
import '../../../core/route_observer.dart';

class VisitedProfilesScreen extends StatefulWidget {
  const VisitedProfilesScreen({super.key});

  @override
  State<VisitedProfilesScreen> createState() => _VisitedProfilesScreenState();
}

class _VisitedProfilesScreenState extends State<VisitedProfilesScreen>
    with RouteAware {
  final _svc = HomeService.instance;
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returned from profile detail view — reload data
    setState(() => _loadData());
  }

  void _loadData() {
    _future = _svc.getVisitedProfiles(limit: 20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text(
          'Profiles You Visited',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<List<Profile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading visited profiles.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            );
          }

          final profiles = snapshot.data ?? [];
          if (profiles.isEmpty) {
            return Center(
              child: Text(
                "You haven't visited any profiles yet.",
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _loadData());
              await _future;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.7, // Taller cards
              ),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final score = 50;
                return _GridProfileCard(profile: profile, matchScore: score);
              },
            ),
          );
        },
      ),
    );
  }
}

class _GridProfileCard extends StatelessWidget {
  final Profile profile;
  final int matchScore;

  const _GridProfileCard({required this.profile, required this.matchScore});

  int get _age {
    if (profile.dateOfBirth == null) return 0;
    final dob = DateTime.tryParse(profile.dateOfBirth!);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final location = [
      profile.city,
      profile.state,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    final age = _age;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(profile: profile),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: profile.profilePhotoUrl != null
                      ? Image.network(
                          profile.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderIcon(gender: profile.gender),
                        )
                      : _PlaceholderIcon(gender: profile.gender),
                ),
              ),
              // Info
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.fullName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF1976D2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      age > 0 ? '$age yrs • $location' : location,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$matchScore% Match',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: matchScore >= 80
                            ? const Color(0xFF2E7D32)
                            : (matchScore >= 60
                                  ? const Color(0xFFF57C00)
                                  : const Color(0xFFC62828)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final String? gender;
  const _PlaceholderIcon({this.gender});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDECDA),
      child: Center(
        child: Icon(
          gender?.toLowerCase() == 'female' ? Icons.face_3 : Icons.face,
          size: 40,
          color: const Color(0xFFD4C4B5),
        ),
      ),
    );
  }
}
