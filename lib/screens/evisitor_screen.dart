// lib/screens/evisitor_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/evisitor_service.dart';

class EvisitorScreen extends StatefulWidget {
  const EvisitorScreen({super.key});

  @override
  State<EvisitorScreen> createState() => _EvisitorScreenState();
}

class _EvisitorScreenState extends State<EvisitorScreen> {
  final _evisitorService = EvisitorService();
  List<EvisitorKandidat> _kandidati = [];
  final Set<int> _odabraniIndeksi = {};
  bool _ucitavanje = false;

  @override
  void initState() {
    super.initState();
    _osvjezi();
  }

  void _osvjezi() {
    setState(() {
      _kandidati = _evisitorService.dohvatiNeprijavljeneGoste(maxDanaUnatrag: 7);
      _odabraniIndeksi.clear();
      for (int i = 0; i < _kandidati.length; i++) {
        _odabraniIndeksi.add(i);
      }
    });
  }

  Future<void> _pokreniExport() async {
    final odabrani = _odabraniIndeksi.map((i) => _kandidati[i]).toList();
    if (odabrani.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Molimo odaberite barem jednog gosta za izvoz.')),
      );
      return;
    }

    setState(() => _ucitavanje = true);
    final uspjeh = await _evisitorService.generirajIExportajCsv(odabrani);
    setState(() => _ucitavanje = false);

    if (uspjeh && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Označi goste kao prijavljene?'),
          content: Text(
            'Generiran je CSV za ${odabrani.length} gostiju.\n\n'
            'Želite li ih označiti kao prijavljene kako se ne bi ponavljali u sljedećim izvozima?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ne, ostavi ih neprijavljenima'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _evisitorService.oznaciKaoPrijavljene(odabrani);
                _osvjezi();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Status uspješno ažuriran!')),
                  );
                }
              },
              child: const Text('Da, označi kao prijavljene', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy.');

    return Scaffold(
      appBar: AppBar(
        title: const Text('eVisitor Prijava (CSV)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _osvjezi,
          ),
        ],
      ),
      body: _kandidati.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Nema novih neprijavljenih gostiju iz zadnjih 7 dana.\n\nSvi boravci su već izvezeni ili prijavljeni.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Odaberite goste za generiranje datoteke. Uključeni su dolasci u zadnjih 7 dana.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _kandidati.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final k = _kandidati[i];
                      final g = k.gost;
                      final b = k.boravak;
                      final odabran = _odabraniIndeksi.contains(i);

                      final satiOdDolaska = DateTime.now().difference(b.datumDolaska).inHours;
                      final jePreko24h = satiOdDolaska > 24;

                      return CheckboxListTile(
                        value: odabran,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _odabraniIndeksi.add(i);
                            } else {
                              _odabraniIndeksi.remove(i);
                            }
                          });
                        },
                        title: Text(
                          g.prezimeIme,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${b.apartmanNaziv} • Dolazak: ${df.format(b.datumDolaska)}'),
                            Text(
                              '${g.vrstaDokumenta}: ${g.brojDokumenta.isNotEmpty ? g.brojDokumenta : "(nema broja)"} • ${g.drzavljanstvo}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (jePreko24h)
                              const Text(
                                'Upozorenje: Dolazak je bio prije više od 24 sata',
                                style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _ucitavanje || _odabraniIndeksi.isEmpty ? null : _pokreniExport,
                    icon: _ucitavanje
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download),
                    label: Text(
                      _ucitavanje
                          ? 'GENERIRANJE...'
                          : 'IZVEZI CSV ZA ODABRANE (${_odabraniIndeksi.length})',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
