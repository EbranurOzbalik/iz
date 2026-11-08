import 'package:flutter/material.dart';

import 'book_cover.dart';
import 'journal.dart';
import 'movie_poster.dart';

IconData mediaIcon(MediaType type) => switch (type) {
  MediaType.book => Icons.menu_book_outlined,
  MediaType.film => Icons.movie_outlined,
  MediaType.series => Icons.tv_outlined,
  MediaType.theatre => Icons.theater_comedy_outlined,
};

class JournalCover extends StatelessWidget {
  const JournalCover({super.key, required this.entry, this.width = 90});
  final JournalEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (entry.movie case final movie?) {
      return MoviePoster(movie: movie, width: width);
    }
    if (entry.book case final book? when book.coverUrl != null) {
      return BookCover(book: book, width: width, height: width * 1.5);
    }
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: '${entry.title}, kapak görseli yok',
      child: Container(
        width: width,
        height: width * 1.5,
        padding: EdgeInsets.all(width * .12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.secondaryContainer, colors.tertiaryContainer],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              mediaIcon(entry.type),
              size: width < 60 ? 16 : 26,
              color: colors.onSecondaryContainer,
            ),
            if (width >= 60)
              Text(
                entry.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: width * .15,
                  color: colors.onSecondaryContainer,
                ),
              ),
            Container(height: 2, width: width * .25, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
