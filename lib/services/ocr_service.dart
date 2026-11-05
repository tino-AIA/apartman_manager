// lib/services/ocr_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class OcrDokumentRezultat {
  final String prezime;
  final String ime;
  final String punoIme;
  final String spol; // "M" ili "Ž"
  final DateTime? datumRodenja;
  final String datumRodenjaTekst; // "dd.MM.yyyy."
  final String drzavljanstvo; // ISO troznamenkasti kod npr. HRV, DEU, POL
  final String vrstaDokumenta; // "Osobna iskaznica" ili "Putovnica"
  final String brojDokumenta;
  final String drzavaIzdavanja;

  OcrDokumentRezultat({
    this.prezime = '',
    this.ime = '',
    required this.punoIme,
    this.spol = '',
    this.datumRodenja,
    this.datumRodenjaTekst = '',
    this.drzavljanstvo = '',
    this.vrstaDokumenta = 'Osobna iskaznica',
    required this.brojDokumenta,
    this.drzavaIzdavanja = '',
  });
}

class OcrService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _picker = ImagePicker();

  Future<OcrDokumentRezultat?> skenirajDokument(BuildContext context) async {
    final izvor = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0D47A1)),
              title: const Text('Fotografiraj dokument (Kamera)'),
              subtitle: const Text('Preporučeno za MRZ traku na poleđini ili dnu'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Učitaj sliku iz galerije'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (izvor == null) return null;

    if (izvor == ImageSource.gallery) {
      return await _odaberiIzGalerije(context);
    } else {
      return await _snimiKamerom(context);
    }
  }

  Future<OcrDokumentRezultat?> _odaberiIzGalerije(BuildContext context) async {
    try {
      final XFile? odabranaSlika = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (odabranaSlika == null) return null;

      final datoteka = File(odabranaSlika.path);

      var inputImage = InputImage.fromFile(datoteka);
      var recognizedText = await _textRecognizer.processImage(inputImage);
      var rezultat = _parsajPodatkeIzTeksta(recognizedText.text);

      if (rezultat.punoIme.isEmpty || rezultat.brojDokumenta.isEmpty) {
        final rotacije = [
          InputImageRotation.rotation90deg,
          InputImageRotation.rotation180deg,
          InputImageRotation.rotation270deg,
        ];

        for (final rot in rotacije) {
          try {
            final decodedImage = await decodeImageFromList(await datoteka.readAsBytes());
            final metadata = InputImageMetadata(
              size: Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
              rotation: rot,
              format: InputImageFormat.nv21,
              bytesPerRow: decodedImage.width,
            );
            final rotiraniInput = InputImage.fromBytes(
              bytes: await datoteka.readAsBytes(),
              metadata: metadata,
            );
            final rotTekst = await _textRecognizer.processImage(rotiraniInput);
            final noviRezultat = _parsajPodatkeIzTeksta(rotTekst.text);

            if (noviRezultat.punoIme.isNotEmpty && noviRezultat.brojDokumenta.isNotEmpty) {
              return noviRezultat;
            }
          } catch (_) {}
        }
      }

      return rezultat;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri obradi slike: $e')),
        );
      }
      return null;
    }
  }

  Future<OcrDokumentRezultat?> _snimiKamerom(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Potrebna je dozvola za kameru.')),
        );
      }
      return null;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera nije pronađena.')),
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    final slikaPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _KameraSkeniranjeScreen(camera: cameras.first),
      ),
    );

    if (slikaPath == null) return null;

    try {
      final inputImage = InputImage.fromFilePath(slikaPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return _parsajPodatkeIzTeksta(recognizedText.text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri OCR obradi: $e')),
        );
      }
      return null;
    }
  }

  OcrDokumentRezultat _parsajPodatkeIzTeksta(String tekst) {
    final siroveLinije = tekst.split('\n');
    List<String> sveOciscene = [];

    for (var l in siroveLinije) {
      String ociscena = l.trim().toUpperCase().replaceAll(' ', '');
      ociscena = ociscena
          .replaceAll('«', '<<')
          .replaceAll('{', '<')
          .replaceAll('(', '<')
          .replaceAll('[', '<')
          .replaceAll('K<', '<<')
          .replaceAll('<K', '<<');

      if (ociscena.length >= 15) {
        sveOciscene.add(ociscena);
      }
    }

    List<String> mrzLinije = sveOciscene.where((l) {
      return l.contains('<') ||
          RegExp(r'^[A-Z0-9]{8,10}[0-9]').hasMatch(l) ||
          l.startsWith('IO') ||
          l.startsWith('ID') ||
          l.startsWith('10') ||
          l.startsWith('1D') ||
          l.startsWith('I<') ||
          l.startsWith('AR') ||
          l.startsWith('P<') ||
          l.startsWith('P');
    }).toList();

    String prezime = '';
    String ime = '';
    String punoIme = '';
    String spol = '';
    DateTime? datumRodenja;
    String drzavljanstvo = '';
    String vrstaDokumenta = 'Osobna iskaznica';
    String brojDokumenta = '';
    String drzavaIzdavanja = '';

    // 1. TD1 Osobne iskaznice (3 linije x 30 znakova)
    if (mrzLinije.length >= 3 && (mrzLinije.any((l) => l.startsWith('I') || l.startsWith('1') || l.startsWith('A')))) {
      final zadnjeTri = mrzLinije.sublist(mrzLinije.length - 3);
      final l1 = zadnjeTri[0];
      final l2 = zadnjeTri[1];
      final l3 = zadnjeTri[2];

      vrstaDokumenta = 'Osobna iskaznica';

      // Linija 1: Tip(2), DrzavaIzdavanja(3), BrojDokumenta(9)
      if (l1.length >= 5) {
        drzavaIzdavanja = _ocistiDrzavu(l1.substring(2, 5));
      }
      brojDokumenta = _izvuciBrojIzTD1Linije(l1);

      // Linija 2: DatumRodenja (pozicija 0-5), Kontrolni(6), Spol (pozicija 7), Istek(8-13), Kontrolni(14), Drzavljanstvo(15-17)
      if (l2.length >= 18) {
        datumRodenja = _parsajDatumYYMMDD(l2.substring(0, 6));
        spol = _parsajSpol(l2[7]);
        drzavljanstvo = _ocistiDrzavu(l2.substring(15, 18));
      }

      // Linija 3: Prezime<<Ime<SrednjeIme
      final imeTuple = _razdvojiImeIPrezimeIzMrz(l3);
      prezime = imeTuple.$1;
      ime = imeTuple.$2;
      punoIme = '$prezime $ime'.trim();
    }
    // 2. TD3 Putovnice (2 linije x 44 znaka)
    else if (mrzLinije.length >= 2) {
      final zadnjeDvije = mrzLinije.sublist(mrzLinije.length - 2);
      final l1 = zadnjeDvije[0];
      final l2 = zadnjeDvije[1];

      vrstaDokumenta = l1.startsWith('P') ? 'Putovnica' : 'Osobna iskaznica';

      // Linija 1: Tip(2), Drzava(3), Prezime<<Ime<Srednje
      if (l1.length >= 5) {
        drzavaIzdavanja = _ocistiDrzavu(l1.substring(2, 5));
      }
      final imeTuple = _razdvojiImeIPrezimeIzMrz(l1);
      prezime = imeTuple.$1;
      ime = imeTuple.$2;
      punoIme = '$prezime $ime'.trim();

      // Linija 2: Broj(0-8), Kontrolni(9), Drzavljanstvo(10-12), DatumRodenja(13-18), Kontrolni(19), Spol(20)
      brojDokumenta = _izvuciBrojIzLinijePutovnice(l2);
      if (l2.length >= 21) {
        drzavljanstvo = _ocistiDrzavu(l2.substring(10, 13));
        datumRodenja = _parsajDatumYYMMDD(l2.substring(13, 19));
        spol = _parsajSpol(l2[20]);
      }
    }

    // Rezervno traženje ako nešto nedostaje
    if (punoIme.isEmpty) {
      for (final l in mrzLinije) {
        if (l.contains('<<')) {
          final imeTuple = _razdvojiImeIPrezimeIzMrz(l);
          if (imeTuple.$1.isNotEmpty || imeTuple.$2.isNotEmpty) {
            prezime = imeTuple.$1;
            ime = imeTuple.$2;
            punoIme = '$prezime $ime'.trim();
            break;
          }
        }
      }
    }

    if (brojDokumenta.isEmpty) {
      for (final l in sveOciscene) {
        final match = RegExp(r'^[A-Z0-9]{8,9}[0-9]').firstMatch(l);
        if (match != null) {
          brojDokumenta = match.group(0)!.substring(0, 9);
          break;
        }
      }
    }

    final df = DateFormat('dd.MM.yyyy.');
    final datumRodenjaTekst = datumRodenja != null ? df.format(datumRodenja) : '';

    return OcrDokumentRezultat(
      prezime: prezime,
      ime: ime,
      punoIme: punoIme.isNotEmpty ? punoIme : '$prezime $ime'.trim(),
      spol: spol,
      datumRodenja: datumRodenja,
      datumRodenjaTekst: datumRodenjaTekst,
      drzavljanstvo: drzavljanstvo,
      vrstaDokumenta: vrstaDokumenta,
      brojDokumenta: brojDokumenta,
      drzavaIzdavanja: drzavaIzdavanja.isNotEmpty ? drzavaIzdavanja : drzavljanstvo,
    );
  }

  (String, String) _razdvojiImeIPrezimeIzMrz(String linija) {
    String radna = linija;

    if (radna.startsWith('P<') || radna.startsWith('P')) {
      radna = radna.replaceAll(RegExp(r'^P<?[A-Z]{3}'), '');
    } else if (radna.startsWith('I<') || radna.startsWith('ID') || radna.startsWith('IO') || radna.startsWith('10')) {
      radna = radna.replaceAll(RegExp(r'^(I<|ID|IO|10|1D)[A-Z<]{3}'), '');
    }

    if (!radna.contains('<<')) return ('', '');

    final dijelovi = radna.split('<<');
    if (dijelovi.length >= 2) {
      String prezime = dijelovi[0].replaceAll('<', ' ').trim();

      String imenaRaw = dijelovi[1]
          .replaceAll(RegExp(r'K<+$'), '')
          .replaceAll(RegExp(r'<+$'), '');

      final subImena = imenaRaw
          .split('<')
          .where((s) => s.isNotEmpty && s.length >= 2)
          .toList();

      String imena = subImena.join(' ').trim();

      prezime = prezime.replaceAll(RegExp(r'[^A-ZČĆŽŠĐ ]'), '').trim();
      imena = imena.replaceAll(RegExp(r'[^A-ZČĆŽŠĐ ]'), '').trim();

      if (prezime.endsWith('K') && prezime.length > 3) {
        prezime = prezime.substring(0, prezime.length - 1);
      }

      return (_formatiraj(prezime), _formatiraj(imena));
    }

    return ('', '');
  }

  String _izvuciBrojIzTD1Linije(String linija1) {
    if (linija1.length >= 14) {
      String nakonDrzave = linija1.substring(5).replaceAll('<', '');
      if (nakonDrzave.length >= 9) {
        return nakonDrzave.substring(0, 9);
      }
    }
    final match = RegExp(r'[A-Z0-9]{8,9}').firstMatch(
      linija1.replaceAll(RegExp(r'^(IO|ID|10|1D|I<|AR)[A-Z<]{3}'), ''),
    );
    return match?.group(0) ?? '';
  }

  String _izvuciBrojIzLinijePutovnice(String linija2) {
    String ociscena = linija2.replaceAll('<', '');
    if (ociscena.length >= 9) {
      return ociscena.substring(0, 9);
    }
    final match = RegExp(r'^[A-Z0-9]{8,9}').firstMatch(linija2);
    return match?.group(0) ?? '';
  }

  DateTime? _parsajDatumYYMMDD(String yymmdd) {
    if (yymmdd.length != 6) return null;
    final yyStr = yymmdd.substring(0, 2);
    final mmStr = yymmdd.substring(2, 4);
    final ddStr = yymmdd.substring(4, 6);

    int? yy = int.tryParse(yyStr);
    int? mm = int.tryParse(mmStr);
    int? dd = int.tryParse(ddStr);

    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final trenutnaGodina = DateTime.now().year % 100;
    // Ako je yy npr. 85 -> 1985; ako je 15 -> 2015
    final punaGodina = (yy > trenutnaGodina) ? (1900 + yy) : (2000 + yy);

    try {
      return DateTime(punaGodina, mm, dd);
    } catch (_) {
      return null;
    }
  }

  String _parsajSpol(String char) {
    final c = char.toUpperCase();
    if (c == 'M') return 'M';
    if (c == 'F' || c == 'W') return 'Ž';
    return '';
  }

  String _ocistiDrzavu(String raw) {
    return raw.replaceAll('<', '').replaceAll(RegExp(r'[^A-Z]'), '').trim();
  }

  String _formatiraj(String tekst) {
    if (tekst.isEmpty) return '';
    return tekst.split(' ').map((r) {
      if (r.isEmpty) return '';
      return r[0].toUpperCase() + (r.length > 1 ? r.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class _KameraSkeniranjeScreen extends StatefulWidget {
  final CameraDescription camera;
  const _KameraSkeniranjeScreen({required this.camera});

  @override
  State<_KameraSkeniranjeScreen> createState() => _KameraSkeniranjeScreenState();
}

class _KameraSkeniranjeScreenState extends State<_KameraSkeniranjeScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Postavite MRZ zonu u okvir'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Center(child: CameraPreview(_controller)),
                // Vodilica okvira za osobnu ili putovnicu
                Center(
                  child: Container(
                    width: size.width * 0.90,
                    height: size.width * 0.90 * 0.63,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Usmjerite kameru na dno ili poleđinu s kodom (<<<)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      backgroundColor: Colors.white,
                      onPressed: () async {
                        try {
                          await _initializeControllerFuture;
                          final image = await _controller.takePicture();
                          if (context.mounted) {
                            Navigator.pop(context, image.path);
                          }
                        } catch (_) {}
                      },
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
    );
  }
}
