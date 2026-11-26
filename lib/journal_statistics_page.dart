import 'package:flutter/material.dart';

import 'journal.dart';

class JournalStatistics {
  JournalStatistics(
    List<JournalEntry> entries,
    List<JournalActivity> activities,
  ) : total = entries.length,
      completed = entries.where((e) => e.status == JournalStatus.done).length,
      active = entries.where((e) => e.status == JournalStatus.active).length,
      rated = entries.where((e) => e.rating > 0).length,
      averageRating = _average(entries),
      activityDays = activities.map((e) => e.day).toSet().length,
      byType = {
        for (final type in MediaType.values)
          type: entries.where((e) => e.type == type).length,
      };

  final int total, completed, active, rated, activityDays;
  final double averageRating;
  final Map<MediaType, int> byType;

  static double _average(List<JournalEntry> entries) {
    final values = entries.where((e) => e.rating > 0).map((e) => e.rating);
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class JournalStatisticsPage extends StatelessWidget {
  const JournalStatisticsPage({
    super.key,
    required this.entries,
    required this.activities,
  });

  final List<JournalEntry> entries;
  final List<JournalActivity> activities;

  @override
  Widget build(BuildContext context) {
    final stats = JournalStatistics(entries, activities);
    final colors = Theme.of(context).colorScheme;
    final maximum = stats.byType.values.fold(1, (a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistiklerim')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'İzlerinin özeti',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.65,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _Metric(
                  label: 'Arşiv',
                  value: '${stats.total}',
                  icon: Icons.bookmarks_outlined,
                ),
                _Metric(
                  label: 'Tamamlanan',
                  value: '${stats.completed}',
                  icon: Icons.check_circle_outline,
                ),
                _Metric(
                  label: 'Ortalama puan',
                  value: stats.rated == 0
                      ? '—'
                      : stats.averageRating.toStringAsFixed(1),
                  icon: Icons.star_outline,
                ),
                _Metric(
                  label: 'Aktif gün',
                  value: '${stats.activityDays}',
                  icon: Icons.calendar_month_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Arşiv dağılımı',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final type in MediaType.values) ...[
              Row(
                children: [
                  Expanded(child: Text(type.label)),
                  Text('${stats.byType[type]}'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (stats.byType[type] ?? 0) / maximum,
                minHeight: 10,
                borderRadius: BorderRadius.circular(20),
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text('${stats.active} eser devam ediyor'),
                subtitle: Text('${stats.rated} esere puan verdin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}
