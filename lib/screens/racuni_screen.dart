// lib/screens/racuni_screen.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';
import '../services/pdf_racun_service.dart';
import '../services/escpos_printer_service.dart';

class RacuniScreen extends StatefulWidget {
  const RacuniScreen({super.key});

  @override
  State<RacuniScreen> createState() => _RacuniScreenState();
}

class _RacuniScreenState extends State<RacuniScreen> {
  // Podaci vlasnika iz Postavki (default Sunset Villa Brela)
  final _postavke = PostavkeIznajmljivaca(
    nazivObjekta: 'Sunset Villa Brela',
    imePrezime: 'Miha Šošić',
    oib: '43163137097',
    mjesto: '21322 Brela',
    adresa: 'Podrače 1',
    telefon: '+386 41 527 274',
    email: 'info@sosic-brela.com',
  );

  // Primjeri gotovih računa iz vaše tablice (100, 101, 102)
  final List<TuristBoravak> _racuni = [
    TuristBoravak(
      id: '102',
      nacinPlacanja: 'Booking',
      racunBroj: '102/26',
      prezimeIme: 'Muller Gerhard',
      datumDolaska: DateTime(2026, 10, 10),
      datumOdlaska: DateTime(2026, 10, 14),
      brojOsoba: 2,
      brojDana: 4,
      cijenaUkupno: 250.00,
      cijenaOsobaNoc: 31.25,
      racunIspisan: true,
    ),
    TuristBoravak(
      id: '101',
      nacinPlacanja: 'Booking',
      racunBroj: '101/26',
      prezimeIme: 'Craft Hugh Jonathan',
      datumDolaska: DateTime(2026, 10, 9),
      datumOdlaska: DateTime(2026, 10, 12),
      brojOsoba: 2,
      brojDana: 3,
      cijenaUkupno: 190.00,
      cijenaOsobaNoc: 31.67,
      racunIspisan: true,
    ),
    TuristBoravak(
      id: '100',
      nacinPlacanja: 'Booking',
      racunBroj: '100/26',
      prezimeIme: 'Frohlich Marco',
      datumDolaska: DateTime(2026, 10, 3),
      datumOdlaska: DateTime(2026, 10, 8),
      brojOsoba: 3,
      brojDana: 5,
      cijenaUkupno: 580.00,
      cijenaOsobaNoc: 38.67,
      racunIspisan: true,
    ),
  ];

  // Prikaz A4 PDF računa s opcijama dijeljenja i printanja
  void _otvoriPdf(TuristBoravak boravak) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text('Račun ${boravak.racunBroj}')),
          body: PdfPreview(
            build: (format) => PdfRacunService.generirajRacunPdf(
              boravak: boravak,
              postavke: _postavke,
            ),
          ),
        ),
      ),
    );
  }

  // Pretpregled za termalni 58 mm pisač
  void _prikaziTermoIspis(TuristBoravak boravak) {
    final termoTekst = EscPosPrinterService.formatirajZa58mm(
      boravak: boravak,
      postavke: _postavke,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Termo traka (58 mm) - RN ${boravak.racunBroj}'),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFFBF8E6), // Boja termalnog papira
            child: Text(
              termoTekst,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Spremno za Bluetooth slanje (čeka uparivanje printera).')),
              );
            },
            icon: const Icon(Icons.bluetooth),
            label: const Text('Ispiši (Bluetooth)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izdani računi'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.separated(
        itemCount: _racuni.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final r = _racuni[index];
          return ListTile(
            title: Text('${r.racunBroj} • ${r.prezimeIme}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold).copyWith(fontFamily: 'Roboto')),
            subtitle: Text('${r.cijenaUkupno.toStringAsFixed(2)} € • ${r.nacinPlacanja}'),
            trailing: Row(
              mainAxisSize: minAxisSize,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  tooltip: 'A4 PDF Račun',
                  onPressed: () => _otvoriPdf(r),
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Color(0xFF0D47A1)),
                  tooltip: 'Ispis na termo rolu (58 mm)',
                  onPressed: () => _prikaziTermoIspis(r),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  MainAxisSize get minAxisSize => MainAxisSize.min;
}
