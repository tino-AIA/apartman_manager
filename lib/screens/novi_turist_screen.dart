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
      _odabraniApartman = _service.apartmani.first.naziv;
      _nacinPlacanja = 'Gotovina / Cash';
      _dolazak = DateTime.now();
      _odlazak = DateTime.now().add(const Duration(days: 7));
      _imeControllers.add(TextEditingController());
      _brojeviDokumenata.add('');
      _cijenaController.text =
          _service.dohvatiCijenuZaDatum(_dolazak).toStringAsFixed(2);
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

  int get _brojNoci {
    final diff = _odlazak.difference(_dolazak).inDays;
    return diff <= 0 ? 1 : diff;
  }

  int get _brojOsoba => _imeControllers.length;

  double get _cijenaPoOsobi => double.tryParse(_cijenaController.text) ?? 0.0;

  double get _ukupno => _brojNoci * _brojOsoba * _cijenaPoOsobi;

  void _preracunajCijenuPremaDatumu() {
    setState(() {
      _cijenaController.text =
          _service.dohvatiCijenuZaDatum(_dolazak).toStringAsFixed(2);
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

  void _spremi() {
    List<GostStavka> gosti = [];
    for (int i = 0; i < _imeControllers.length; i++) {
      String ime = _imeControllers[i].text.trim();
      if (ime.isEmpty) ime = 'Gost ${i + 1}';
      gosti.add(GostStavka(
        prezimeIme: ime,
        brojDokumenta: _brojeviDokumenata[i],
        nositeljRacuna: (i == _nositeljIndex),
      ));
    }

    final nositelj = gosti[_nositeljIndex].prezimeIme;

    final noviBoravak = TuristBoravak(
      id: widget.postojeci?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      apartmanNaziv: _odabraniApartman,
      prezimeIme: nositelj,
      gosti: gosti,
      datumDolaska: _dolazak,
      datumOdlaska: _odlazak,
      brojDana: _brojNoci,
      brojOsoba: _brojOsoba,
      cijenaOsobaNoc: _cijenaPoOsobi,
      cijenaUkupno: _ukupno,
      nacinPlacanja: _nacinPlacanja,
      racunBroj: widget.postojeci?.racunBroj ?? '',
    );

    if (widget.postojeci != null) {
      _service.azurirajBoravak(widget.postojeci!.id, noviBoravak);
    } else {
      _service.dodajBoravak(noviBoravak);
    }

    Navigator.pop(context);
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
              value: _odabraniApartman,
              decoration: const InputDecoration(
                labelText: 'Odaberi apartman *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
              ),
              items: _service.apartmani.map((a) {
                return DropdownMenuItem(value: a.naziv, child: Text(a.naziv));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _odabraniApartman = val);
              },
            ),
            const SizedBox(height: 12),

            // 2. Odabir datuma
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
                        setState(() {
                          _dolazak = picked;
                          if (_odlazak.isBefore(_dolazak)) {
                            _odlazak = _dolazak.add(const Duration(days: 1));
                          }
                          _preracunajCijenuPremaDatumu();
                        });
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
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _odlazak,
                        firstDate: _dolazak.add(const Duration(days: 1)),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _odlazak = picked);
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
                DropdownMenuItem(
                  value: 'Gotovina / Cash',
                  child: Text('Gotovina / Cash'),
                ),
                DropdownMenuItem(
                  value: 'Kartica / Card',
                  child: Text('Kartica / Card'),
                ),
                DropdownMenuItem(
                  value: 'Booking.com',
                  child: Text('Booking.com'),
                ),
                DropdownMenuItem(
                  value: 'Airbnb',
                  child: Text('Airbnb'),
                ),
                DropdownMenuItem(
                  value: 'Transakcijski račun',
                  child: Text('Transakcijski račun'),
                ),
              ],
              onChanged: (val) => setState(() => _nacinPlacanja = val!),
            ),
            const Divider(height: 32),

            // 3. Popis osoba i nositelj računa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Prijavljene osobe u apartmanu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: _dodajNovogGosta,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Dodaj osobu'),
                ),
              ],
            ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: idx,
                        groupValue: _nositeljIndex,
                        onChanged: (val) =>
                            setState(() => _nositeljIndex = val!),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: idx == _nositeljIndex
                                    ? 'Nositelj računa *'
                                    : 'Osoba ${idx + 1}',
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
                        icon: const Icon(Icons.document_scanner,
                            color: Colors.blue),
                        tooltip: 'OCR Skeniraj (Kamera ili Galerija)',
                        onPressed: () => _skenirajZaGosta(idx),
                      ),
                      if (_imeControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
              onPressed: _spremi,
              icon: const Icon(Icons.check),
              label: Text(widget.postojeci == null
                  ? 'SPREMI I DODAJE NA POPIS'
                  : 'SPREMI IZMJENE'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
