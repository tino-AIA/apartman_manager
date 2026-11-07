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

  void _osvjezi() {
    if (mounted) {
      _ucitajPostavke();
      setState(() {});
    }
  }

  Future<void> _ucitajPostavke() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client.from('postavke_vlasnik').select();

      final res = user != null
          ? await query.eq('user_id', user.id).maybeSingle()
          : await query.limit(1).maybeSingle();

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

  /// Pomoćna metoda koja sortira boravke od računa br. 1 prema gore
  List<TuristBoravak> _dohvatiSortiraniPromet() {
    final lista = List<TuristBoravak>.from(_service.boravci);
    lista.sort((a, b) {
      final rbrA = int.tryParse(a.racunBroj.split('/').first) ?? 0;
      final rbrB = int.tryParse(b.racunBroj.split('/').first) ?? 0;
      if (rbrA != rbrB) {
        return rbrA.compareTo(rbrB); // Uzlazno: 1, 2, 3...
      }
      return a.datumDolaska.compareTo(b.datumDolaska);
    });
    return lista;
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

  Future<void> _izveziPdf() async {
    await _ucitajPostavke();
    if (!mounted) return;

    final sortiraniPromet = _dohvatiSortiraniPromet();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Obrazac EP - Pregled PDF-a')),
          body: PdfPreview(
            build: (format) => KprExportService.generirajKprPdf(
              stavke: sortiraniPromet,
              postavke: _postavke,
              godina: DateTime.now().year,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _izveziExcel() async {
    await _ucitajPostavke();
    final godina = DateTime.now().year;
    final sortiraniPromet = _dohvatiSortiraniPromet();

    final bytes = KprExportService.generirajKprExcel(
      stavke: sortiraniPromet,
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
    final promet = _dohvatiSortiraniPromet();
    final ukupniPromet = promet.fold<double>(0.0, (sum, i) => sum + i.cijenaUkupno);
    final godina = DateTime.now().year;
    final aktivnePostavke = _postavke.imePrezime.isNotEmpty ? _postavke : _service.postavke;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knjiga prometa (Obrazac EP)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Osvježi', style: TextStyle(fontSize: 12)),
            onPressed: () {
              _ucitajPostavke();
              _service.ucitajIzSupabase();
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade800,
              side: BorderSide(color: Colors.green.shade700),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.table_chart, size: 16),
            label: const Text('Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: promet.isEmpty ? null : _izveziExcel,
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: promet.isEmpty ? null : _izveziPdf,
          ),
          const SizedBox(width: 8),
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
                    Text(
                      aktivnePostavke.imePrezime.isNotEmpty
                          ? aktivnePostavke.imePrezime
                          : (aktivnePostavke.nazivObjekta.isNotEmpty ? aktivnePostavke.nazivObjekta : 'Vlasnik'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Text('Obrazac EP', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  ],
                ),
                Text('OIB: ${aktivnePostavke.oib} • ${aktivnePostavke.adresa}, ${aktivnePostavke.mjesto}'),
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
