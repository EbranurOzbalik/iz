import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TmdbAttribution extends StatelessWidget {
  const TmdbAttribution({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      icon: const Icon(Icons.info_outline, size: 18),
      label: const Text('Film bilgileri: TMDB'),
      onPressed: () => showAboutDialog(
        context: context,
        applicationName: 'İZ · Film bilgileri',
        applicationIcon: SvgPicture.asset('assets/tmdb-logo.svg', width: 80),
        children: const [
          Text(
            'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          ),
          SizedBox(height: 12),
          SelectableText('https://www.themoviedb.org'),
        ],
      ),
    ),
  );
}
