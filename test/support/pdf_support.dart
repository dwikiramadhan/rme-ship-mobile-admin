import 'dart:io';

/// pdfx can't open a PDF on a Linux host (the CI runner): the tests that show
/// one run on macOS and Windows only. The app itself targets Android and iOS.
final bool noPdfRenderer = Platform.isLinux;
