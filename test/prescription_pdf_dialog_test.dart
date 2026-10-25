import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

import 'package:bayan_rme/features/patients/presentation/widgets/prescription_pdf_dialog.dart';

import 'support/pdf_support.dart';

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 test'));

Future<void> _pump(WidgetTester tester, PrescriptionPdfDialog dialog) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('file name is read from Content-Disposition', () {
    expect(
      prescriptionFileName('attachment; filename="resep-siti-14072026.pdf"'),
      'resep-siti-14072026.pdf',
    );
    expect(prescriptionFileName('attachment; filename=resep.pdf'), 'resep.pdf');
    expect(prescriptionFileName(null), isNull);
  });

  testWidgets('downloads the prescription and saves the same bytes', (tester) async {
    String? requested;
    String? savedName;
    Uint8List? savedBytes;
    await _pump(
      tester,
      PrescriptionPdfDialog(
        medicalRecordId: 'rec-1',
        loader: (id) async {
          requested = id;
          return (bytes: _pdf, fileName: 'resep-siti-14072026.pdf');
        },
        saver: (name, bytes) async {
          savedName = name;
          savedBytes = bytes;
          return true;
        },
      ),
    );

    expect(requested, 'rec-1');
    expect(find.byType(PdfViewPinch), findsOneWidget);
    expect(find.text('resep-siti-14072026.pdf'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(savedName, 'resep-siti-14072026.pdf');
    expect(savedBytes, _pdf);
    expect(find.text('Resep tersimpan: resep-siti-14072026.pdf'), findsOneWidget);
  }, skip: noPdfRenderer);

  testWidgets('save is disabled until the download succeeds', (tester) async {
    var saved = false;
    await _pump(
      tester,
      PrescriptionPdfDialog(
        medicalRecordId: 'rec-2',
        loader: (id) async => throw DioException(
          requestOptions: RequestOptions(path: id),
          response: Response(requestOptions: RequestOptions(path: id), statusCode: 404),
        ),
        saver: (_, _) async => saved = true,
      ),
    );

    expect(find.text('Gagal memuat dokumen'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(saved, isFalse);
  });
}
