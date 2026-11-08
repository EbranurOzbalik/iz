import 'package:flutter/material.dart';

import 'journal.dart';
import 'journal_cover.dart';

const _months = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];
String calendarDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
DateTime _shift(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

class JournalCalendar extends StatefulWidget {
  const JournalCalendar({
    super.key,
    required this.entries,
    required this.activities,
    required this.today,
    required this.onOpenEntry,
  });
  final List<JournalEntry> entries;
  final List<JournalActivity> activities;
  final DateTime today;
  final ValueChanged<String> onOpenEntry;
  @override
  State<JournalCalendar> createState() => _JournalCalendarState();
}

class _JournalCalendarState extends State<JournalCalendar> {
  int weeksBack = 0;
  DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = dayDate(widget.today);
    final lastMonday = _shift(today, 1 - today.weekday);
    final start = _shift(lastMonday, -84 - weeksBack * 7);
    final end = _shift(start, 90);
    final byDay = <String, List<JournalActivity>>{};
    for (final activity in widget.activities) {
      byDay.putIfAbsent(activity.day, () => []).add(activity);
    }
    final firstDay = widget.activities.isEmpty
        ? today
        : widget.activities
              .map((e) => DateTime.parse(e.day))
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final activeDays = List.generate(
      91,
      (i) => localDay(_shift(start, i)),
    ).where((key) => byDay[key]?.isNotEmpty ?? false).length;
    Color levelColor(int count) => Color.lerp(
      colors.surfaceContainerHighest,
      colors.primary,
      count.clamp(0, 4) / 4,
    )!;
    final selectedActivities = selected == null
        ? <JournalActivity>[]
        : byDay[localDay(selected!)] ?? [];
    final entries = {for (final entry in widget.entries) entry.id: entry};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 48),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            Text(
              'İz takvimin',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${start.year}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.activities.isEmpty
              ? 'İlk notunla veya ilerleme kaydınla bir kare renklensin.'
              : 'Bu dönemde $activeDays aktif gün',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final labelWidth = MediaQuery.textScalerOf(
              context,
            ).scale(25).clamp(25.0, 60.0);
            final cell = (constraints.maxWidth - labelWidth - 12 * 4) / 13;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      for (var row = 0; row < 7; row++)
                        SizedBox(
                          height: cell + 4,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              {0: 'Pzt', 2: 'Çar', 4: 'Cum', 6: 'Paz'}[row] ??
                                  '',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                              textScaler: TextScaler.noScaling,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 24,
                        child: Stack(
                          children: [
                            for (var column = 0; column < 13; column++)
                              if (column == 0 ||
                                  _shift(start, column * 7).month !=
                                      _shift(start, (column - 1) * 7).month)
                                Positioned(
                                  left: (column * (cell + 4)).clamp(
                                    0,
                                    constraints.maxWidth - labelWidth - 30,
                                  ),
                                  child: Text(
                                    _months[_shift(start, column * 7).month -
                                        1],
                                    textScaler: TextScaler.noScaling,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      for (var row = 0; row < 7; row++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              for (var column = 0; column < 13; column++) ...[
                                if (column > 0) const SizedBox(width: 4),
                                Builder(
                                  builder: (context) {
                                    final date = _shift(
                                      start,
                                      column * 7 + row,
                                    );
                                    final count =
                                        byDay[localDay(date)]?.length ?? 0;
                                    final future = date.isAfter(today);
                                    final isSelected = selected == date;
                                    final label =
                                        '${calendarDate(date)} · ${future ? 'Henüz gelmedi' : '$count iz'}';
                                    return Semantics(
                                      button: true,
                                      enabled: !future,
                                      selected: isSelected,
                                      label: label,
                                      child: Tooltip(
                                        message: label,
                                        excludeFromSemantics: true,
                                        child: InkWell(
                                          key: ValueKey(
                                            'day-${localDay(date)}',
                                          ),
                                          onTap: future
                                              ? null
                                              : () => setState(
                                                  () => selected = date,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          child: Container(
                                            width: cell,
                                            height: cell,
                                            decoration: BoxDecoration(
                                              color: levelColor(count)
                                                  .withValues(
                                                    alpha: future ? .25 : 1,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: isSelected
                                                  ? Border.all(
                                                      color: colors.onSurface,
                                                      width: 2,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('0', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            for (var level = 0; level < 5; level++)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: levelColor(level),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const Text('4+ kayıt', style: TextStyle(fontSize: 11)),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Önceki 13 hafta',
              onPressed: firstDay.isBefore(start)
                  ? () => setState(() => weeksBack += 13)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${calendarDate(start)} – ${calendarDate(end.isAfter(today) ? today : end)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'Sonraki 13 hafta',
              onPressed: weeksBack > 0
                  ? () => setState(() => weeksBack -= 13)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selected ?? today,
              firstDate: DateTime(firstDay.year - 1),
              lastDate: today,
              helpText: 'İz bıraktığın günü seç',
            );
            if (date != null && mounted) {
              setState(() {
                selected = date;
                final distance =
                    DateTime.utc(
                          lastMonday.year,
                          lastMonday.month,
                          lastMonday.day,
                        )
                        .difference(
                          DateTime.utc(date.year, date.month, date.day),
                        )
                        .inDays;
                weeksBack = distance > 84
                    ? ((distance - 84 + 90) ~/ 91) * 13
                    : 0;
              });
            }
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(selected == null ? 'Gün seç' : calendarDate(selected!)),
        ),
        if (selected != null)
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                if (selectedActivities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Bu gün için henüz bir kayıt yok.'),
                  ),
                for (final activity in selectedActivities)
                  if (entries[activity.entryId] case final entry?)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JournalCover(entry: entry, width: 32),
                      title: Text(entry.title),
                      subtitle: Text(activity.text),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenEntry(entry.id),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}
