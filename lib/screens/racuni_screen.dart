// lib/screens/racuni_screen.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';
import '../services/podaci_service.dart';
import '../services/pdf_racun_service.dart';
import '../services/escpos_printer_service.dart';
import 'novi_turist_screen.dart';

class RacuniScreen extends StatefulWidget {
  const RacuniScreen({super.key});

  @override
  State<RacuniScreen> createState() => _RacuniScreenState();
}

class _RacuniScreenState extends State<RacuniScreen> {
  final _service = PodaciService();

  final _postavke = PostavkeIznajmljivaca(
    nazivObjekta: 'Sunset Villa Brela',
    imePrezime: 'Miha Šošić',
    oib: '43163137097',
    mjesto: '21322 Brela',
    adresa: 'Podrače 1',
    telefon: '+386 41 527 274',
    email: 'info@sosic-brela.com',
  );

  @override
  void initState() {
    super.initState();
    _service.addListener(_osvjezi);
  }

  @override
  void dispose() {
    _service.removeListener(_osvjezi);
    super.dispose();
  }

  void _osvjezi() => setState(() {});

  void _potvrdiBrisanje(BuildContext context, TuristBoravak b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja računa'),
        content: Text(
          'Sigurno želite obrisati račun ${b.racunBroj} (${b.prezimeIme})?\n\n'
          'Svi sljedeći računi i stavke u Knjizi prometa automatski će se renumerirati (npr. račun 4 postaje 3).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _service.obrisiBoravak(b.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Račun ${b.racunBroj} obrisan. Redoslijed je usklađen.')),
              );
            },
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
            color: const Color(0xFFFBF8E6),
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
                const SnackBar(content: Text('Spremno za Bluetooth slanje na pisač.')),
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
    final racuni = _service.boravci;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Izdani računi'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: racuni.isEmpty
          ? const Center(
              child: Text(
                'Nema izdanih računa.\nNovi računi nastaju unosom gosta na popisu turista.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: racuni.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = racuni[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D47A1),
                    child: Text(
                      r.racunBroj.split('/').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  title: Text(
                    '${r.racunBroj} • ${r.prezimeIme}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${r.cijenaUkupno.toStringAsFixed(2)} € • ${r.nacinPlacanja} • ${r.apartmanNaziv}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
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
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (val) {
                          if (val == 'uredi') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NoviTuristScreen(postojeci: r),
                              ),
                            );
                          } else if (val == 'obrisi') {
                            _potvrdiBrisanje(context, r);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'uredi',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Uredi'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'obrisi',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Obriši', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
