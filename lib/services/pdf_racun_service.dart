// lib/services/pdf_racun_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

class PdfRacunService {
  static Future<Uint8List> generirajRacunPdf({
    required TuristBoravak boravak,
    required PostavkeIznajmljivaca postavke,
    DateTime? datumIzdavanja,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd. MM. yyyy.');
    final tf = DateFormat('HH:mm');
    final sad = datumIzdavanja ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Zaglavlje objekta i vlasnika
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${postavke.nazivObjekta} - ${postavke.imePrezime}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('OIB: ${postavke.oib}', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('${postavke.adresa}, ${postavke.mjesto}, Croatia', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('${postavke.telefon} - ${postavke.email}', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Broj računa
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                color: PdfColors.grey200,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('RAČUN Br. / INVOICE No.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.Text(boravak.racunBroj, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Termini i Gost
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Dolazak / Arrival: ${df.format(boravak.datumDolaska)}', style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(child: pw.Text('Odlazak / Departure: ${df.format(boravak.datumOdlaska)}', style: const pw.TextStyle(fontSize: 10))),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('GOST / GUEST:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text(boravak.prezimeIme, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),

              // Tablica stavki računa
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _th('Opis usluge / Service'),
                      _th('Br. osoba\nPersons', align: pw.TextAlign.center),
                      _th('Br. dana\nDays', align: pw.TextAlign.center),
                      _th('Cijena po os.-noćenju\nPrice per person-night', align: pw.TextAlign.right),
                      _th('UKUPNO\nTOTAL (EUR)', align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _td('Noćenje / Nights'),
                      _td('${boravak.brojOsoba}', align: pw.TextAlign.center),
                      _td('${boravak.brojDana}', align: pw.TextAlign.center),
                      _td('${boravak.cijenaOsobaNoc.toStringAsFixed(2)} €', align: pw.TextAlign.right),
                      _td('${boravak.cijenaUkupno.toStringAsFixed(2)} €', align: pw.TextAlign.right, bold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Za naplatu i način plaćanja
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('ZA NAPLATU / REIMBURSE: ', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${boravak.cijenaUkupno.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Način plaćanja / Payment method: ${boravak.nacinPlacanja}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),

              // Datum, vrijeme i mjesto
              pw.Text('U Brelima, ${df.format(sad)} ${tf.format(sad)}h', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 15),

              // Zakonske napomene
              pw.Text('Boravišna pristojba uključena u cijenu usluga / Sojourn tax included in the price of the service', 
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.SizedBox(height: 4),
              pw.Text(postavke.pdvNapomena, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),

              // Zahvala
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Zahvaljujemo Vam na posjeti i nadamo se da nosite lijepe uspomene sa Vašeg odmora!\nThank you for visiting, and we hope you take home wonderful memories from your vacation!',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
