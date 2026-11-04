import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/main.dart';

void main() {
  testWidgets('Search stays reachable with a keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final requests = <RequestOptions>[];
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'numFound': 1,
                'docs': [
                  {'title': 'Dune kitabı'},
                ],
              },
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: BookSearchPage(dio: dio)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.ensureVisible(find.text('Kitap Ara'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Kitap Ara')).bottom,
      lessThanOrEqualTo(260),
    );
    await tester.tap(find.text('Kitap Ara'));
    await tester.pumpAndSettle();
    expect(requests.single.queryParameters['q'], 'Dune');
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Dune kitabı'),
      150,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('Dune kitabı').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Validation, sorting and retry remain usable in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final requests = <RequestOptions>[];
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          if (requests.length == 1) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'docs': [], 'numFound': 0},
              ),
            );
          }
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: BookSearchPage(dio: dio)));
    await tester.ensureVisible(find.text('Kitap Ara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitap Ara'));
    await tester.pumpAndSettle();
    expect(find.text('Bir kitap adı yaz'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.ensureVisible(find.byTooltip('Sonuçları sırala'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonuçları sırala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlk yayın: en eski').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.ensureVisible(find.text('Kitap Ara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitap Ara'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last.queryParameters['q'], 'Dune');
    expect(requests.last.queryParameters['sort'], 'old');
    await tester.ensureVisible(find.text('Kitap bulunamadı'));
    await tester.pumpAndSettle();
    expect(find.text('Kitap bulunamadı').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
