import 'package:flutter/material.dart';

/// UI-only page to display all eye health form info (dummy data for now).
/// Later 'll replace the dummy data with API response from backend.
class EyeHealthProfilePage extends StatelessWidget {
  const EyeHealthProfilePage({super.key});

  // ===== Dummy data (matches backend model types) =====
  EyeHealthFormViewData _demoData() {
    return EyeHealthFormViewData(
      fullName: 'Sarah Ahmed',
      dateOfBirth: DateTime(2003, 7, 21),
      gender: 'Female',
      previousEyeConditions: const ['myopia', 'astigmatism'],
      chronicDiseases: const ['diabetes'],
      usesGlasses: true,
      usesContactLenses: false,
      eyeSurgeryHistory: 'LASIK (2019) - left eye',
      screenTimeHours: 7,
      lightingConditions: 'Normal',
      sleepHours: 6,
      diet: 'Average',
      currentEyeSymptoms: const ['dryness', 'eye strain', 'blurred vision'],
      isActive: true,
      createdAt: DateTime(2025, 12, 10, 11, 30),
      updatedAt: DateTime(2026, 2, 9, 19, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _demoData();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile Information'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: () {
                // UI only (later: open edit page / enable editing)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit (UI only for now)')),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _HeaderCard(data: data),
            const SizedBox(height: 14),

            _SectionTitle(title: 'Personal Information'),
            const SizedBox(height: 10),
            _InfoGrid(items: [
              _InfoItem(
                icon: Icons.person_outline,
                title: 'Full Name',
                value: data.fullName,
              ),
              _InfoItem(
                icon: Icons.badge_outlined,
                title: 'Gender',
                value: data.gender,
              ),
              _InfoItem(
                icon: Icons.cake_outlined,
                title: 'Date of Birth',
                value: _fmtDate(data.dateOfBirth),
              ),
              _InfoItem(
                icon: Icons.verified_outlined,
                title: 'Profile Status',
                value: data.isActive ? 'Active' : 'Inactive',
              ),
            ]),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Previous Eye Conditions'),
            const SizedBox(height: 10),
            _ChipsWrap(
              chips: data.previousEyeConditions.isEmpty
                  ? const ['None']
                  : data.previousEyeConditions.map(_humanize).toList(),
            ),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Chronic Diseases'),
            const SizedBox(height: 10),
            _ChipsWrap(
              chips: data.chronicDiseases.isEmpty
                  ? const ['None']
                  : data.chronicDiseases.map(_humanize).toList(),
            ),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Vision Aids'),
            const SizedBox(height: 10),
            _InfoGrid(items: [
              _InfoItem(
                icon: Icons.remove_red_eye_outlined,
                title: 'Uses Glasses',
                value: data.usesGlasses ? 'Yes' : 'No',
              ),
              _InfoItem(
                icon: Icons.contact_page_outlined,
                title: 'Uses Contact Lenses',
                value: data.usesContactLenses ? 'Yes' : 'No',
              ),
            ]),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Eye Surgery History'),
            const SizedBox(height: 10),
            _BigNoteCard(
              icon: Icons.medical_information_outlined,
              title: 'History',
              text: (data.eyeSurgeryHistory == null || data.eyeSurgeryHistory!.trim().isEmpty)
                  ? 'No surgeries reported.'
                  : data.eyeSurgeryHistory!.trim(),
            ),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Daily Habits & Lifestyle'),
            const SizedBox(height: 10),
            _InfoGrid(items: [
              _InfoItem(
                icon: Icons.monitor_outlined,
                title: 'Screen Time',
                value: '${data.screenTimeHours} h/day',               
              ),
              _InfoItem(
                icon: Icons.lightbulb_outline,
                title: 'Lighting',
                value: data.lightingConditions,
              ),
              _InfoItem(
                icon: Icons.bedtime_outlined,
                title: 'Sleep',
                value: '${data.sleepHours} h/night',
                ),
              _InfoItem(
                icon: Icons.restaurant_outlined,
                title: 'Diet',
                value: data.diet ?? '—',
              ),
            ]),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Current Eye Symptoms'),
            const SizedBox(height: 10),
            _ChipsWrap(
              chips: data.currentEyeSymptoms.isEmpty
                  ? const ['None']
                  : data.currentEyeSymptoms.map(_humanize).toList(),
            ),
            const SizedBox(height: 18),

            _SectionTitle(title: 'Record Metadata'),
            const SizedBox(height: 10),
            _InfoGrid(items: [
              _InfoItem(
                icon: Icons.calendar_month_outlined,
                title: 'Created At',
                value: _fmtDateTime(data.createdAt),
              ),
              _InfoItem(
                icon: Icons.update_outlined,
                title: 'Updated At',
                value: _fmtDateTime(data.updatedAt),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _humanize(String s) {
    // e.g. "eye strain" / "eye_strain" / "myopia"
    final cleaned = s.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return s;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

/// ===== Simple view-model (UI layer) =====
class EyeHealthFormViewData {
  final String fullName;
  final DateTime dateOfBirth;
  final String gender;

  final List<String> previousEyeConditions;
  final List<String> chronicDiseases;

  final bool usesGlasses;
  final bool usesContactLenses;

  final String? eyeSurgeryHistory;

  final int screenTimeHours;
  final String lightingConditions;
  final int sleepHours;
  final String? diet;

  final List<String> currentEyeSymptoms;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EyeHealthFormViewData({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.previousEyeConditions,
    required this.chronicDiseases,
    required this.usesGlasses,
    required this.usesContactLenses,
    required this.eyeSurgeryHistory,
    required this.screenTimeHours,
    required this.lightingConditions,
    required this.sleepHours,
    required this.diet,
    required this.currentEyeSymptoms,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// ===== UI Widgets =====

class _HeaderCard extends StatelessWidget {
  final EyeHealthFormViewData data;
  const _HeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.18),
            theme.colorScheme.secondary.withOpacity(0.18),
          ],
        ),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.18),
            child: Text(
              data.fullName.isNotEmpty ? data.fullName[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.fullName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Eye-Health Form Summary',
                  style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusChip(isActive: data.isActive),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isActive
        ? theme.colorScheme.secondary.withOpacity(0.16)
        : Colors.black.withOpacity(0.06);
    final fg = isActive ? theme.colorScheme.secondary : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 92,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => _InfoTile(item: items[i]),
    );
  }
}


class _InfoItem {
  final IconData icon;
  final String title;
  final String value;

  _InfoItem({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _InfoTile extends StatelessWidget {
  final _InfoItem item;
  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.55))),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsWrap extends StatelessWidget {
  final List<String> chips;
  const _ChipsWrap({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips.map((t) {
        return Chip(
          label: Text(t),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        );
      }).toList(),
    );
  }
}

class _BigNoteCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _BigNoteCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(color: Colors.black.withOpacity(0.75), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 