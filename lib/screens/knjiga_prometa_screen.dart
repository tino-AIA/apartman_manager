// lib/screens/knjiga_prometa_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';
import '../services/podaci_service.dart';
import '../services/kpr_export_service.dart';
import 'novi_turist_screen.dart';

class KnjigaPrometaScreen extends StatefulWidget {
  const KnjigaPrometaScreen({super.key});

  @override
  State<KnjigaPrometaScreen> createState() => _KnjigaPrometaScreenState();
}

class _KnjigaPrometaScreenState extends State<KnjigaPrometaScreen> {
  final _service = PodaciService();

  PostavkeIznajmljivaca _postavke = PostavkeIznajmljivaca(
    nazivObjekta: '',
    imePrezime: '',
    oib: '',
    mjesto: '',
    adresa: '',
    telefon: '',
    email: '',
  );

  @override
  void initState() {
    super.initState();
    _service.addListener(_osvjezi);
    _ucitajPostavke();
  }

  @override
  void dispose() {
    _service.removeListener(_osvjezi);
    super.dispose();
  }

  void _osvjezi() => setState(() {});

  Future<void> _ucitajPostavke() async {
    try {
      final res = await Supabase.instance.client
          .from('postavke_vlasnik')
          .select()
          .limit(1)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _postavke = PostavkeIznajmljivaca(
            nazivObjekta: res['naziv_objekta']?.toString() ?? '',
            imePrezime: res['ime_prezime']?.toString() ?? '',
            oib: res['oib']?.toString() ?? '',
            mjesto: res['mjesto']?.toString() ?? '',
            adresa: res['adresa']?.toString() ?? '',
            telefon: res['telefon']?.toString() ?? '',
            email: res['email']?.toString() ?? '',
            pdvNapomena: res['pdv_napomena']?.toString() ??
                'Obveznik nije u sustavu PDV-a, sukladno odredbama čl. 90. st. 2. Zakona o PDV-u. PDV nije obračunat.',
          );
        });
      }
    } catch (e) {
      debugPrint('Greška pri dohvaćanju postavki za Knjigu EP: $e');
    }
  }

  void _potvrdiBrisanje(BuildContext context, TuristBoravak b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja iz Knjige EP'),
        content: Text(
          'Sigurno želite obrisati stavku "${b.prezimeIme}" (Račun ${b.racunBroj})?\n\n'
          'Redni brojevi u Knjizi prometa i svi računi iza njega automatski će se uskladiti.',
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
                const SnackBar(content: Text('Stavka obrisana. Knjiga prometa je usklađena.')),
              );
            },
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _izveziPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Obrazac EP - Pregled PDF-a')),
          body: PdfPreview(
            build: (format) => KprExportService.generirajKprPdf(
              stavke: _service.boravci,
              postavke: _postavke,
              godina: DateTime.now().year,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _izveziExcel() async {
    final godina = DateTime.now().year;
    final bytes = KprExportService.generirajKprExcel(
      stavke: _service.boravci,
      postavke: _postavke,
      godina: godina,
    );

    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Evidencija_prometa_$godina.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Knjiga prometa $godina (Obrazac EP)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy.');
    final promet = _service.boravci;
    final ukupniPromet = promet.fold<double>(0.0, (sum, i) => sum + i.cijenaUkupno);
    final godina = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knjiga prometa (Obrazac EP)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view, color: Colors.green),
            tooltip: 'Izvezi u Excel (.xlsx)',
            onPressed: promet.isEmpty ? null : _izveziExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Službeni A4 PDF',
            onPressed: promet.isEmpty ? null : _izveziPdf,
          ),
        ],
      ),
      body: Column(
        children: [
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
                    Text(_postavke.imePrezime.isNotEmpty ? _postavke.imePrezime : _postavke.nazivObjekta,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Obrazac EP', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  ],
                ),
                Text('OIB: ${_postavke.oib} • ${_postavke.adresa}, ${_postavke.mjesto}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('UKUPAN PROMET $godina:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${ukupniPromet.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D47A1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: promet.isEmpty
                ? const Center(
                    child: Text(
                      'Knjiga prometa je prazna.\nUnesite boravke na popisu turista.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    itemCount: promet.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = promet[index];
                      final redniBroj = index + 1;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey.shade300,
                          child: Text(
                            '$redniBroj',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        title: Text(s.prezimeIme, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('RN ${s.racunBroj} • ${df.format(s.datumDolaska)} • ${s.apartmanNaziv}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${s.cijenaUkupno.toStringAsFixed(2)} €',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (val) {
                                if (val == 'uredi') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoviTuristScreen(postojeci: s),
                                    ),
                                  );
                                } else if (val == 'obrisi') {
                                  _potvrdiBrisanje(context, s);
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
          ),
        ],
      ),
    );
  }
}
