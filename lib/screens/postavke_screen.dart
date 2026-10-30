// lib/screens/postavke_screen.dart
import 'package:flutter/material.dart';
import '../models/postavke_model.dart';

class PostavkeScreen extends StatefulWidget {
  const PostavkeScreen({super.key});

  @override
  State<PostavkeScreen> createState() => _PostavkeScreenState();
}

class _PostavkeScreenState extends State<PostavkeScreen> {
  // 1. Podaci o objektu i vlasniku (predefinirano prema tablici Brela)
  final _nazivObjektaCtrl = TextEditingController(text: 'Sunset Villa Brela');
  final _imePrezimeCtrl = TextEditingController(text: 'Miha Šošić');
  final _oibCtrl = TextEditingController(text: '43163137097');
  final _mjestoCtrl = TextEditingController(text: '21322 Brela');
  final _adresaCtrl = TextEditingController(text: 'Podrače 1');
  final _telefonCtrl = TextEditingController(text: '+386 41 527 274');
  final _emailCtrl = TextEditingController(text: 'info@sosic-brela.com');
  final _pdvNapomenaCtrl = TextEditingController(
    text: 'Obveznik nije u sustavu PDV-a, sukladno odredbama čl. 90. st. 2. Zakona o PDV-u. PDV nije obračunat.',
  );

  // 2. Dinamička lista smještajnih jedinica s cijenama po 4 sezone
  final List<SmjestajnaJedinica> _jedinice = [
    SmjestajnaJedinica(
      id: '1',
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

  // Dijalog za dodavanje ili uređivanje smještajne jedinice
  void _otvoriDijalogZaJedinicu({SmjestajnaJedinica? postojeca, int? index}) {
    final nazivCtrl = TextEditingController(text: postojeca?.naziv ?? '');
    final maxOsobaCtrl = TextEditingController(text: postojeca?.maxOsoba.toString() ?? '4');
    
    // Cijene za 4 sezone
    final c1 = TextEditingController(text: postojeca != null ? postojeca.cjenikSezone[0].cijenaPoOsobiNoc.toString() : '25.0');
    final c2 = TextEditingController(text: postojeca != null ? postojeca.cjenikSezone[1].cijenaPoOsobiNoc.toString() : '30.0');
    final c3 = TextEditingController(text: postojeca != null ? postojeca.cjenikSezone[2].cijenaPoOsobiNoc.toString() : '45.0');
    final c4 = TextEditingController(text: postojeca != null ? postojeca.cjenikSezone[3].cijenaPoOsobiNoc.toString() : '30.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(postojeca == null ? 'Nova smještajna jedinica' : 'Uredi smještajnu jedinicu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nazivCtrl, decoration: const InputDecoration(labelText: 'Naziv jedinice (npr. Apartman 2)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: maxOsobaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kapacitet (max osoba)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              const Text('Cijene po osobi / noć (€):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: c1, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Izvan sezone', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: c2, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Predsezona', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: c3, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Glavna sezona', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: c4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Postsezona', border: OutlineInputBorder()))),
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
                id: postojeca?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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

  @override
  Widget build(BuildContext context) {
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
            // SEKCIJA 1: Podaci o objektu i vlasniku
            const Text('Podaci o objektu i vlasniku', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 12),
            TextField(controller: _nazivObjektaCtrl, decoration: const InputDecoration(labelText: 'Naziv objekta (npr. Sunset Villa)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _imePrezimeCtrl, decoration: const InputDecoration(labelText: 'Ime i prezime vlasnika', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _oibCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OIB vlasnika', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _mjestoCtrl, decoration: const InputDecoration(labelText: 'Mjesto i pošt. broj', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _adresaCtrl, decoration: const InputDecoration(labelText: 'Ulica i kućni broj', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _telefonCtrl, decoration: const InputDecoration(labelText: 'Kontakt telefon', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Kontakt email', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: _pdvNapomenaCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Napomena o PDV-u na računima', border: OutlineInputBorder())),

            const Divider(height: 40, thickness: 1.5),

            // SEKCIJA 2: Upravljanje smještajnim jedinicama
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Smještajne jedinice', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
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

            // Gumb za spremanje svih postavki
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Svi podaci objekta i smještajne jedinice uspješno spremljeni!')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('SPREMI SVE POSTAVKE', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
