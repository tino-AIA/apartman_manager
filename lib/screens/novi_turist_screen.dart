// lib/screens/novi_turist_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import '../models/turist_model.dart';

class NoviTuristScreen extends StatefulWidget {
  final int sljedeciBrojRacuna; // npr. 103

  const NoviTuristScreen({super.key, required this.sljedeciBrojRacuna});

  @override
  State<NoviTuristScreen> createState() => _NoviTuristScreenState();
}

class _NoviTuristScreenState extends State<NoviTuristScreen> {
  final _formKey = GlobalKey<FormState>();

  final _imeCtrl = TextEditingController();
  final _drzavljanstvoCtrl = TextEditingController();
  final _brojIspraveCtrl = TextEditingController();

  final _brojOsobaCtrl = TextEditingController(text: '2');
  final _cijenaPoOsobiCtrl = TextEditingController(text: '25.00');
  final _ukupnoCtrl = TextEditingController();

  DateTime _datumDolaska = DateTime.now();
  DateTime _datumOdlaska = DateTime.now().add(const Duration(days: 7));
  String _nacinPlacanja = 'Gotovina / Cash';

  final List<String> _opcijePlacanja = [
    'Gotovina / Cash',
    'Booking',
    'Transakcijski račun / Bank transfer',
    'Airbnb',
  ];

  @override
  void initState() {
    super.initState();
    _rekalkulirajCijenu(izvorJeUkupno: false);
  }

  int get _brojDana => _datumOdlaska.difference(_datumDolaska).inDays;

  // Dvosmjerni kalkulator (izmjena cijene po osobi/noći ili ukupnog iznosa)
  void _rekalkulirajCijenu({required bool izvorJeUkupno}) {
    int osobe = int.tryParse(_brojOsobaCtrl.text) ?? 1;
    int dana = _brojDana > 0 ? _brojDana : 1;

    if (izvorJeUkupno) {
      double ukupno = double.tryParse(_ukupnoCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double poOsobi = ukupno / (osobe * dana);
      _cijenaPoOsobiCtrl.text = poOsobi.toStringAsFixed(2);
    } else {
      double poOsobi = double.tryParse(_cijenaPoOsobiCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double ukupno = poOsobi * osobe * dana;
      _ukupnoCtrl.text = ukupno.toStringAsFixed(2);
    }
    setState(() {});
  }

  // Skeniranje osobnog dokumenta kamerom (MRZ / OCR)
  Future<void> _skenirajDokument() async {
    try {
      final kamere = await availableCameras();
      if (kamere.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera nije dostupna na ovom uređaju.')),
        );
        return;
      }

      // Otvaranje jednostavnog foto dijaloga
      final controller = CameraController(kamere.first, ResolutionPreset.high);
      await controller.initialize();

      if (!mounted) return;
      final XFile? foto = await showDialog<XFile>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Usmjeri na MRZ zonu ili podatke'),
          content: SizedBox(
            height: 350,
            width: double.maxFinite,
            child: CameraPreview(controller),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                final file = await controller.takePicture();
                if (ctx.mounted) Navigator.pop(ctx, file);
              },
              child: const Text('Skeniraj'),
            ),
          ],
        ),
      );

      await controller.dispose();

      if (foto != null) {
        final inputImage = InputImage.fromFilePath(foto.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        await textRecognizer.close();

        _obradiOcrTekst(recognizedText.text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri skeniranju: $e')),
      );
    }
  }

  // Parsiranje očitanog teksta (MRZ linije ili standardni tekst)
  void _obradiOcrTekst(String rawText) {
    final linije = rawText.split('\n');
    String pronadenoIme = '';

    for (var l in linije) {
      String clean = l.trim().replaceAll(' ', '');
      // Traženje ICAO MRZ formata (P< ili I<)
      if (clean.startsWith('P<') || clean.startsWith('I<') || clean.startsWith('ID')) {
        var dijelovi = clean.split('<<');
        if (dijelovi.length >= 2) {
          pronadenoIme = '${dijelovi[0].replaceAll(RegExp(r'[^A-Z]'), '')} ${dijelovi[1].replaceAll('<', ' ').trim()}';
          break;
        }
      }
    }

    setState(() {
      if (pronadenoIme.isNotEmpty) {
        _imeCtrl.text = pronadenoIme;
      } else if (linije.isNotEmpty) {
        _imeCtrl.text = linije.first; // Fallback na prvu očitana liniju
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Podaci uspješno očitani s dokumenta!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd. MM. yyyy.');
    final godina = DateTime.now().year.toString().substring(2);
    final generiraniRnBr = '${widget.sljedeciBrojRacuna}/$godina';

    return Scaffold(
      appBar: AppBar(
        title: Text('Novi turist (RN $generiraniRnBr)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gumb za kameru / OCR
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _skenirajDokument,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('SKENIRAJ OSOBNU / PUTOVNICU (OCR)'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _imeCtrl,
                decoration: const InputDecoration(labelText: 'Prezime i ime gosta *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Unesite ime i prezime' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _nacinPlacanja,
                      decoration: const InputDecoration(labelText: 'Način plaćanja', border: OutlineInputBorder()),
                      items: _opcijePlacanja.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => _nacinPlacanja = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Odabir datuma boravka
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dolazak:'),
                      subtitle: Text(df.format(_datumDolaska), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final pick = await showDatePicker(
                          context: context,
                          initialDate: _datumDolaska,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (pick != null) {
                          setState(() {
                            _datumDolaska = pick;
                            if (_datumOdlaska.isBefore(_datumDolaska)) {
                              _datumOdlaska = _datumDolaska.add(const Duration(days: 1));
                            }
                            _rekalkulirajCijenu(izvorJeUkupno: false);
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Odlazak:'),
                      subtitle: Text(df.format(_datumOdlaska), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final pick = await showDatePicker(
                          context: context,
                          initialDate: _datumOdlaska,
                          firstDate: _datumDolaska.add(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                        );
                        if (pick != null) {
                          setState(() {
                            _datumOdlaska = pick;
                            _rekalkulirajCijenu(izvorJeUkupno: false);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),

              // Kalkulator sekcija
              Text('Kalkulacija cijene ($_brojDana noćenja)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brojOsobaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Broj osoba', border: OutlineInputBorder()),
                      onChanged: (_) => _rekalkulirajCijenu(izvorJeUkupno: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cijenaPoOsobiCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cijena os./noć (€)', border: OutlineInputBorder()),
                      onChanged: (_) => _rekalkulirajCijenu(izvorJeUkupno: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ukupnoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'UKUPNO ZA NAPLATU (€)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                onChanged: (_) => _rekalkulirajCijenu(izvorJeUkupno: true),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final noviGost = TuristBoravak(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        nacinPlacanja: _nacinPlacanja,
                        racunBroj: generiraniRnBr,
                        prezimeIme: _imeCtrl.text.trim(),
                        datumDolaska: _datumDolaska,
                        datumOdlaska: _datumOdlaska,
                        brojOsoba: int.tryParse(_brojOsobaCtrl.text) ?? 1,
                        brojDana: _brojDana,
                        cijenaUkupno: double.tryParse(_ukupnoCtrl.text.replaceAll(',', '.')) ?? 0.0,
                        cijenaOsobaNoc: double.tryParse(_cijenaPoOsobiCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      );
                      Navigator.pop(context, noviGost);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('SPREMI I DODAJ NA POPIS', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
