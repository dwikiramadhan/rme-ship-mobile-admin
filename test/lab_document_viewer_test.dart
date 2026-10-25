import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

import 'package:bayan_rme/features/patients/presentation/widgets/lab_document_viewer.dart';

import 'support/pdf_support.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> _pump(WidgetTester tester, LabDocumentViewer viewer) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(height: 500, child: viewer))));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('image documents are downloaded and shown', (tester) async {
    String? requested;
    await _pump(
      tester,
      LabDocumentViewer(
        url: 'http://server/api/v1/lab-examinations/view-document/a.png',
        fileName: 'a.png',
        loader: (url) async {
          requested = url;
          return (bytes: Uint8List.fromList(_png), contentType: 'image/png');
        },
      ),
    );

    expect(requested, 'http://server/api/v1/lab-examinations/view-document/a.png');
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('PDF documents open in the PDF viewer', (tester) async {
    await _pump(
      tester,
      LabDocumentViewer(
        url: 'http://server/doc',
        // No .pdf extension: detected from the content type.
        fileName: 'doc',
        loader: (_) async => (
          bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 test')),
          contentType: 'application/pdf',
        ),
      ),
    );

    expect(find.byType(PdfViewPinch), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  }, skip: noPdfRenderer);

  testWidgets('a missing document shows a clear error with retry', (tester) async {
    var attempts = 0;
    await _pump(
      tester,
      LabDocumentViewer(
        url: 'http://server/missing.png',
        fileName: 'missing.png',
        loader: (url) async {
          attempts++;
          throw DioException(
            requestOptions: RequestOptions(path: url),
            response: Response(requestOptions: RequestOptions(path: url), statusCode: 404),
          );
        },
      ),
    );

    expect(find.text('Gagal memuat dokumen'), findsOneWidget);
    expect(find.text('Dokumen tidak ditemukan di server.'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
  });

  test('PDF renderer errors say what to do', () {
    expect(
      pdfOpenErrorDetail(MissingPluginException('open.document.data')),
      contains('jalankan ulang'),
    );
  });
}
