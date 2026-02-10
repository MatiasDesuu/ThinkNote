import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/custom_snackbar.dart';

class ExportService {
  static Future<void> exportToMarkdown({
    required BuildContext context,
    required String title,
    required String content,
  }) async {
    try {
      final cleanTitle = title.trim().isEmpty ? 'Untitled Note' : title.trim();
      final fileName =
          '${cleanTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.md';

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export to Markdown',
        fileName: fileName,
        allowedExtensions: ['md'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(content);

        CustomSnackbar.show(
          context: context,
          message: 'Note exported to: ${p.basename(outputFile)}',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Error exporting note: $e',
        type: CustomSnackbarType.error,
      );
    }
  }

  static Future<void> exportToHtml({
    required BuildContext context,
    required String title,
    required String content,
  }) async {
    try {
      final cleanTitle = title.trim().isEmpty ? 'Untitled Note' : title.trim();
      final fileName =
          '${cleanTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.html';

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export to HTML',
        fileName: fileName,
        allowedExtensions: ['html'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);

        final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$cleanTitle</title>
    <style>
        @media print {
            body { margin: 0; padding: 20px; }
            .no-print { display: none; }
        }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            line-height: 1.6; 
            margin: 40px; 
            color: #333;
            max-width: 800px;
            margin-left: auto;
            margin-right: auto;
        }
        h1 { 
            color: #2c3e50; 
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        pre { 
            background-color: #f8f9fa; 
            padding: 15px; 
            border-radius: 5px; 
            border-left: 4px solid #3498db;
            overflow-x: auto;
        }
        code { 
            background-color: #f8f9fa; 
            padding: 2px 6px; 
            border-radius: 3px; 
            font-family: 'Courier New', monospace;
        }
        p { margin-bottom: 15px; }
        .content { white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>$cleanTitle</h1>
    <div class="content">${content.replaceAll('\n', '<br>')}</div>
</body>
</html>
        ''';

        await file.writeAsString(htmlContent);

        CustomSnackbar.show(
          context: context,
          message: 'Note exported to: ${p.basename(outputFile)}',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Error exporting note: $e',
        type: CustomSnackbarType.error,
      );
    }
  }

  static Future<void> exportToPdf({
    required BuildContext context,
    required String title,
    required String content,
  }) async {
    try {
      final cleanTitle = title.trim().isEmpty ? 'Untitled Note' : title.trim();
      final fileName =
          '${cleanTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.pdf';

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export to PDF',
        fileName: fileName,
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final pdf = pw.Document();

        final paragraphs =
            content
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .toList();

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    cleanTitle,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  ...paragraphs.map(
                    (paragraph) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 12),
                      child: pw.Text(
                        paragraph,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );

        final bytes = await pdf.save();
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        CustomSnackbar.show(
          context: context,
          message: 'Note exported to: ${p.basename(outputFile)}',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Error exporting note: $e',
        type: CustomSnackbarType.error,
      );
    }
  }
}
