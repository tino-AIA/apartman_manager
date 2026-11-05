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
  final String drzavljanstvo; // ISO kod npr. HRV, DEU, POL, CZE, SVK, AUT
  final String vrstaDokumenta; // "Osobna iskaznica", "Putovnica", "Vozačka dozvola", "Ostalo"
  final String brojDokumenta;
  final String drzavaIzdavanja;
  final String gradPrebivalista;

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
    this.gradPrebivalista = '',
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
              subtitle: const Text('MRZ traka (<<<) ili prednja strana isprave'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Učitaj sliku iz galerije'),
              subtitle: const Text('Putovnica, osobna iskaznica, boravišna dozvola'),
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

      // 1. Pokušaj s izvornom slikom
      final inputImage = InputImage.fromFile(datoteka);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final rezultat = _obradiPrepoznatiTekst(recognizedText);

      if (rezultat != null && rezultat.punoIme.isNotEmpty) {
        return rezultat;
      }

      // 2. Ako nije prepoznato, provjeri rotacije za vertikalne i okrenute slike
      final decodedImage = await decodeImageFromList(await datoteka.readAsBytes());
      final width = decodedImage.width.toDouble();
      final height = decodedImage.height.toDouble();

      final rotacije = [
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation270deg,
        InputImageRotation.rotation180deg,
      ];

      for (final rot in rotacije) {
        try {
          final metadata = InputImageMetadata(
            size: Size(width, height),
            rotation: rot,
            format: InputImageFormat.nv21,
            bytesPerRow: decodedImage.width,
          );
          final rotiraniInput = InputImage.fromBytes(
            bytes: await datoteka.readAsBytes(),
            metadata: metadata,
          );
          final rotText = await _textRecognizer.processImage(rotiraniInput);
          final r = _obradiPrepoznatiTekst(rotText);
          if (r != null && r.punoIme.isNotEmpty) {
            return r;
          }
        } catch (_) {}
      }

      return rezultat ?? _parsajIzSiroveStringLinije(recognizedText.text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri OCR obradi: $e')),
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
      return _obradiPrepoznatiTekst(recognizedText) ??
          _parsajIzSiroveStringLinije(recognizedText.text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri OCR obradi: $e')),
        );
      }
      return null;
    }
  }

  OcrDokumentRezultat? _obradiPrepoznatiTekst(RecognizedText recognizedText) {
    List<String> sveLinije = [];
    for (var b in recognizedText.blocks) {
      for (var l in b.lines) {
        final t = l.text.trim();
        if (t.isNotEmpty) sveLinije.add(t);
      }
    }

    if (sveLinije.isEmpty) return null;

    // Prvi prioritet: MRZ zona (Pasoši ili TD1/TD2 linije s <<<)
    final mrz = _pokusajMrzParsiranje(sveLinije);
    if (mrz != null && mrz.punoIme.isNotEmpty) {
      return mrz;
    }

    // Drugi prioritet: Vizualni parser prednje strane
    return _parsajVizualno(sveLinije, recognizedText.text);
  }

  OcrDokumentRezultat _parsajIzSiroveStringLinije(String tekst) {
    final linije = tekst.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final mrz = _pokusajMrzParsiranje(linije);
    if (mrz != null) return mrz;
    return _parsajVizualno(linije, tekst);
  }

  OcrDokumentRezultat? _pokusajMrzParsiranje(List<String> linije) {
    List<String> mrzKandidati = [];
    for (var l in linije) {
      String c = l
          .toUpperCase()
          .replaceAll(' ', '')
          .replaceAll('«', '<<')
          .replaceAll('{', '<')
          .replaceAll('(', '<')
          .replaceAll('[', '<');

      if (c.contains('<') ||
          (c.length >= 25 && RegExp(r'^[A-Z0-9<]+$').hasMatch(c))) {
        mrzKandidati.add(c);
      }
    }

    if (mrzKandidati.isEmpty) return null;

    // TD3 Putovnica (2 linije, cca 44 znaka)
    for (int i = 0; i < mrzKandidati.length; i++) {
      final l1 = mrzKandidati[i];
      if ((l1.startsWith('P<') || l1.startsWith('P')) && l1.length >= 28) {
        String l2 = '';
        if (i + 1 < mrzKandidati.length) {
          l2 = mrzKandidati[i + 1];
        }

        final tuple = _razdvojiImeIPrezimeIzMrz(l1);
        final brojDoc = l2.isNotEmpty ? _izvuciBrojIzLinijePutovnice(l2) : '';
        DateTime? dRod;
        String spol = '';
        String drzavljanstvo = '';

        if (l2.length >= 21) {
          drzavljanstvo = _ocistiDrzavu(l2.substring(10, 13));
          dRod = _parsajDatumYYMMDD(l2.substring(13, 19));
          spol = _parsajSpol(l2[20]);
        }

        final df = DateFormat('dd.MM.yyyy.');
        return OcrDokumentRezultat(
          prezime: tuple.$1,
          ime: tuple.$2,
          punoIme: '${tuple.$1} ${tuple.$2}'.trim(),
          spol: spol,
          datumRodenja: dRod,
          datumRodenjaTekst: dRod != null ? df.format(dRod) : '',
          drzavljanstvo: drzavljanstvo.isNotEmpty ? drzavljanstvo : (l1.length >= 5 ? _ocistiDrzavu(l1.substring(2, 5)) : ''),
          vrstaDokumenta: 'Putovnica',
          brojDokumenta: brojDoc,
        );
      }
    }

    // TD1 Osobna iskaznica (3 linije, cca 30 znakova)
    if (mrzKandidati.length >= 3) {
      for (int i = 0; i <= mrzKandidati.length - 3; i++) {
        final l1 = mrzKandidati[i];
        final l2 = mrzKandidati[i + 1];
        final l3 = mrzKandidati[i + 2];

        if ((l1.startsWith('I') || l1.startsWith('1') || l1.startsWith('A')) && l3.contains('<<')) {
          final tuple = _razdvojiImeIPrezimeIzMrz(l3);
          final brojDoc = _izvuciBrojIzTD1Linije(l1);
          DateTime? dRod;
          String spol = '';
          String drz = '';

          if (l2.length >= 18) {
            dRod = _parsajDatumYYMMDD(l2.substring(0, 6));
            spol = _parsajSpol(l2[7]);
            drz = _ocistiDrzavu(l2.substring(15, 18));
          }

          final df = DateFormat('dd.MM.yyyy.');
          return OcrDokumentRezultat(
            prezime: tuple.$1,
            ime: tuple.$2,
            punoIme: '${tuple.$1} ${tuple.$2}'.trim(),
            spol: spol,
            datumRodenja: dRod,
            datumRodenjaTekst: dRod != null ? df.format(dRod) : '',
            drzavljanstvo: drz,
            vrstaDokumenta: 'Osobna iskaznica',
            brojDokumenta: brojDoc,
          );
        }
      }
    }

    return null;
  }

  OcrDokumentRezultat _parsajVizualno(List<String> linije, String puniTekst) {
    String prezime = '';
    String ime = '';
    String brojDokumenta = '';
    DateTime? datumRodenja;
    String spol = '';
    String drzavljanstvo = '';
    String vrstaDokumenta = 'Osobna iskaznica';

    final textGornji = puniTekst.toUpperCase();

    // 1. Detekcija vrste i države
    if (textGornji.contains('PASSPORT') || textGornji.contains('CESTOVNÍ') || textGornji.contains('REISEPASS')) {
      vrstaDokumenta = 'Putovnica';
    } else if (textGornji.contains('DRIVING') || textGornji.contains('VODIČSKÝ') || textGornji.contains('VOZAČKA')) {
      vrstaDokumenta = 'Vozačka dozvola';
    }

    if (textGornji.contains('SLOVENSK') || textGornji.contains('SVK')) {
      drzavljanstvo = 'SVK';
    } else if (textGornji.contains('POLSKA') || textGornji.contains('POLSKIE') || textGornji.contains('RZECZPOSPOLITA')) {
      drzavljanstvo = 'POL';
    } else if (textGornji.contains('ČESKÁ') || textGornji.contains('CZECH') || textGornji.contains('CZE')) {
      drzavljanstvo = 'CZE';
    } else if (textGornji.contains('ÖSTERREICH') || textGornji.contains('AUSTRIA') || textGornji.contains('AUT')) {
      drzavljanstvo = 'AUT';
    } else if (textGornji.contains('DEUTSCHLAND') || textGornji.contains('AUFENTHALTSTITEL') || textGornji.contains('GERMANY')) {
      drzavljanstvo = textGornji.contains('RUS') ? 'RUS' : 'DEU';
    }

    // 2. Prepoznavanje po linijama s ispravnim RegExp bez (?i)
    final prezimePattern = RegExp(
      r'\b(PRIEZVISKO|NAZWISKO|PŘÍJMENÍ|PRIJMENI|SURNAME|NAMEN)\b|\b1[\.\s]',
      caseSensitive: false,
    );
    final imePattern = RegExp(
      r'\b(GIVEN\s*NAMES?|MENO|IMIONA|JMÉNO|JMENO|FORENAMES|VORNAMEN)\b|\b2[\.\s]',
      caseSensitive: false,
    );
    final brojPattern = RegExp(
      r'\b(ČÍSLO|CISLO|DOCUMENT\s*NO|DOKUMENTU|CARD\s*NO)\b|\b5[\.\s]',
      caseSensitive: false,
    );

    for (int i = 0; i < linije.length; i++) {
      final l = linije[i].trim();
      final u = l.toUpperCase();

      // Traženje prezimena
      if (prezime.isEmpty && prezimePattern.hasMatch(l)) {
        String s = l.replaceAll(prezimePattern, '').replaceAll('/', '').trim();
        if (s.isEmpty && i + 1 < linije.length) {
          s = linije[i + 1].trim();
        }
        if (s.isNotEmpty && !_jeOznaka(s)) {
          prezime = _ocistiImeTekst(s);
        }
      }

      // Traženje imena
      if (ime.isEmpty && imePattern.hasMatch(l)) {
        String s = l.replaceAll(imePattern, '').replaceAll('/', '').trim();
        if (s.isEmpty && i + 1 < linije.length) {
          s = linije[i + 1].trim();
        }
        if (s.isNotEmpty && !_jeOznaka(s)) {
          ime = _ocistiImeTekst(s);
        }
      }

      // Traženje broja isprave
      if (brojDokumenta.isEmpty && brojPattern.hasMatch(l)) {
        final m = RegExp(r'[A-Z0-9]{2,4}\s?[0-9]{5,8}').firstMatch(u);
        if (m != null) {
          brojDokumenta = m.group(0)!.replaceAll(' ', '');
        } else if (i + 1 < linije.length) {
          final sljedeca = linije[i + 1].trim().replaceAll(' ', '');
          if (RegExp(r'^[A-Z0-9]{6,10}$').hasMatch(sljedeca)) {
            brojDokumenta = sljedeca;
          }
        }
      }
    }

    // Rezervno traženje broja dokumenta (npr. MM261502, MM234827, DIC424993, 215361650, 42377229, U4887618, 035747)
    if (brojDokumenta.isEmpty) {
      final docMatches = RegExp(r'\b([A-Z]{1,3}\s?[0-9]{6,8}|[0-9]{8,10}|[A-Z0-9]{8,10})\b').allMatches(puniTekst);
      for (var dm in docMatches) {
        final kandidat = dm.group(0)!.replaceAll(' ', '');
        if (!kandidat.startsWith('19') && !kandidat.startsWith('20') && kandidat.length >= 6) {
          brojDokumenta = kandidat;
          break;
        }
      }
    }

    // 3. Traženje datuma rođenja (dd.MM.yyyy, dd/MM/yyyy, dd-MM-yyyy ili dd MM yyyy)
    final dateMatch = RegExp(r'\b([0-3][0-9])[\.\/\-\s]([0-1][0-9])[\.\/\-\s](19[4-9][0-9]|20[0-2][0-9])\b').firstMatch(puniTekst);
    if (dateMatch != null) {
      datumRodenja = _parsajDatumDDMMYYYY(dateMatch.group(0)!);
    }

    // 4. Traženje spola (M, Ž, F, W)
    if (RegExp(r'\b(POHLAVIE|PŁEĆ|POHLAVÍ|SEX|GESCHLECHT)\b', caseSensitive: false).hasMatch(puniTekst)) {
      if (RegExp(r'\b(M|MUŽ|MALE|MÄNNLICH)\b').hasMatch(textGornji)) {
        spol = 'M';
      } else if (RegExp(r'\b(F|Ž|ŽENA|FEMALE|WEIBLICH|K)\b').hasMatch(textGornji)) {
        spol = 'Ž';
      }
    }

    // Rezervno spajanje imena ako linije nisu bile označene etiketom
    if (prezime.isEmpty && ime.isEmpty) {
      for (var l in linije) {
        if (l.contains(' ') && RegExp(r'^[A-ZČĆŽŠĐÁÉÍÓÚÝČĎĚŇŘŠŤŽŮÄÖÜ\s\-]{5,30}$').hasMatch(l)) {
          final dijelovi = l.split(' ').where((x) => x.length >= 2).toList();
          if (dijelovi.length >= 2 && !_jeOznaka(l)) {
            prezime = _ocistiImeTekst(dijelovi[0]);
            ime = _ocistiImeTekst(dijelovi.sublist(1).join(' '));
            break;
          }
        }
      }
    }

    final df = DateFormat('dd.MM.yyyy.');
    return OcrDokumentRezultat(
      prezime: _formatiraj(prezime),
      ime: _formatiraj(ime),
      punoIme: '${_formatiraj(prezime)} ${_formatiraj(ime)}'.trim(),
      spol: spol,
      datumRodenja: datumRodenja,
      datumRodenjaTekst: datumRodenja != null ? df.format(datumRodenja) : '',
      drzavljanstvo: drzavljanstvo,
      vrstaDokumenta: vrstaDokumenta,
      brojDokumenta: brojDokumenta,
      drzavaIzdavanja: drzavljanstvo,
    );
  }

  bool _jeOznaka(String t) {
    final u = t.toUpperCase();
    return u.contains('REPUBLIK') ||
        u.contains('OBČANSKÝ') ||
        u.contains('PREUKAZ') ||
        u.contains('PASSPORT') ||
        u.contains('IDENTITY') ||
        u.contains('DOWÓD') ||
        u.contains('OSOBISTY') ||
        u.contains('AUFENTHALT');
  }

  String _ocistiImeTekst(String raw) {
    return raw
        .replaceAll(RegExp(r'[^a-zA-ZčćžšđČĆŽŠĐáéíóúýčďěňřšťžůÁÉÍÓÚÝČĎĚŇŘŠŤŽŮäöüÄÖÜß\s\-]'), '')
        .trim();
  }

  (String, String) _razdvojiImeIPrezimeIzMrz(String linija) {
    String radna = linija;
    if (radna.startsWith('P<') || radna.startsWith('P')) {
      radna = radna.replaceAll(RegExp(r'^P<?[A-Z]{3}'), '');
    } else if (radna.startsWith('I<') ||
        radna.startsWith('ID') ||
        radna.startsWith('IO') ||
        radna.startsWith('10')) {
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
      if (nakonDrzave.length >= 9) return nakonDrzave.substring(0, 9);
    }
    final match = RegExp(r'[A-Z0-9]{8,9}').firstMatch(
      linija1.replaceAll(RegExp(r'^(IO|ID|10|1D|I<|AR)[A-Z<]{3}'), ''),
    );
    return match?.group(0) ?? '';
  }

  String _izvuciBrojIzLinijePutovnice(String linija2) {
    String ociscena = linija2.replaceAll('<', '');
    if (ociscena.length >= 9) return ociscena.substring(0, 9);
    final match = RegExp(r'^[A-Z0-9]{8,9}').firstMatch(linija2);
    return match?.group(0) ?? '';
  }

  DateTime? _parsajDatumYYMMDD(String yymmdd) {
    if (yymmdd.length != 6) return null;
    int? yy = int.tryParse(yymmdd.substring(0, 2));
    int? mm = int.tryParse(yymmdd.substring(2, 4));
    int? dd = int.tryParse(yymmdd.substring(4, 6));

    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final trenutnaGodina = DateTime.now().year % 100;
    final punaGodina = (yy > trenutnaGodina) ? (1900 + yy) : (2000 + yy);

    try {
      return DateTime(punaGodina, mm, dd);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parsajDatumDDMMYYYY(String tekst) {
    try {
      final dijelovi = tekst
          .replaceAll('/', '.')
          .replaceAll('-', '.')
          .replaceAll(' ', '.')
          .split('.');
      if (dijelovi.length >= 3) {
        int d = int.parse(dijelovi[0]);
        int m = int.parse(dijelovi[1]);
        int y = int.parse(dijelovi[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
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
        title: const Text('Postavite ispravu u okvir'),
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
                      'Poleđina osobne (s kodom <<<) ili prednja strana / putovnica',
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
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
        },
      ),
    );
  }
}
