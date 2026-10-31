// lib/screens/postavke_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/postavke_model.dart';
import '../services/podaci_service.dart';

class PostavkeScreen extends StatefulWidget {
  const PostavkeScreen({super.key});

  @override
  State<PostavkeScreen> createState() => _PostavkeScreenState();
}

class _PostavkeScreenState extends State<PostavkeScreen> {
  static const String _vlasnikUuid = '00000000-0000-0000-0000-000000000001';

  final _nazivObjektaCtrl = TextEditingController();
  final _imePrezimeCtrl = TextEditingController();
  final _oibCtrl = TextEditingController();
  final _mjestoCtrl = TextEditingController();
  final _adresaCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pdvNapomenaCtrl = TextEditingController(
    text:
        'Obveznik nije u sustavu PDV-a, sukladno odredbama čl. 90. st. 2. Zakona o PDV-u. PDV nije obračunat.',
  );

  List<SmjestajnaJedinica> _jedinice = [];
  bool _ucitavanje = true;
  bool _spremam = false;

  @override
  void initState() {
    super.initState();
    _ucitajPodatkeIzBaze();
  }

  @override
  void dispose() {
    _nazivObjektaCtrl.dispose();
    _imePrezimeCtrl.dispose();
    _oibCtrl.dispose();
    _mjestoCtrl.dispose();
    _adresaCtrl.dispose();
    _telefonCtrl.dispose();
    _emailCtrl.dispose();
    _pdvNapomenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ucitajPodatkeIzBaze() async {
    setState(() => _ucitavanje = true);
    final supabase = Supabase.instance.client;

    try {
      final vlasnikRes = await supabase
          .from('postavke_vlasnik')
          .select()
          .limit(1)
          .maybeSingle();

      if (vlasnikRes != null) {
        _nazivObjektaCtrl.text = vlasnikRes['naziv_objekta']?.toString() ?? '';
        _imePrezimeCtrl.text = vlasnikRes['ime_prezime']?.toString() ?? '';
        _oibCtrl.text = vlasnikRes['oib']?.toString() ?? '';
        _mjestoCtrl.text = vlasnikRes['mjesto']?.toString() ?? '';
        _adresaCtrl.text = vlasnikRes['adresa']?.toString() ?? '';
        _telefonCtrl.text = vlasnikRes['telefon']?.toString() ?? '';
        _emailCtrl.text = vlasnikRes['email']?.toString() ?? '';
        if (vlasnikRes['pdv_napomena'] != null &&
            vlasnikRes['pdv_napomena'].toString().isNotEmpty) {
          _pdvNapomenaCtrl.text = vlasnikRes['pdv_napomena'].toString();
        }
      }

      final jediniceRes = await supabase
          .from('smjestajne_jedinice')
          .select()
          .order('naziv', ascending: true);

      if (jediniceRes is List && (jediniceRes as List).isNotEmpty) {
        _jedinice = (jediniceRes as List).map((j) {
          final cjenikRaw = (j['cjenik_sezone'] ?? j['cjenik']) as List<dynamic>? ?? [];
          List<SezonskiPeriod> sezonskiPeriodi = [];

          if (cjenikRaw.isNotEmpty) {
            sezonskiPeriodi = cjenikRaw.map((p) {
              return SezonskiPeriod(
                naziv: p['naziv']?.toString() ?? '',
                pocetniMjesec:
                    int.tryParse(p['pocetniMjesec']?.toString() ?? '1') ?? 1,
                pocetniDan:
                    int.tryParse(p['pocetniDan']?.toString() ?? '1') ?? 1,
                zavrsniMjesec:
                    int.tryParse(p['zavrsniMjesec']?.toString() ?? '12') ?? 12,
                zavrsniDan:
                    int.tryParse(p['zavrsniDan']?.toString() ?? '31') ?? 31,
                cijenaPoOsobiNoc:
                    (p['cijena'] as num?)?.toDouble() ?? 0.0,
              );
            }).toList();
          }

          if (sezonskiPeriodi.isEmpty) {
            sezonskiPeriodi = _kreirajPodrazumijevaneSezone();
          }

          return SmjestajnaJedinica(
            id: j['id']?.toString() ?? '',
            naziv: j['naziv']?.toString() ?? '',
            maxOsoba: int.tryParse(
                    (j['max_osoba'] ?? j['kapacitet'])?.toString() ?? '4') ??
                4,
            cjenikSezone: sezonskiPeriodi,
          );
        }).toList();
      } else {
        _jedinice = [];
      }
    } catch (e) {
      debugPrint('Greška pri učitavanju postavki: $e');
    } finally {
      if (mounted) setState(() => _ucitavanje = false);
    }
  }

  static List<SezonskiPeriod> _kreirajPodrazumijevaneSezone() {
    return [
      SezonskiPeriod(
          naziv: 'Izvan sezone',
          pocetniMjesec: 1,
          pocetniDan: 1,
          zavrsniMjesec: 4,
          zavrsniDan: 30,
          cijenaPoOsobiNoc: 25.0),
      SezonskiPeriod(
          naziv: 'Predsezona',
          pocetniMjesec: 5,
          pocetniDan: 1,
          zavrsniMjesec: 6,
          zavrsniDan: 15,
          cijenaPoOsobiNoc: 30.0),
      SezonskiPeriod(
          naziv: 'Glavna sezona',
          pocetniMjesec: 6,
          pocetniDan: 16,
          zavrsniMjesec: 8,
          zavrsniDan: 31,
          cijenaPoOsobiNoc: 45.0),
      SezonskiPeriod(
          naziv: 'Postsezona',
          pocetniMjesec: 9,
          pocetniDan: 1,
          zavrsniMjesec: 10,
          zavrsniDan: 31,
          cijenaPoOsobiNoc: 30.0),
    ];
  }

  void _otvoriDijalogZaJedinicu({SmjestajnaJedinica? postojeca, int? index}) {
    final nazivCtrl = TextEditingController(text: postojeca?.naziv ?? '');
    final maxOsobaCtrl =
        TextEditingController(text: postojeca?.maxOsoba.toString() ?? '4');

    List<SezonskiPeriod> radneSezone = [];
    if (postojeca != null && postojeca.cjenikSezone.isNotEmpty) {
      for (var s in postojeca.cjenikSezone) {
        radneSezone.add(SezonskiPeriod(
          naziv: s.naziv,
          pocetniMjesec: s.pocetniMjesec,
          pocetniDan: s.pocetniDan,
          zavrsniMjesec: s.zavrsniMjesec,
          zavrsniDan: s.zavrsniDan,
          cijenaPoOsobiNoc: s.cijenaPoOsobiNoc,
        ));
      }
    } else {
      radneSezone = _kreirajPodrazumijevaneSezone();
    }

    final cijeneKontroleri = radneSezone
        .map((s) => TextEditingController(text: s.cijenaPoOsobiNoc.toString()))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final df = DateFormat('dd.MM.');
          final godina = DateTime.now().year;

          return AlertDialog(
            title: Text(postojeca == null
                ? 'Nova smještajna jedinica'
                : 'Uredi smještajnu jedinicu'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nazivCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Naziv jedinice (npr. De luxe, Sunny...)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxOsobaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kapacitet (max osoba)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Sezonski periodi i cijene (€):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    ...List.generate(radneSezone.length, (i) {
                      final sezona = radneSezone[i];
                      final dPocetak = DateTime(
                          godina, sezona.pocetniMjesec, sezona.pocetniDan);
                      final dKraj = DateTime(
                          godina, sezona.zavrsniMjesec, sezona.zavrsniDan);
                      final rasponTekst =
                          '${df.format(dPocetak)} - ${df.format(dKraj)}';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sezona.naziv,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D47A1))),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.date_range,
                                          size: 18),
                                      label: Text(rasponTekst,
                                          style:
                                              const TextStyle(fontSize: 12)),
                                      onPressed: () async {
                                        final odabrani =
                                            await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime(godina, 1, 1),
                                          lastDate: DateTime(godina, 12, 31),
                                          initialDateRange: DateTimeRange(
                                              start: dPocetak, end: dKraj),
                                          helpText:
                                              'Odaberite raspon: ${sezona.naziv}',
                                        );
                                        if (odabrani != null) {
                                          setDialogState(() {
                                            radneSezone[i] = SezonskiPeriod(
                                              naziv: sezona.naziv,
                                              pocetniMjesec:
                                                  odabrani.start.month,
                                              pocetniDan: odabrani.start.day,
                                              zavrsniMjesec: odabrani.end.month,
                                              zavrsniDan: odabrani.end.day,
                                              cijenaPoOsobiNoc:
                                                  sezona.cijenaPoOsobiNoc,
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: cijeneKontroleri[i],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Cijena/noć',
                                        suffixText: '€',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Odustani')),
              ElevatedButton(
                onPressed: () {
                  if (nazivCtrl.text.trim().isEmpty) return;

                  List<SezonskiPeriod> finalneSezone = [];
                  for (int i = 0; i < radneSezone.length; i++) {
                    final novaCijena = double.tryParse(
                            cijeneKontroleri[i].text.replaceAll(',', '.')) ??
                        0.0;
                    finalneSezone.add(SezonskiPeriod(
                      naziv: radneSezone[i].naziv,
                      pocetniMjesec: radneSezone[i].pocetniMjesec,
                      pocetniDan: radneSezone[i].pocetniDan,
                      zavrsniMjesec: radneSezone[i].zavrsniMjesec,
                      zavrsniDan: radneSezone[i].zavrsniDan,
                      cijenaPoOsobiNoc: novaCijena,
                    ));
                  }

                  final idJedinice = (postojeca != null && postojeca.id.isNotEmpty)
                      ? postojeca.id
                      : '';

                  final nova = SmjestajnaJedinica(
                    id: idJedinice,
                    naziv: nazivCtrl.text.trim(),
                    maxOsoba: int.tryParse(maxOsobaCtrl.text) ?? 4,
                    cjenikSezone: finalneSezone,
                  );

                  setState(() {
                    if (index != null) {
                      _jedinice[index] = nova;
                    } else {
                      _jedinice.add(nova);
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Spremi jedinicu'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _spremiSveUBazu() async {
    setState(() => _spremam = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Spremanje postavki vlasnika
      await supabase.from('postavke_vlasnik').upsert({
        'id': _vlasnikUuid,
        'naziv_objekta': _nazivObjektaCtrl.text.trim(),
        'ime_prezime': _imePrezimeCtrl.text.trim(),
        'oib': _oibCtrl.text.trim(),
        'mjesto': _mjestoCtrl.text.trim(),
        'adresa': _adresaCtrl.text.trim(),
        'telefon': _telefonCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'pdv_napomena': _pdvNapomenaCtrl.text.trim(),
      });

      // 2. Brisanje starih jedinica i upis novih
      await supabase
          .from('smjestajne_jedinice')
          .delete()
          .neq('naziv', '__NEPOSTOJECA_STAVKA__');

      for (var j in _jedinice) {
        final cjenikJson = j.cjenikSezone
            .map((p) => {
                  'naziv': p.naziv,
                  'pocetniMjesec': p.pocetniMjesec,
                  'pocetniDan': p.pocetniDan,
                  'zavrsniMjesec': p.zavrsniMjesec,
                  'zavrsniDan': p.zavrsniDan,
                  'cijena': p.cijenaPoOsobiNoc,
                })
            .toList();

        final Map<String, dynamic> zapis = {
          'naziv': j.naziv,
          'max_osoba': j.maxOsoba,
          'kapacitet': j.maxOsoba,
          'cijena_sezona': j.cjenikSezone.length > 2
              ? j.cjenikSezone[2].cijenaPoOsobiNoc
              : 0.0,
          'cijena_predsezona': j.cjenikSezone.length > 1
              ? j.cjenikSezone[1].cijenaPoOsobiNoc
              : 0.0,
          'cjenik': cjenikJson,
          'cjenik_sezone': cjenikJson,
        };

        if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(j.id)) {
          zapis['id'] = j.id;
        }

        await supabase.from('smjestajne_jedinice').insert(zapis);
      }

      await PodaciService().ucitajIzSupabase();
      await _ucitajPodatkeIzBaze();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Svi podaci i smještajne jedinice uspješno su spremljeni u bazu!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri spremanju u bazu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _spremam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ucitavanje) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final df = DateFormat('dd.MM.');
    final godina = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Postavke iznajmljivača'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podaci o objektu i vlasniku',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nazivObjektaCtrl,
              decoration: const InputDecoration(
                  labelText: 'Naziv objekta (npr. Sunset Villa)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imePrezimeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Ime i prezime vlasnika',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _oibCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'OIB vlasnika', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mjestoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Mjesto i pošt. broj',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _adresaCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Ulica i kućni broj',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _telefonCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Kontakt telefon',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Kontakt email',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pdvNapomenaCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Napomena o PDV-u na računima',
                  border: OutlineInputBorder()),
            ),
            const Divider(height: 40, thickness: 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Smještajne jedinice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _otvoriDijalogZaJedinicu(),
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj jedinicu'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_jedinice.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'Trenutno nema dodanih smještajnih jedinica.\nKliknite na gornji gumb "+ Dodaj jedinicu" za unos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _jedinice.length,
                itemBuilder: (context, idx) {
                  final j = _jedinice[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0D47A1),
                        child: Icon(Icons.meeting_room, color: Colors.white),
                      ),
                      title: Text(j.naziv,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kapacitet: ${j.maxOsoba} osoba'),
                          const SizedBox(height: 4),
                          ...j.cjenikSezone.map((s) {
                            final d1 = DateTime(
                                godina, s.pocetniMjesec, s.pocetniDan);
                            final d2 = DateTime(
                                godina, s.zavrsniMjesec, s.zavrsniDan);
                            return Text(
                              '• ${s.naziv} (${df.format(d1)} - ${df.format(d2)}): ${s.cijenaPoOsobiNoc.toStringAsFixed(0)} €',
                              style: const TextStyle(fontSize: 12),
                            );
                          }),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _otvoriDijalogZaJedinicu(
                                postojeca: j, index: idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => _jedinice.removeAt(idx)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
                onPressed: _spremam ? null : _spremiSveUBazu,
                icon: _spremam
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _spremam ? 'SPREMANJE U BAZU...' : 'SPREMI SVE POSTAVKE',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
