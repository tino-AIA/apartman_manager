// lib/screens/knjiga_prometa_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';
import '../services/kpr_export_service.dart';

class KnjigaPrometaScreen extends StatefulWidget {
  const KnjigaPrometaScreen({super.key});

  @override
  State<KnjigaPrometaScreen> createState() => _KnjigaPrometaScreenState();
}

class _KnjigaPrometaScreenState extends State<KnjigaPrometaScreen> {
  final _postavke = PostavkeIznajmljivaca(
    nazivObjekta: 'Sunset Villa Brela',
    imePrezime: 'Miha Šošić',
    oib: '43163137097',
    mjesto: 'Brela',
    adresa: 'Podrače 1',
    telefon: '+386 41 527 274',
    email: 'info@sosic-brela.com',
  );

  // Učitani računi (uključujući zadnja tri za provjeru izračuna)
  final List<TuristBoravak> _promet = [
    TuristBoravak(id: '100', nacinPlacanja: 'Booking', racunBroj: '100/26', prezimeIme: 'Frohlich Marco', datumDolaska: DateTime(2026, 10, 3), datumOdlaska: DateTime(2026, 10, 8), brojOsoba: 3, brojDana: 5, cijenaUkupno: 580.0, cijenaOsobaNoc: 38.67),
    TuristBoravak(id: '101', nacinPlacanja: 'Booking', racunBroj: '101/26', prezimeIme: 'Craft Hugh Jonathan', datumDolaska: DateTime(2026, 10, 9), datumOdlaska: DateTime(2026, 10, 12), brojOsoba: 2, brojDana: 3, cijenaUkupno: 190.0, cijenaOsobaNoc: 31.67),
    TuristBoravak(id: '102', nacinPlacanja: 'Booking', racunBroj: '102/26', prezimeIme: 'Muller Gerhard', datumDolaska: DateTime(2026, 10, 10), datumOdlaska: DateTime(2026, 10, 14), brojOsoba: 2, brojDana: 4, cijenaUkupno: 250.0, cijenaOsobaNoc: 31.25),
  ];

  double get _ukupniPromet => _promet.fold(0.0, (sum, i) => sum + i.cijenaUkupno);

  void _izveziPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Obrazac EP - Pregled PDF-a')),
          body: PdfPreview(
            build: (format) => KprExportService.generirajKprPdf(
              stavke: _promet,
              postavke: _postavke,
              godina: 2026,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _izveziExcel() async {
    final bytes = KprExportService.generirajKprExcel(
      stavke: _promet,
      postavke: _postavke,
      godina: 2026,
    );

    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Evidencija_prometa_2026.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Knjiga prometa 2026 (Obrazac EP)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy.');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knjiga prometa (Obrazac EP)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view, color: Colors.green),
            tooltip: 'Izvezi u Excel (.xlsx)',
            onPressed: _izveziExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Službeni A4 PDF',
            onPressed: _izveziPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // Kartica s podacima poreznog obveznika
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFE8EEF5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_postavke.imePrezime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Obrazac EP', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  ],
                ),
                Text('OIB: ${_postavke.oib} • ${_postavke.adresa}, ${_postavke.mjesto}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('UKUPAN PROMET 2026:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_ukupniPromet.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D47A1))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Popis stavki prometa
          Expanded(
            child: ListView.separated(
              itemCount: _promet.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = _promet[index];
                return ListTile(
                  leading: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  title: Text(s.prezimeIme, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('RN ${s.racunBroj} • ${df.format(s.datumDolaska)}'),
                  trailing: Text('${s.cijenaUkupno.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
