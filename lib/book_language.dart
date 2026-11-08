import 'package:flutter/material.dart';

enum BookLanguage {
  turkish('Türkçe', 'tur', 'tr'),
  english('İngilizce', 'eng', 'en');

  const BookLanguage(this.label, this.code, this.locale);
  final String label, code, locale;
}

class BookLanguageSelector extends StatelessWidget {
  const BookLanguageSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BookLanguage value;
  final ValueChanged<BookLanguage>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Kitap dili', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final language in BookLanguage.values)
            ChoiceChip(
              label: Text(language.label),
              selected: value == language,
              onSelected: onChanged == null
                  ? null
                  : (_) => onChanged!(language),
            ),
        ],
      ),
    ],
  );
}
