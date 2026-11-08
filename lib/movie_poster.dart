import 'package:flutter/material.dart';
import 'movie.dart';

class MoviePoster extends StatelessWidget {
  const MoviePoster({super.key, required this.movie, this.width = 70});
  final Movie movie;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Semantics(
      image: true,
      label: '${movie.title}, afiş bulunamadı',
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: width * 1.5,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: movie.posterUrl == null
              ? placeholder()
              : Image.network(
                  movie.posterUrl!,
                  fit: BoxFit.cover,
                  semanticLabel: '${movie.title} afişi',
                  errorBuilder: (_, _, _) => placeholder(),
                  frameBuilder: (_, child, frame, loaded) =>
                      frame == null ? placeholder() : child,
                ),
        ),
      ),
    );
  }
}
