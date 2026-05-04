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

 @override
Widget build(BuildContext context) {
  return Scaffold(
  extendBody: true,
  backgroundColor: Colors.transparent,
  body: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Color(0xFF8DCAC3),
          Color(0xFFEAF6F4),
          Color(0xFFFFF8F0),
        ],
        stops: [0.0, 0.50, 1.5],
      ),
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: const [
            SizedBox(height: 18),
            HeaderSection(),
            SizedBox(height: 18),
            SearchBar(),
            SizedBox(height: 28),
            DailyTipCard(),
            SizedBox(height: 24),
            LatestNewsSection(),
            SizedBox(height: 24),
            ProtectionSection(),
            SizedBox(height: 24),
            AboutSection(),
            SizedBox(height: 100),
          ],
        ),
      ),
    ),
  ),
  bottomNavigationBar: SmartBottomNav(
  selectedIndex: 4,
  onItemTap: (index) {
    if (index == 4) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            mainAccountId: mainAccountId,
            firebaseUid: firebaseUid,
          ),
        ),
      );
    }

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            mainAccountId: mainAccountId,
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
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProgressPage(
            selectedForHome: {},
            onToggleForHome: (_) {},
            userId: mainAccountId,
            formId: formId,
          ),
        ),
      );
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsPage(
            userId: mainAccountId,
            formId: formId,
          ),
        ),
      );
    }
  },
),
);
}
}
BoxDecoration cardStyle(
  Color color, {
  Color? borderColor,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: borderColor ?? const Color(0xFFf4efea), // default
      width: 1.5,
    ),
  );
}
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tips & News",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Learn, protect, and improve your eye health",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.notifications_none, size: 28),
        ],
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 38,
        child: TextField(
          decoration: InputDecoration(
            hintText: "Search tips, news, and more..." ,   hintStyle: const TextStyle(fontSize: 15,color: Colors.grey,),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
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

class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Daily Tip",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardStyle(const Color(0xFFf3f6f3), borderColor: const Color(0xFFD6EDEA)),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.tips_and_updates,
                    color: Colors.teal,
                    size: 36,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "20-20-20 Rule",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Every 20 minutes, look at something 20 feet away for 20 seconds.",
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.access_time,
                  color: Colors.teal,
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
            return const SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  "Loading latest news...",
                  style: TextStyle(color: Colors.black45),
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

          return Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Latest News",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "View all",
                    style: TextStyle(color: Colors.teal),
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
                      decoration: cardStyle(const Color(0xFFfbf8f5)),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  article["description"] ??
                                      "Read the latest updates about eye health.",
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: Colors.black54,
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
                          ? Colors.teal
                          : Colors.grey.shade300,
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
class ProtectionSection extends StatelessWidget {
  const ProtectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "How to Protect Your Eyes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "View all",
                style: TextStyle(color: Colors.teal),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: ProtectCard(
                    icon: Icons.airline_seat_recline_extra,
                    title: "Take Regular Breaks",
                    description:
                        "Rest your eyes every 20 minutes to reduce strain.",
                    color: Color(0xFFf4bb76),
                    bgColor: Color(0xFFfcf4ef),
                    borderColor: Color(0xFFefe3d6),
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
                    description:
                        "Drink enough water to keep your eyes moist.",
                    color: Color(0xFF6bada0),
                    bgColor: Color(0xFFf6f7f3),
                    borderColor: Color(0xFFeaeeea),
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
                    description:
                        "Use natural or soft lighting to reduce fatigue.",
                    color: Color(0xFF1d4774),
                    bgColor: Color(0xFFf7f5f3),
                    borderColor: Color(0xFFe3e4e7),
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

class ProtectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const ProtectCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), 
      decoration: cardStyle(bgColor,borderColor: borderColor),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, 
        children: [
          const SizedBox(height: 6),

          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});
Widget featureItem(IconData icon, String title, String subtitle) {
  return Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF62C2B6),
            size: 30,
          ),

          const SizedBox(height: 10),

          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.35,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget verticalDivider() {
  return Container(
    height: 95,
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: const Color(0xFFD6EDEA),
  );
}
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About CLIPVIEW",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 12),

          /// الكارد الأول
          Container(
            padding: const EdgeInsets.all(12),
            decoration: cardStyle(const Color(0xFFf0f5f3),borderColor:Color(0xFFe6f0ee)),
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

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Get the most out of CLIPVIEW",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Learn how to use your device and app to improve your eye health every day.",
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF8fb8b1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          /// الكارد الثاني
         Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 18,
  ),
  decoration: cardStyle(const Color(0xFFf0f5f3),borderColor:Color(0xFFe6f0ee)),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      featureItem(
        Icons.verified_user_outlined,
        "Privacy First",
        "Camera-free by design",
      ),

      verticalDivider(),

      featureItem(
        Icons.attach_file,
        "Clip-On Design",
        "Easy to attach and use",
      ),

      verticalDivider(),

      featureItem(
        Icons.battery_full,
        "Long Battery",
        "All-day monitoring on a single charge",
      ),

      verticalDivider(),

      featureItem(
        Icons.bar_chart,
        "Smart Insights",
        "AI-powered personalization",
      ),
    ],
  ),
),
        ],
      ),
    );
  }
}