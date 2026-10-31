// lib/screens/postavke_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/postavke_model.dart';
import '../services/podaci_service.dart';

class PostavkeScreen extends StatefulWidget {
  const PostavkeScreen({super.key});

  @override
  State<PostavkeScreen> createState() => _PostavkeScreenState();
}

class _PostavkeScreenState extends State<PostavkeScreen> {
  final _nazivObjektaCtrl = TextEditingController(text: 'Sunset Villa Brela');
  final _imePrezimeCtrl = TextEditingController(text: 'Miha Šošić');
  final _oibCtrl = TextEditingController(text: '43163137097');
  final _mjestoCtrl = TextEditingController(text: '21322 Brela');
  final _adresaCtrl = TextEditingController(text: 'Podrače 1');
  final _telefonCtrl = TextEditingController(text: '+386 41 527 274');
  final _emailCtrl = TextEditingController(text: 'info@sosic-brela.com');
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
      // 1. Učitavanje postavki vlasnika
      final vlasnikRes = await supabase
          .from('postavke_vlasnik')
          .select()
          .limit(1)
          .maybeSingle();

      if (vlasnikRes != null) {
        _nazivObjektaCtrl.text = vlasnikRes['naziv_objekta']?.toString() ?? _nazivObjektaCtrl.text;
        _imePrezimeCtrl.text = vlasnikRes['ime_prezime']?.toString() ?? _imePrezimeCtrl.text;
        _oibCtrl.text = vlasnikRes['oib']?.toString() ?? _oibCtrl.text;
        _mjestoCtrl.text = vlasnikRes['mjesto']?.toString() ?? _mjestoCtrl.text;
        _adresaCtrl.text = vlasnikRes['adresa']?.toString() ?? _adresaCtrl.text;
        _telefonCtrl.text = vlasnikRes['telefon']?.toString() ?? _telefonCtrl.text;
        _emailCtrl.text = vlasnikRes['email']?.toString() ?? _emailCtrl.text;
        _pdvNapomenaCtrl.text = vlasnikRes['pdv_napomena']?.toString() ?? _pdvNapomenaCtrl.text;
      }

      // 2. Učitavanje smještajnih jedinica
      final jediniceRes = await supabase
          .from('smjestajne_jedinice')
          .select()
          .order('naziv', ascending: true);

      if (jediniceRes is List && (jediniceRes as List).isNotEmpty) {
        _jedinice = (jediniceRes as List).map((j) {
          final cjenikRaw = j['cjenik'] as List<dynamic>? ?? [];
          List<SezonskiPeriod> sezonskiPeriodi = [];

          if (cjenikRaw.isNotEmpty) {
            sezonskiPeriodi = cjenikRaw.map((p) {
              return SezonskiPeriod(
                naziv: p['naziv']?.toString() ?? '',
                pocetniMjesec: int.tryParse(p['pocetniMjesec']?.toString() ?? '1') ?? 1,
                pocetniDan: int.tryParse(p['pocetniDan']?.toString() ?? '1') ?? 1,
                zavrsniMjesec: int.tryParse(p['zavrsniMjesec']?.toString() ?? '12') ?? 12,
                zavrsniDan: int.tryParse(p['zavrsniDan']?.toString() ?? '31') ?? 31,
                cijenaPoOsobiNoc: (p['cijena'] as num?)?.toDouble() ?? 30.0,
              );
            }).toList();
          }

          if (sezonskiPeriodi.isEmpty) {
            sezonskiPeriodi = [
              SezonskiPeriod(naziv: 'Izvan sezone', pocetniMjesec: 1, pocetniDan: 1, zavrsniMjesec: 4, zavrsniDan: 30, cijenaPoOsobiNoc: 25.0),
              SezonskiPeriod(naziv: 'Predsezona', pocetniMjesec: 5, pocetniDan: 1, zavrsniMjesec: 6, zavrsniDan: 15, cijenaPoOsobiNoc: 30.0),
              SezonskiPeriod(naziv: 'Glavna sezona', pocetniMjesec: 6, pocetniDan: 16, zavrsniMjesec: 8, zavrsniDan: 31, cijenaPoOsobiNoc: 45.0),
              SezonskiPeriod(naziv: 'Postsezona', pocetniMjesec: 9, pocetniDan: 1, zavrsniMjesec: 10, zavrsniDan: 31, cijenaPoOsobiNoc: 30.0),
            ];
          }

          return SmjestajnaJedinica(
            id: j['id']?.toString() ?? '',
            naziv: j['naziv']?.toString() ?? '',
            maxOsoba: int.tryParse((j['kapacitet'] ?? j['max_osoba'])?.toString() ?? '4') ?? 4,
            cjenikSezone: sezonskiPeriodi,
          );
        }).toList();
      } else {
        _jedinice = [
          SmjestajnaJedinica(
            id: '',
            naziv: 'Apartman A1 (Sunset)',
            maxOsoba: 4,
            cjenikSezone: [
              SezonskiPeriod(naziv: 'Izvan sezone', pocetniMjesec: 1, pocetniDan: 1, zavrsniMjesec: 4, zavrsniDan: 30, cijenaPoOsobiNoc: 25.0),
              SezonskiPeriod(naziv: 'Predsezona', pocetniMjesec: 5, pocetniDan: 1, zavrsniMjesec: 6, zavrsniDan: 15, cijenaPoOsobiNoc: 30.0),
              SezonskiPeriod(naziv: 'Glavna sezona', pocetniMjesec: 6, pocetniDan: 16, zavrsniMjesec: 8, zavrsniDan: 31, cijenaPoOsobiNoc: 45.0),
              SezonskiPeriod(naziv: 'Postsezona', pocetniMjesec: 9, pocetniDan: 1, zavrsniMjesec: 10, zavrsniDan: 31, cijenaPoOsobiNoc: 30.0),
            ],
          ),
        ];
      }
    } catch (e) {
      debugPrint('Greška pri učitavanju postavki: $e');
    } finally {
      if (mounted) setState(() => _ucitavanje = false);
    }
  }

  void _otvoriDijalogZaJedinicu({SmjestajnaJedinica? postojeca, int? index}) {
    final nazivCtrl = TextEditingController(text: postojeca?.naziv ?? '');
    final maxOsobaCtrl =
        TextEditingController(text: postojeca?.maxOsoba.toString() ?? '4');

    final c1 = TextEditingController(
        text: postojeca != null ? postojeca.cjenikSezone[0].cijenaPoOsobiNoc.toString() : '25.0');
    final c2 = TextEditingController(
        text: postojeca != null ? postojeca.cjenikSezone[1].cijenaPoOsobiNoc.toString() : '30.0');
    final c3 = TextEditingController(
        text: postojeca != null ? postojeca.cjenikSezone[2].cijenaPoOsobiNoc.toString() : '45.0');
    final c4 = TextEditingController(
        text: postojeca != null ? postojeca.cjenikSezone[3].cijenaPoOsobiNoc.toString() : '30.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(postojeca == null ? 'Nova smještajna jedinica' : 'Uredi smještajnu jedinicu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nazivCtrl,
                decoration: const InputDecoration(
                  labelText: 'Naziv jedinice (npr. Apartman 2)',
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
              const Text('Cijene po osobi / noć (€):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c1,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Izvan sezone', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: c2,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Predsezona', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c3,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Glavna sezona', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: c4,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Postsezona', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani')),
          ElevatedButton(
            onPressed: () {
              if (nazivCtrl.text.trim().isEmpty) return;

              final nova = SmjestajnaJedinica(
                id: postojeca?.id ?? '',
                naziv: nazivCtrl.text.trim(),
                maxOsoba: int.tryParse(maxOsobaCtrl.text) ?? 4,
                cjenikSezone: [
                  SezonskiPeriod(naziv: 'Izvan sezone', pocetniMjesec: 1, pocetniDan: 1, zavrsniMjesec: 4, zavrsniDan: 30, cijenaPoOsobiNoc: double.tryParse(c1.text) ?? 25.0),
                  SezonskiPeriod(naziv: 'Predsezona', pocetniMjesec: 5, pocetniDan: 1, zavrsniMjesec: 6, zavrsniDan: 15, cijenaPoOsobiNoc: double.tryParse(c2.text) ?? 30.0),
                  SezonskiPeriod(naziv: 'Glavna sezona', pocetniMjesec: 6, pocetniDan: 16, zavrsniMjesec: 8, zavrsniDan: 31, cijenaPoOsobiNoc: double.tryParse(c3.text) ?? 45.0),
                  SezonskiPeriod(naziv: 'Postsezona', pocetniMjesec: 9, pocetniDan: 1, zavrsniMjesec: 10, zavrsniDan: 31, cijenaPoOsobiNoc: double.tryParse(c4.text) ?? 30.0),
                ],
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
      ),
    );
  }

  Future<void> _spremiSveUBazu() async {
    setState(() => _spremam = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Spremanje postavki vlasnika
      await supabase.from('postavke_vlasnik').upsert({
        'id': '1',
        'naziv_objekta': _nazivObjektaCtrl.text.trim(),
        'ime_prezime': _imePrezimeCtrl.text.trim(),
        'oib': _oibCtrl.text.trim(),
        'mjesto': _mjestoCtrl.text.trim(),
        'adresa': _adresaCtrl.text.trim(),
        'telefon': _telefonCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'pdv_napomena': _pdvNapomenaCtrl.text.trim(),
      });

      // 2. Brisanje postojećih jedinica pa ponovni upis kako bi redoslijed i brisanja bili točni
      await supabase.from('smjestajne_jedinice').delete().neq('id', '00000000-0000-0000-0000-000000000000');

      for (var j in _jedinice) {
        final cjenikJson = j.cjenikSezone.map((p) => {
          'naziv': p.naziv,
          'pocetniMjesec': p.pocetniMjesec,
          'pocetniDan': p.pocetniDan,
          'zavrsniMjesec': p.zavrsniMjesec,
          'zavrsniDan': p.zavrsniDan,
          'cijena': p.cijenaPoOsobiNoc,
        }).toList();

        final zapis = {
          'naziv': j.naziv,
          'max_osoba': j.maxOsoba,
          'kapacitet': j.maxOsoba,
          'cijena_sezona': j.cjenikSezone.length > 2 ? j.cjenikSezone[2].cijenaPoOsobiNoc : 45.0,
          'cijena_predsezona': j.cjenikSezone.length > 1 ? j.cjenikSezone[1].cijenaPoOsobiNoc : 30.0,
          'cjenik': cjenikJson,
        };

        await supabase.from('smjestajne_jedinice').insert(zapis);
      }

      // Osvježi PodaciService da novi apartmani budu odmah dostupni u unosu boravka
      await PodaciService().ucitajIzSupabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Svi podaci i smještajne jedinice uspješno su sinkronizirani sa Supabase bazom!'),
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
              decoration: const InputDecoration(labelText: 'Naziv objekta (npr. Sunset Villa)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imePrezimeCtrl,
              decoration: const InputDecoration(labelText: 'Ime i prezime vlasnika', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _oibCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OIB vlasnika', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mjestoCtrl,
                    decoration: const InputDecoration(labelText: 'Mjesto i pošt. broj', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _adresaCtrl,
                    decoration: const InputDecoration(labelText: 'Ulica i kućni broj', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'Kontakt telefon', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Kontakt email', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pdvNapomenaCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Napomena o PDV-u na računima', border: OutlineInputBorder()),
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
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Nema dodanih smještajnih jedinica. Kliknite na "Dodaj jedinicu".', style: TextStyle(color: Colors.grey)),
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
                      title: Text(j.naziv, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Kapacitet: ${j.maxOsoba} os. | Sezona: ${j.cjenikSezone[2].cijenaPoOsobiNoc.toStringAsFixed(0)} € | Pred/Post: ${j.cjenikSezone[1].cijenaPoOsobiNoc.toStringAsFixed(0)} €',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _otvoriDijalogZaJedinicu(postojeca: j, index: idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => _jedinice.removeAt(idx)),
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
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
