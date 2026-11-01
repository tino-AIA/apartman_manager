// lib/screens/novi_turist_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/turist_model.dart';
import '../services/podaci_service.dart';
import '../services/ocr_service.dart';

class NoviTuristScreen extends StatefulWidget {
  final TuristBoravak? postojeci;
  const NoviTuristScreen({super.key, this.postojeci});

  @override
  State<NoviTuristScreen> createState() => _NoviTuristScreenState();
}

class _NoviTuristScreenState extends State<NoviTuristScreen> {
  final _service = PodaciService();
  final _ocrService = OcrService();

  late String _odabraniApartman;
  late String _nacinPlacanja;
  late DateTime _dolazak;
  late DateTime _odlazak;

  final List<TextEditingController> _imeControllers = [];
  final List<String> _brojeviDokumenata = [];
  int _nositeljIndex = 0;

  final _cijenaController = TextEditingController();
  bool _spremam = false;

  @override
  void initState() {
    super.initState();
    if (widget.postojeci != null) {
      final p = widget.postojeci!;
      _odabraniApartman = p.apartmanNaziv;
      _nacinPlacanja = p.nacinPlacanja;
      _dolazak = p.datumDolaska;
      _odlazak = p.datumOdlaska;
      for (final g in p.gosti) {
        _imeControllers.add(TextEditingController(text: g.prezimeIme));
        _brojeviDokumenata.add(g.brojDokumenta);
      }
      _nositeljIndex = p.gosti.indexWhere((g) => g.nositeljRacuna);
      if (_nositeljIndex == -1) _nositeljIndex = 0;
      _cijenaController.text = p.cijenaOsobaNoc.toStringAsFixed(2);
    } else {
      _odabraniApartman = _service.apartmani.isNotEmpty
          ? _service.apartmani.first.naziv
          : 'Apartman A1';
      _nacinPlacanja = 'Gotovina / Cash';

      // Automatski postavi datume na prvi sljedeći slobodni period za apartman
      _postaviPrviSlobodanTermin(_odabraniApartman);

      _imeControllers.add(TextEditingController());
      _brojeviDokumenata.add('');
      _cijenaController.text = _service
          .dohvatiCijenuZaDatum(_dolazak, apartmanNaziv: _odabraniApartman)
          .toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final c in _imeControllers) {
      c.dispose();
    }
    _cijenaController.dispose();
    super.dispose();
  }

  int get _maxKapacitet {
    final ap = _service.apartmani.firstWhere(
      (a) => a.naziv == _odabraniApartman,
      orElse: () => ApartmanModel(id: '', naziv: '', kapacitet: 10),
    );
    return ap.kapacitet > 0 ? ap.kapacitet : 10;
  }

  /// Pronalazi zadnji dan zauzeća za apartman i postavlja dolazak na taj dan (ili danas ako je slobodan)
  void _postaviPrviSlobodanTermin(String apartmanNaziv) {
    final zauzetiBoravci = _service.boravci
        .where((b) => b.apartmanNaziv == apartmanNaziv && b.id != widget.postojeci?.id)
        .toList();

    DateTime predlozeniDolazak = DateTime.now();

    if (zauzetiBoravci.isNotEmpty) {
      // Sortiraj po datumu odlaska uzlazno
      zauzetiBoravci.sort((a, b) => a.datumOdlaska.compareTo(b.datumOdlaska));
      final zadnjiOdlazak = zauzetiBoravci.last.datumOdlaska;

      // Ako je zadnji odlazak u budućnosti, sljedeći gost može doći na dan odlaska prethodnog
      if (zadnjiOdlazak.isAfter(predlozeniDolazak)) {
        predlozeniDolazak = zadnjiOdlazak;
      }
    }

    _dolazak = DateTime(predlozeniDolazak.year, predlozeniDolazak.month, predlozeniDolazak.day);
    _odlazak = _dolazak.add(const Duration(days: 7));
  }

  /// Provjera preklapanja: novi boravak se preklapa ako je novi dolazak prije postojećeg odlaska,
  /// a novi odlazak poslije postojećeg dolaska.
  TuristBoravak? _pronadiPreklapanje(DateTime start, DateTime end, String apartman) {
    for (var b in _service.boravci) {
      if (widget.postojeci != null && b.id == widget.postojeci!.id) continue;
      if (b.apartmanNaziv != apartman) continue;

      final postojeciStart = DateTime(b.datumDolaska.year, b.datumDolaska.month, b.datumDolaska.day);
      final postojeciEnd = DateTime(b.datumOdlaska.year, b.datumOdlaska.month, b.datumOdlaska.day);

      // Preklapanje termina
      if (start.isBefore(postojeciEnd) && end.isAfter(postojeciStart)) {
        return b;
      }
    }
    return null;
  }

  int get _brojNoci {
    final diff = _odlazak.difference(_dolazak).inDays;
    return diff <= 0 ? 1 : diff;
  }

  int get _brojOsoba => _imeControllers.length;

  double get _cijenaPoOsobi =>
      double.tryParse(_cijenaController.text.replaceAll(',', '.')) ?? 0.0;

  double get _ukupno => _brojNoci * _brojOsoba * _cijenaPoOsobi;

  void _preracunajCijenuPremaDatumu() {
    setState(() {
      _cijenaController.text = _service
          .dohvatiCijenuZaDatum(_dolazak, apartmanNaziv: _odabraniApartman)
          .toStringAsFixed(2);
    });
  }

  Future<void> _skenirajZaGosta(int index) async {
    final doc = await _ocrService.skenirajDokument(context);
    if (doc != null && doc.punoIme.isNotEmpty) {
      setState(() {
        _imeControllers[index].text = doc.punoIme;
        _brojeviDokumenata[index] = doc.brojDokumenta;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Očitano: ${doc.punoIme} ${doc.brojDokumenta.isNotEmpty ? "(${doc.brojDokumenta})" : ""}',
            ),
          ),
        );
      }
    }
  }

  void _dodajNovogGosta() {
    // Pravilo 3: Onemogućavanje unosa većeg broja gostiju od kapaciteta
    if (_imeControllers.length >= _maxKapacitet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maksimalni kapacitet za apartman "$_odabraniApartman" je $_maxKapacitet osoba.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _imeControllers.add(TextEditingController());
      _brojeviDokumenata.add('');
    });
  }

  void _ukloniGosta(int index) {
    if (_imeControllers.length <= 1) return;
    setState(() {
      _imeControllers[index].dispose();
      _imeControllers.removeAt(index);
      _brojeviDokumenata.removeAt(index);
      if (_nositeljIndex >= _imeControllers.length) {
        _nositeljIndex = 0;
      }
    });
  }

  Future<void> _spremi() async {
    // Pravilo: Obvezan unos barem 1 osobe s imenom i prezimenom
    final uneseniGosti = _imeControllers
        .map((c) => c.text.trim())
        .where((ime) => ime.isNotEmpty)
        .toList();

    if (uneseniGosti.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nije moguće spremiti boravak bez unosa barem jedne osobe (prezime i ime).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Provjera nositelja računa
    final nositeljIme = _imeControllers[_nositeljIndex].text.trim();
    if (nositeljIme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Molimo unesite prezime i ime nositelja računa.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Provjera preklapanja prije spremanja
    final konflikt = _pronadiPreklapanje(_dolazak, _odlazak, _odabraniApartman);
    if (konflikt != null) {
      final df = DateFormat('dd.MM.yyyy.');
      final t1 = df.format(konflikt.datumDolaska);
      final t2 = df.format(konflikt.datumOdlaska);
      _prikaziDijalogZauzetosti(konflikt.prezimeIme, t1, t2);
      return;
    }

    // Provjera kapaciteta
    if (_imeControllers.length > _maxKapacitet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Broj prijavljenih osoba prelazi kapacitet ($_maxKapacitet).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_spremam) return;
    setState(() => _spremam = true);

    try {
      List<GostStavka> gosti = [];
      for (int i = 0; i < _imeControllers.length; i++) {
        String ime = _imeControllers[i].text.trim();
        if (ime.isEmpty) {
          ime = 'Gost ${i + 1}';
        }
        gosti.add(GostStavka(
          prezimeIme: ime,
          brojDokumenta: _brojeviDokumenata[i],
          nositeljRacuna: (i == _nositeljIndex),
        ));
      }

      final String dodijeljeniBrojRacuna =
          (widget.postojeci != null && widget.postojeci!.racunBroj.isNotEmpty)
              ? widget.postojeci!.racunBroj
              : _service.generirajSljedeciBrojRacuna(_dolazak);

      final noviBoravak = TuristBoravak(
        id: widget.postojeci?.id.isNotEmpty == true
            ? widget.postojeci!.id
            : 'boravak_${DateTime.now().millisecondsSinceEpoch}',
        apartmanNaziv: _odabraniApartman,
        prezimeIme: nositeljIme,
        gosti: gosti,
        datumDolaska: _dolazak,
        datumOdlaska: _odlazak,
        brojDana: _brojNoci,
        brojOsoba: _brojOsoba,
        cijenaOsobaNoc: _cijenaPoOsobi,
        cijenaUkupno: _ukupno,
        nacinPlacanja: _nacinPlacanja,
        racunBroj: dodijeljeniBrojRacuna,
        racunIspisan: widget.postojeci?.racunIspisan ?? false,
      );

      if (widget.postojeci != null) {
        await _service.azurirajBoravak(widget.postojeci!.id, noviBoravak);
      } else {
        await _service.dodajBoravak(noviBoravak);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri spremanju boravka: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _spremam = false);
    }
  }

  void _prikaziDijalogZauzetosti(String nositelj, String odDatuma, String doDatuma) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
        title: const Text('Termin je već zauzet!'),
        content: Text(
          'Apartman "$_odabraniApartman" je u odabranom razdoblju već rezerviran.\n\n'
          'Postojeći boravak: $nositelj\n'
          'Zauzeti period: $odDatuma - $doDatuma\n\n'
          'Molimo odaberite slobodne datume ili drugi apartman.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('U redu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy.');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.postojeci == null ? 'Novi boravak' : 'Uredi boravak'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Odabir apartmana
            DropdownButtonFormField<String>(
              value: _service.apartmani.any((a) => a.naziv == _odabraniApartman)
                  ? _odabraniApartman
                  : (_service.apartmani.isNotEmpty ? _service.apartmani.first.naziv : null),
              decoration: InputDecoration(
                labelText: 'Odaberi apartman *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.apartment),
                helperText: 'Maksimalni kapacitet: $_maxKapacitet osoba',
              ),
              items: _service.apartmani.map((a) {
                return DropdownMenuItem(
                  value: a.naziv,
                  child: Text('${a.naziv} (max ${a.kapacitet} os.)'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _odabraniApartman = val;
                    if (widget.postojeci == null) {
                      _postaviPrviSlobodanTermin(val);
                    }
                    _preracunajCijenuPremaDatumu();
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // 2. Odabir datuma (Zabrana preklapanja i odlaska prije dolaska)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'Dolazak:\n${df.format(_dolazak)}',
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dolazak,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        final noviOdlazak = (_odlazak.isBefore(picked) || _odlazak.isAtSameMomentAs(picked))
                            ? picked.add(const Duration(days: 1))
                            : _odlazak;

                        final konflikt = _pronadiPreklapanje(picked, noviOdlazak, _odabraniApartman);
                        if (konflikt != null) {
                          final t1 = df.format(konflikt.datumDolaska);
                          final t2 = df.format(konflikt.datumOdlaska);
                          _prikaziDijalogZauzetosti(konflikt.prezimeIme, t1, t2);
                        } else {
                          setState(() {
                            _dolazak = picked;
                            _odlazak = noviOdlazak;
                            _preracunajCijenuPremaDatumu();
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                      'Odlazak:\n${df.format(_odlazak)}',
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () async {
                      // Pravilo 2: Odlazak može biti najranije dan poslije dolaska
                      final minOdlazak = _dolazak.add(const Duration(days: 1));

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _odlazak.isAfter(_dolazak) ? _odlazak : minOdlazak,
                        firstDate: minOdlazak,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        final konflikt = _pronadiPreklapanje(_dolazak, picked, _odabraniApartman);
                        if (konflikt != null) {
                          final t1 = df.format(konflikt.datumDolaska);
                          final t2 = df.format(konflikt.datumOdlaska);
                          _prikaziDijalogZauzetosti(konflikt.prezimeIme, t1, t2);
                        } else {
                          setState(() => _odlazak = picked);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Način plaćanja
            DropdownButtonFormField<String>(
              value: _nacinPlacanja,
              decoration: const InputDecoration(
                labelText: 'Način plaćanja',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Gotovina / Cash', child: Text('Gotovina / Cash')),
                DropdownMenuItem(value: 'Kartica / Card', child: Text('Kartica / Card')),
                DropdownMenuItem(value: 'Booking.com', child: Text('Booking.com')),
                DropdownMenuItem(value: 'Airbnb', child: Text('Airbnb')),
                DropdownMenuItem(value: 'Transakcijski račun', child: Text('Transakcijski račun')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _nacinPlacanja = val);
              },
            ),
            const Divider(height: 32),

            // 3. Popis osoba i nositelj računa s limitom kapaciteta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prijavljene osobe',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '$_brojOsoba / $_maxKapacitet osoba',
                      style: TextStyle(
                        fontSize: 12,
                        color: _brojOsoba >= _maxKapacitet ? Colors.orange.shade800 : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _brojOsoba >= _maxKapacitet ? null : _dodajNovogGosta,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Dodaj osobu'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Označite kvačicom osobu na čije ime ide račun:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            ..._imeControllers.asMap().entries.map((entry) {
              final idx = entry.key;
              final controller = entry.value;
              final brojDoc = _brojeviDokumenata[idx];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: idx,
                        groupValue: _nositeljIndex,
                        onChanged: (val) => setState(() => _nositeljIndex = val!),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: idx == _nositeljIndex
                                    ? 'Nositelj računa (Prezime i ime) *'
                                    : 'Osoba ${idx + 1} (Prezime i ime)',
                                isDense: true,
                              ),
                            ),
                            if (brojDoc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 2),
                                child: Text(
                                  'Dokument: $brojDoc',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.document_scanner, color: Colors.blue),
                        tooltip: 'OCR Skeniraj (Kamera ili Galerija)',
                        onPressed: () => _skenirajZaGosta(idx),
                      ),
                      if (_imeControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _ukloniGosta(idx),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const Divider(height: 32),

            // 4. Kalkulacija cijene
            Text(
              'Kalkulacija cijene ($_brojNoci noćenja • $_brojOsoba os.)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cijenaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cijena os./noć (€)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('UKUPNO (€)',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '${_ukupno.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _spremam ? null : _spremi,
              icon: _spremam
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _spremam
                    ? 'SPREMANJE...'
                    : (widget.postojeci == null
                        ? 'SPREMI I DODAJ NA POPIS'
                        : 'SPREMI IZMJENE'),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
