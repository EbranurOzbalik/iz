import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'movie.dart';

class MovieAttribution extends StatelessWidget {
  const MovieAttribution({super.key, this.movie});
  final Movie? movie;

  bool get usesTvmaze =>
      Uri.tryParse(movie?.posterUrl ?? '')?.host == 'static.tvmaze.com';
  bool get usesBiletsa =>
      Uri.tryParse(movie?.posterUrl ?? '')?.host == 'biletsa.com';

  Future<void> open(String? value) async {
    final uri = Uri.tryParse(value ?? '');
    if (uri != null && uri.scheme == 'https') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      icon: const Icon(Icons.info_outline, size: 18),
      label: const Text('Film bilgileri ve görsel kaynağı'),
      onPressed: () => showAboutDialog(
        context: context,
        applicationName: 'İZ · Film bilgileri',
        children: [
          Text(
            'İZ Katalog API, açık lisanslı Wikidata bilgilerini kullanır. '
            '${usesBiletsa
                ? 'Tiyatro bilgileri, afişi ve bilet bağlantısı Biletsa tarafından sağlanır.'
                : usesTvmaze
                ? 'Dizi afişi TVmaze tarafından sağlanır.'
                : 'Görseller varsa Wikimedia Commons üzerinden gösterilir ve her dosyanın kendi lisansı geçerlidir.'}',
          ),
          const SizedBox(height: 12),
          if (movie?.sourceUrl != null)
            TextButton(
              onPressed: () => open(movie!.sourceUrl),
              child: const Text('Film veri kaynağını aç'),
            ),
          if (movie?.posterAttributionUrl != null)
            TextButton(
              onPressed: () => open(movie!.posterAttributionUrl),
              child: const Text('Görsel lisansı ve atfını aç'),
            ),
          TextButton(
            onPressed: () => open('https://www.wikidata.org'),
            child: const Text('Wikidata'),
          ),
        ],
      ),
    ),
  );
}
