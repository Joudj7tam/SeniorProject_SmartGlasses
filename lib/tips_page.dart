/// TipsPage:
/// Displays eye care tips, latest news, and protection guidance.
/// Includes sections for daily tips, news carousel, and feature highlights.
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'smart_bottom_nav.dart';
import 'dart:async';

import 'main.dart';
import 'settings_page.dart';
import 'notifications_page.dart';
import 'progress_page.dart';

class TipsPage extends StatelessWidget {
  final String mainAccountId;
  final String firebaseUid;
  final String formId;

  const TipsPage({
    super.key,
    required this.mainAccountId,
    required this.firebaseUid,
    required this.formId,
  });

  void _openProgress(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressPage(
          userId: mainAccountId,
          firebaseUid: firebaseUid,
          formId: formId,
          onBackRequested: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TipsPage(
                  mainAccountId: mainAccountId,
                  firebaseUid: firebaseUid,
                  formId: formId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SmartProgressFab(
        selectedIndex: 4,
        onTap: () => _openProgress(context),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: isDark
                ? [
                    const Color(0xFF1A2E2C),
                    const Color(0xFF1A1A1A),
                    const Color(0xFF121212),
                  ]
                : [
                    const Color(0xFF8DCAC3),
                    const Color(0xFFEAF6F4),
                    const Color(0xFFFFF8F0),
                  ],
            stops: const [0.0, 0.50, 1.5],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 18),
                const HeaderSection(),
                const SizedBox(height: 18),
                const TipsSearchBar(),
                const SizedBox(height: 28),
                const DailyTipCard(),
                const SizedBox(height: 24),
                const LatestNewsSection(),
                const SizedBox(height: 24),
                const ProtectionSection(),
                const SizedBox(height: 24),
                const AboutSection(),
                const SizedBox(height: 150),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SmartBottomNav(
        selectedIndex: 4,

        onHomeTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(
                mainAccountId: mainAccountId,
                firebaseUid: firebaseUid,
              ),
            ),
          );
        },

        onSettingsTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsPage(
                mainAccountId: mainAccountId,
                firebaseUid: firebaseUid,
                smartLightEnabled: true,
                smartLightIntensity: 0.95,
                smartLightColor: const Color(0xFF06D6A0),
                onSmartLightToggle: (_) {},
                glassesLink: ValueNotifier({
                  'user_id': null,
                  'form_id': null,
                  'name': null,
                  'deviceId': null,
                }),
                onRequestLink: () {},
                activeFormId: formId,
              ),
            ),
          );
        },

        onProgressTap: () => _openProgress(context),

        onAlertsTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsPage(
                userId: mainAccountId,
                firebaseUid: firebaseUid,
                formId: formId,
              ),
            ),
          );
        },

        onTipsTap: () {
          // Already on Tips page
        },
      ),
    );
  }
}

// Shared card style used across the page
BoxDecoration cardStyle(Color color, {Color? borderColor}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: borderColor ?? const Color(0xFFf4efea),
      width: 1.5,
    ),
  );
}

/// Header section: shows page title and quick description
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 21,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    "Tips & News",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Learn, protect, and improve your eye health",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.54),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search bar: allows users to search tips, news, and content
class TipsSearchBar extends StatelessWidget {
  const TipsSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 38,
        child: TextField(
          decoration: InputDecoration(
            hintText: "Search tips, news, and more...",
            hintStyle: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Daily tip card: displays a quick eye-care tip for users
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Daily Tip",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF2EC4B6).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: const Icon(
                    Icons.tips_and_updates,
                    color: Color(0xFF2EC4B6),
                    size: 36,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "20-20-20 Rule",
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2EC4B6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Every 20 minutes, look at something 20 feet away for 20 seconds.",
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  color: Color(0xFF2EC4B6),
                  size: 40,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Latest news section: fetches and displays eye health news with auto-sliding carousel
class LatestNewsSection extends StatefulWidget {
  const LatestNewsSection({super.key});

  @override
  State<LatestNewsSection> createState() => _LatestNewsSectionState();
}

class _LatestNewsSectionState extends State<LatestNewsSection> {
  final PageController _pageController = PageController();
  late Future<List<dynamic>> _newsFuture;

  int currentIndex = 0;
  Timer? timer;

  final String apiKey = "7e86fab528d94dac9985bdf6c6d5136e";

  @override
  void initState() {
    super.initState();
    _newsFuture = fetchEyeNews();
  }

  Future<List<dynamic>> fetchEyeNews() async {
    final url = Uri.parse(
      "https://newsapi.org/v2/everything?q=eye%20health%20OR%20digital%20eye%20strain%20OR%20blue%20light&language=en&pageSize=5&apiKey=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["articles"];
    } else {
      throw Exception("Failed to load news");
    }
  }

  void startAutoSlide(int length) {
    if (timer != null) return;

    timer = Timer.periodic(const Duration(seconds: 4), (Timer t) {
      if (!_pageController.hasClients || length <= 1) return;

      final nextIndex = (currentIndex + 1) % length;

      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<List<dynamic>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  "Loading latest news...",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox();
          }

          final newsList = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            startAutoSlide(newsList.length);
          });

          final cs = Theme.of(context).colorScheme;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Latest News",
                    style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  const Text(
                    "View all",
                    style: TextStyle(color: Color(0xFF2EC4B6)),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 145,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: newsList.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final article = newsList[index];

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF2EC4B6).withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              article["urlToImage"] ??
                                  "https://images.unsplash.com/photo-1585832770485-e68a5dbfad52?q=80&w=1200",
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article["title"] ?? "Eye Health News",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: cs.onSurface,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  article["description"] ??
                                      "Read the latest updates about eye health.",
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: cs.onSurface.withValues(alpha: 0.54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  newsList.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentIndex == index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? const Color(0xFF2EC4B6)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

/// Protection section: shows simple actions to protect eye health
class ProtectionSection extends StatelessWidget {
  const ProtectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "How to Protect Your Eyes",
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const Text(
                "View all",
                style: TextStyle(color: Color(0xFF2EC4B6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: ProtectCard(
                    icon: Icons.airline_seat_recline_extra,
                    title: "Take Regular Breaks",
                    description: "Rest your eyes every 20 minutes to reduce strain.",
                    iconColor: Color(0xFFf4bb76),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: ProtectCard(
                    icon: Icons.water_drop,
                    title: "Stay Hydrated",
                    description: "Drink enough water to keep your eyes moist.",
                    iconColor: Color(0xFF6bada0),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: ProtectCard(
                    icon: Icons.lightbulb,
                    title: "Good Lighting",
                    description: "Use natural or soft lighting to reduce fatigue.",
                    iconColor: Color(0xFF1d4774),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable card: displays an icon, title, and short description
class ProtectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  const ProtectCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2EC4B6).withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 6),

          CircleAvatar(
            radius: 28,
            backgroundColor: iconColor,
            child: Icon(icon, color: Colors.white, size: 26),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
              color: cs.onSurface,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// About section: explains app features and benefits
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  Widget _featureItem(BuildContext context, IconData icon, String title, String subtitle) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF2EC4B6), size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                height: 1.25,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.35,
                color: cs.onSurface.withValues(alpha: 0.54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider(BuildContext context) {
    return Container(
      height: 95,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFF2EC4B6).withValues(alpha: 0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About CLIPVIEW",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF2EC4B6).withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    "assets/images/glasses.png",
                    width: 170,
                    height: 120,
                    fit: BoxFit.fill,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Get the most out of CLIPVIEW",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Learn how to use your device and app to improve your eye health every day.",
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: cs.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF2EC4B6).withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _featureItem(context, Icons.verified_user_outlined, "Privacy First", "Camera-free by design"),
                _verticalDivider(context),
                _featureItem(context, Icons.attach_file, "Clip-On Design", "Easy to attach and use"),
                _verticalDivider(context),
                _featureItem(context, Icons.battery_full, "Long Battery", "All-day monitoring on a single charge"),
                _verticalDivider(context),
                _featureItem(context, Icons.bar_chart, "Smart Insights", "AI-powered personalization"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
