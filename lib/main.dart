import 'package:dio/dio.dart';
import 'book.dart';

Future<void> main() async {
  final dio = Dio();

  // Uygulamanın başlangıç durumu
  bool isLoading = false;
  String? errorMessage;
  List<Book> books = [];

  try {
    // İstek başlıyor
    isLoading = true;
    errorMessage = null;

    final response = await dio.get(
      'https://openlibrary.org/search.json',
      queryParameters: {
        'q': 'Suç ve Ceza',
        'limit': 5,
      },
    );

    print(response.statusCode);
    print(response.data.runtimeType);

    // API'den gelen veri
    final decoded = response.data;
    final docs = decoded['docs'];

    // Ham kitap verilerini Book nesnelerine dönüştürüyoruz
    books = docs.map<Book>((bookJson) {
      return Book.fromJson(bookJson);
    }).toList();

    // İstek başarıyla bitti
    isLoading = false;

    // Kitapları kullanıyoruz
    for (final book in books) {
      print(book.title);
      print(book.authors);

      if (book.firstPublishYear != null) {
        print('Yayın yılı: ${book.firstPublishYear}');
      } else {
        print('Yayın yılı bilinmiyor');
      }

      if (book.editionCount != null) {
        print('Baskı sayısı: ${book.editionCount}');
      } else {
        print('Baskı sayısı bilinmiyor');
      }
    }
  } catch (e) {
    // İstek başarısız olsa da artık yükleme bitmiştir
    isLoading = false;
    errorMessage = 'Kitaplar yüklenemedi';

    print(errorMessage);
    print('Hata detayı: $e');
  }

  print('Loading: $isLoading');
  print('Error: $errorMessage');
}