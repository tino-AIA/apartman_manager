// lib/services/kpr_export_service.dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

class KprExportService {
  // 1. Generiranje Excel datoteke (.xlsx) identične sheetu Export
  static List<int>? generirajKprExcel({
    required List<TuristBoravak> stavke,
    required PostavkeIznajmljivaca postavke,
    required int godina,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Export'];
    excel.setDefaultSheet('Export');

    // Zaglavlje obrasca
    sheet.appendRow([TextCellValue('1. OPĆI PODACI O POREZNOM OBVEZNIKU'), TextCellValue('Obrazac EP')]);
    sheet.appendRow([TextCellValue('1.1 IME I PREZIME'), TextCellValue(postavke.imePrezime)]);
    sheet.appendRow([TextCellValue('1.2 OIB'), TextCellValue(postavke.oib)]);
    sheet.appendRow([TextCellValue('1.3 MJESTO PREBIVALIŠTA / BORAVIŠTA'), TextCellValue(postavke.mjesto)]);
    sheet.appendRow([TextCellValue('1.4 ADRESA PREBIVALIŠTA / BORAVIŠTA'), TextCellValue(postavke.adresa)]);
    sheet.appendRow([TextCellValue('EVIDENCIJA O PROMETU ZA : $godina. godinu')]);
    sheet.appendRow([TextCellValue('')]);

    // Zaglavlje tablice
    sheet.appendRow([
      TextCellValue('Redni broj'),
      TextCellValue('Broj računa'),
      TextCellValue('Nadnevak'),
      TextCellValue('KORISNIK USLUGE (Prezime i ime)'),
      TextCellValue('IZNOS RAČUNA (EUR)'),
    ]);

    double ukupno = 0.0;
    final df = DateFormat('dd. MM. yyyy.');

    for (int i = 0; i < stavke.length; i++) {
      final s = stavke[i];
      ukupno += s.cijenaUkupno;
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.racunBroj),
        TextCellValue(df.format(s.datumDolaska)),
        TextCellValue(s.prezimeIme),
        DoubleCellValue(s.cijenaUkupno),
      ]);
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(ukupno),
    ]);

    return excel.save();
  }

  // 2. Generiranje službenog A4 PDF-a s prijenosima stranica
  static Future<Uint8List> generirajKprPdf({
    required List<TuristBoravak> stavke,
    required PostavkeIznajmljivaca postavke,
    required int godina,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd. MM. yyyy.');
    const int stavkiPoStranici = 35; // Paginacija kao u vašoj tablici

    double donos = 0.0;
    int ukupnoStranica = (stavke.length / stavkiPoStranici).ceil();
    if (ukupnoStranica == 0) ukupnoStranica = 1;

    for (int str = 0; str < ukupnoStranica; str++) {
      final startIndex = str * stavkiPoStranici;
      final endIndex = (startIndex + stavkiPoStranici < stavke.length)
          ? startIndex + stavkiPoStranici
          : stavke.length;

      final podStavke = stavke.sublist(startIndex, endIndex);
      double zbrojStranice = podStavke.fold(0.0, (sum, item) => sum + item.cijenaUkupno);
      double zaPrijenos = donos + zbrojStranice;

      final trenutniDonos = donos;
      final trenutniZaPrijenos = zaPrijenos;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Zaglavlje na svakoj stranici
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('1. OPĆI PODACI O POREZNOM OBVEZNIKU', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Obrazac EP', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
                pw.Text('1.1 IME I PREZIME: ${postavke.imePrezime}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('1.2 OIB: ${postavke.oib}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('1.3 MJESTO PREBIVALIŠTA / BORAVIŠTA: ${postavke.mjesto}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('1.4 ADRESA PREBIVALIŠTA / BORAVIŠTA: ${postavke.adresa}', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text('EVIDENCIJA O PROMETU ZA: $godina. godinu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ),
                pw.SizedBox(height: 10),

                // Tablica
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _th('R.br.', width: 35),
                        _th('Broj računa', width: 65),
                        _th('Nadnevak', width: 75),
                        _th('KORISNIK USLUGE (Prezime i ime)'),
                        _th('IZNOS (€)', align: pw.TextAlign.right, width: 80),
                      ],
                    ),
                    if (str > 0)
                      pw.TableRow(
                        children: [
                          _td('*', align: pw.TextAlign.center),
                          _td('*'),
                          _td('*'),
                          _td('DONOS:', bold: true),
                          _td('${trenutniDonos.toStringAsFixed(2)} €', align: pw.TextAlign.right, bold: true),
                        ],
                      ),
                    for (int i = 0; i < podStavke.length; i++)
                      pw.TableRow(
                        children: [
                          _td('${startIndex + i + 1}', align: pw.TextAlign.center),
                          _td(podStavke[i].racunBroj),
                          _td(df.format(podStavke[i].datumDolaska)),
                          _td(podStavke[i].prezimeIme),
                          _td('${podStavke[i].cijenaUkupno.toStringAsFixed(2)} €', align: pw.TextAlign.right),
                        ],
                      ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _td(''),
                        _td(''),
                        _td(''),
                        _td(str == ukupnoStranica - 1 ? 'TOTAL:' : 'ZA PRIJENOS:', bold: true),
                        _td('${trenutniZaPrijenos.toStringAsFixed(2)} €', align: pw.TextAlign.right, bold: true),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('U ${postavke.mjesto}, ${df.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('( potpis poreznog obveznika )', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            );
          },
        ),
      );
      donos = zaPrijenos;
    }

    return pdf.save();
  }

  static pw.Widget _th(String text, {double? width, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
