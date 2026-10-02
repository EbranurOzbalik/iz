class Book {
   String title;
   List<String> authors;
   int? firstPublishYear;
   int? editionCount;

   Book({
     required this.title,
     required this.authors,
     this.firstPublishYear,
     this.editionCount,
   });

   factory Book.fromJson(Map<String, dynamic> json) {
     return Book(
       title: json['title'],
       authors: List<String>.from(json['author_name'] ?? []),
       firstPublishYear: json['first_publish_year'],
       editionCount: json['edition_count'],

     );
   }

}