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
  final String spol;
  final DateTime? datumRodenja;
  final String datumRodenjaTekst;
  final String drzavljanstvo;
  final String vrstaDokumenta;
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
              subtitle: const Text('Osobna iskaznica, putovnica ili vozačka dozvola'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Učitaj sliku iz galerije'),
              subtitle: const Text('Slika osobne, putovnice ili vozačke'),
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

      final inputImage = InputImage.fromFile(datoteka);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      var rezultat = _obradiPrepoznatiTekst(recognizedText);

      if (rezultat != null &&
          rezultat.punoIme.isNotEmpty &&
          !_jeSustavnaRijec(rezultat.punoIme) &&
          rezultat.brojDokumenta.isNotEmpty &&
          !_jeSustavnaRijec(rezultat.brojDokumenta)) {
        return rezultat;
      }

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
          if (r != null &&
              r.punoIme.isNotEmpty &&
              !_jeSustavnaRijec(r.punoIme) &&
              r.brojDokumenta.isNotEmpty &&
              !_jeSustavnaRijec(r.brojDokumenta)) {
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

    final mrz = _pokusajMrzParsiranje(sveLinije);
    if (mrz != null && mrz.punoIme.isNotEmpty && !_jeSustavnaRijec(mrz.punoIme)) {
      return mrz;
    }

    return _parsajVizualno(sveLinije, recognizedText.text);
  }

  OcrDokumentRezultat _parsajIzSiroveStringLinije(String tekst) {
    final linije =
        tekst.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final mrz = _pokusajMrzParsiranje(linije);
    if (mrz != null && mrz.punoIme.isNotEmpty && !_jeSustavnaRijec(mrz.punoIme)) {
      return mrz;
    }
    return _parsajVizualno(linije, tekst);
  }

  OcrDokumentRezultat? _pokusajMrzParsiranje(List<String> linije) {
    List<String> ocisceneMrz = [];
    for (var l in linije) {
      String c = l
          .toUpperCase()
          .replaceAll(' ', '')
          .replaceAll('«', '<<')
          .replaceAll('{', '<')
          .replaceAll('(', '<')
          .replaceAll('[', '<')
          .replaceAll('|', '<')
          .replaceAll('K<', '<<')
          .replaceAll('<K', '<<');

      if (c.contains('<<') ||
          (c.length >= 24 && RegExp(r'^[A-Z0-9<]+$').hasMatch(c))) {
        ocisceneMrz.add(c);
      }
    }

    if (ocisceneMrz.isEmpty) return null;

    // TD3 Format (Putovnice: 2 linije po 44 znaka)
    for (int i = 0; i < ocisceneMrz.length; i++) {
      final l1 = ocisceneMrz[i];
      if ((l1.startsWith('P<') || l1.startsWith('P')) && l1.contains('<<')) {
        String l2 = (i + 1 < ocisceneMrz.length) ? ocisceneMrz[i + 1] : '';

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
          drzavljanstvo: drzavljanstvo.isNotEmpty
              ? drzavljanstvo
              : (l1.length >= 5 ? _ocistiDrzavu(l1.substring(2, 5)) : ''),
          vrstaDokumenta: 'Putovnica',
          brojDokumenta: brojDoc,
        );
      }
    }

    // TD1 Format (Osobne iskaznice: 3 linije po 30 znakova)
    if (ocisceneMrz.length >= 3) {
      for (int i = 0; i <= ocisceneMrz.length - 3; i++) {
        final l1 = ocisceneMrz[i];
        final l2 = ocisceneMrz[i + 1];
        final l3 = ocisceneMrz[i + 2];

        if ((l1.startsWith('I') || l1.startsWith('1') || l1.startsWith('A')) &&
            l3.contains('<<')) {
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

    // 1. Vrsta dokumenta - točna detekcija vozačke dozvole i putovnice
    if (textGornji.contains('VOZAČKA') ||
        textGornji.contains('VOZACKA') ||
        textGornji.contains('DOZVOLA') ||
        textGornji.contains('DRIVING') ||
        textGornji.contains('LICENCE') ||
        textGornji.contains('PERMIS DE CONDUIRE') ||
        textGornji.contains('FÜHRERSCHEIN') ||
        textGornji.contains('FUHRERSCHEIN') ||
        textGornji.contains('VODIČSKÝ') ||
        (textGornji.contains('B1') && textGornji.contains('AM'))) {
      vrstaDokumenta = 'Vozačka dozvola';
    } else if (textGornji.contains('PASSPORT') ||
        textGornji.contains('CESTOVNÍ') ||
        textGornji.contains('REISEPASS') ||
        textGornji.contains('ÚTLEVÉL') ||
        textGornji.contains('PASAPORT')) {
      vrstaDokumenta = 'Putovnica';
    } else {
      vrstaDokumenta = 'Osobna iskaznica';
    }

    // 2. Državljanstvo
    if (textGornji.contains('HRVATSKA') ||
        textGornji.contains('CROATIA') ||
        textGornji.contains('HRV') ||
        textGornji.contains(' RH ') ||
        textGornji.contains('(HR)')) {
      drzavljanstvo = 'HRV';
    } else if (textGornji.contains('SLOVENSK') || textGornji.contains('SVK')) {
      drzavljanstvo = 'SVK';
    } else if (textGornji.contains('POLSKA') || textGornji.contains('POLSKIE') || textGornji.contains('RZECZPOSPOLITA')) {
      drzavljanstvo = 'POL';
    } else if (textGornji.contains('ČESKÁ') || textGornji.contains('CZECH') || textGornji.contains('CZE')) {
      drzavljanstvo = 'CZE';
    } else if (textGornji.contains('ÖSTERREICH') || textGornji.contains('AUSTRIA') || textGornji.contains('AUT')) {
      drzavljanstvo = 'AUT';
    } else if (textGornji.contains('MAGYARORSZÁG') || textGornji.contains('HUNGARY') || textGornji.contains('HUN')) {
      drzavljanstvo = 'HUN';
    } else if (textGornji.contains('DANMARK') || textGornji.contains('DENMARK') || textGornji.contains('DNK')) {
      drzavljanstvo = 'DNK';
    } else if (textGornji.contains('SRBIJA') || textGornji.contains('SERBIA') || textGornji.contains('SRB')) {
      drzavljanstvo = 'SRB';
    } else if (textGornji.contains('UKRAINE') || textGornji.contains('UKR')) {
      drzavljanstvo = 'UKR';
    } else if (textGornji.contains('BOSNA') || textGornji.contains('BIH')) {
      drzavljanstvo = 'BIH';
    } else if (textGornji.contains('DEUTSCHLAND') || textGornji.contains('GERMANY') || textGornji.contains('DEU')) {
      drzavljanstvo = textGornji.contains('RUS') ? 'RUS' : 'DEU';
    }

    // 3. Ciljano traženje prezimena i imena
    for (int i = 0; i < linije.length; i++) {
      final l = linije[i].trim();
      final u = l.toUpperCase();

      if (_jeSustavnaRijec(u)) continue;

      // Traženje PREZIMENA (polje 1.)
      if (prezime.isEmpty && _jePoljePrezimena(u)) {
        String val = _ocistiOznake(l);
        if ((val.isEmpty || _jeSustavnaRijec(val)) && i + 1 < linije.length) {
          final sljedeca = linije[i + 1].trim();
          if (!_jeSustavnaRijec(sljedeca) && !_sadrziBrojeve(sljedeca)) {
            val = sljedeca;
          }
        }
        if (val.isNotEmpty && !_jeSustavnaRijec(val) && !_sadrziBrojeve(val)) {
          prezime = _ocistiImeTekst(val);
        }
      }

      // Traženje IMENA (polje 2.)
      if (ime.isEmpty && _jePoljeImena(u)) {
        String val = _ocistiOznake(l);
        if ((val.isEmpty || _jeSustavnaRijec(val)) && i + 1 < linije.length) {
          final sljedeca = linije[i + 1].trim();
          if (!_jeSustavnaRijec(sljedeca) && !_sadrziBrojeve(sljedeca)) {
            val = sljedeca;
          }
        }
        if (val.isNotEmpty && !_jeSustavnaRijec(val) && !_sadrziBrojeve(val)) {
          ime = _ocistiImeTekst(val);
        }
      }

      // BROJ ISPRAVE (polje 5. ili oznake s brojem)
      if (brojDokumenta.isEmpty &&
          (u.startsWith('5.') ||
              u.contains('5. BROJ') ||
              u.contains('BROJ ISPRAVE') ||
              u.contains('BROJ DOKUMENTA') ||
              u.contains('ČÍSLO') ||
              u.contains('CISLO') ||
              u.contains('DOCUMENT NO') ||
              u.contains('DOKUMENTU') ||
              u.contains('CARD NO') ||
              u.contains('OKMÁNYAZONOSÍTÓ'))) {
        final m = RegExp(r'\b[A-Z0-9]{7,10}\b').firstMatch(u.replaceAll('5.', ''));
        if (m != null) {
          final cand = m.group(0)!;
          if (_sadrziBrojeve(cand) && !_jeSustavnaRijec(cand)) {
            brojDokumenta = cand;
          }
        } else if (i + 1 < linije.length) {
          final sljedeca = linije[i + 1].trim().replaceAll(' ', '');
          if (RegExp(r'^[A-Z0-9]{7,10}$').hasMatch(sljedeca) &&
              _sadrziBrojeve(sljedeca) &&
              !_jeSustavnaRijec(sljedeca)) {
            brojDokumenta = sljedeca;
          }
        }
      }
    }

    // Rezervno traženje broja isprave (mora sadržavati brojeve i imati 7-10 znakova)
    if (brojDokumenta.isEmpty) {
      final matches = RegExp(r'\b([0-9]{8,10}|[A-Z0-9]{8,10}|[0-9]{6}[A-Z]{2})\b').allMatches(puniTekst);
      for (final m in matches) {
        final cand = m.group(0)!.replaceAll(' ', '');
        if (_sadrziBrojeve(cand) &&
            !_jeSustavnaRijec(cand) &&
            !cand.startsWith('19') &&
            !cand.startsWith('20') &&
            cand.length >= 7) {
          brojDokumenta = cand;
          break;
        }
      }
    }

    // 4. DATUM ROĐENJA (polje 3., striktno odbacuje 4a i 4b datume isteka)
    for (int i = 0; i < linije.length; i++) {
      final u = linije[i].toUpperCase();
      if ((u.startsWith('3.') ||
              u.contains('3. DATUM') ||
              u.contains('ROĐENJA') ||
              u.contains('RODJENJA') ||
              u.contains('DATE OF BIRTH') ||
              u.contains('GEBURTSDATUM') ||
              u.contains('NARODENIA') ||
              u.contains('NAROZENÍ') ||
              u.contains('URODZENIA') ||
              u.contains('SZÜLETÉSI')) &&
          !u.contains('4A.') &&
          !u.contains('4B.') &&
          !u.contains('VRIJEDI') &&
          !u.contains('EXPIRY') &&
          !u.contains('GÜLTIG') &&
          !u.contains('VYDANIA') &&
          !u.contains('ISSUE')) {
        final m = RegExp(r'([0-3]?[0-9])[\.\/\-\s]([0-1]?[0-9])[\.\/\-\s](19[3-9][0-9]|20[0-1][0-9])')
            .firstMatch(linije[i]);
        if (m != null) {
          datumRodenja = _parsajDatumDDMMYYYY(m.group(0)!);
          break;
        } else if (i + 1 < linije.length) {
          final m2 = RegExp(r'([0-3]?[0-9])[\.\/\-\s]([0-1]?[0-9])[\.\/\-\s](19[3-9][0-9]|20[0-1][0-9])')
              .firstMatch(linije[i + 1]);
          if (m2 != null) {
            datumRodenja = _parsajDatumDDMMYYYY(m2.group(0)!);
            break;
          }
        }
      }
    }

    if (datumRodenja == null) {
      final dateMatches = RegExp(r'\b([0-3]?[0-9])[\.\/\-\s]([0-1]?[0-9])[\.\/\-\s](19[3-9][0-9]|20[0-1][0-2])\b')
          .allMatches(puniTekst);
      for (final dm in dateMatches) {
        final d = _parsajDatumDDMMYYYY(dm.group(0)!);
        if (d != null && d.year <= 2012) {
          datumRodenja = d;
          break;
        }
      }
    }

    // 5. Spol
    if (RegExp(r'\b(SPOL|SEX|POHLAVIE|PŁEĆ|POHLAVÍ|GESCHLECHT|NEM)\b', caseSensitive: false).hasMatch(puniTekst)) {
      if (RegExp(r'\b(M|MUŽ|MUŠKI|MALE|MÄNNLICH|FÉRFI)\b').hasMatch(textGornji)) {
        spol = 'M';
      } else if (RegExp(r'\b(F|Ž|ŽENA|ŽENSKI|FEMALE|WEIBLICH|NŐ|NO)\b').hasMatch(textGornji)) {
        spol = 'Ž';
      }
    }

    // 6. Rezervno pronalaženje imena (ako polja 1. i 2. nisu imala standardne oznake)
    if (prezime.isEmpty && ime.isEmpty) {
      for (var l in linije) {
        final clean = _ocistiImeTekst(l);
        if (clean.length >= 4 &&
            clean.length <= 35 &&
            !_jeSustavnaRijec(clean) &&
            !_sadrziBrojeve(l)) {
          final parts = clean.split(' ').where((x) => x.length >= 2).toList();
          if (parts.length >= 2) {
            prezime = parts[0];
            ime = parts.sublist(1).join(' ');
            break;
          }
        }
      }
    }

    final df = DateFormat('dd.MM.yyyy.');
    final finalPrezime = _formatiraj(prezime);
    final finalIme = _formatiraj(ime);

    return OcrDokumentRezultat(
      prezime: finalPrezime,
      ime: finalIme,
      punoIme: '$finalPrezime $finalIme'.trim(),
      spol: spol,
      datumRodenja: datumRodenja,
      datumRodenjaTekst: datumRodenja != null ? df.format(datumRodenja) : '',
      drzavljanstvo: drzavljanstvo,
      vrstaDokumenta: vrstaDokumenta,
      brojDokumenta: brojDokumenta,
      drzavaIzdavanja: drzavljanstvo,
    );
  }

  bool _jePoljePrezimena(String u) {
    return u.startsWith('1.') ||
        u.startsWith('1 ') ||
        u == 'PREZIME' ||
        u.contains('PREZIME') ||
        u.contains('SURNAME') ||
        u.contains('PRIEZVISKO') ||
        u.contains('NAZWISKO') ||
        u.contains('PŘÍJMENÍ') ||
        u.contains('CSALÁDI');
  }

  bool _jePoljeImena(String u) {
    return u.startsWith('2.') ||
        u.startsWith('2 ') ||
        u == 'IME' ||
        u.contains('IME') ||
        u.contains('GIVEN') ||
        u.contains('MENO') ||
        u.contains('IMIONA') ||
        u.contains('JMÉNO') ||
        u.contains('UTÓNÉV');
  }

  String _ocistiOznake(String l) {
    return l
        .replaceAll(
            RegExp(
                r'\b(prezime|ime|priezvisko|nazwisko|příjmení|prijmeni|prumeni|prjmeni|családi|csaladi|utónév|utonev|surname|namen|given\s*names?|gven\s*names?|imegiven\s*names?|meno|imiona|jméno|jmeno|forenames|vornamen|info|data|card\s*number|cardnumber|caronumber|osobna\s*iskaznica|vrijedi\s*do|expiry\s*date|vrijedi|expiry)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'^[12345][\.\s\w]?'), '')
        .replaceAll('/', '')
        .replaceAll(':', '')
        .replaceAll('-', '')
        .trim();
  }

  bool _jeSustavnaRijec(String tekst) {
    final u = tekst.toUpperCase().replaceAll(' ', '').replaceAll('-', '');
    final crnaLista = [
      'VJED',
      'DOR',
      'VJEDDOR',
      'VRIJEDI',
      'VRIJEDIDO',
      'EXPIRY',
      'EXPIRYDATE',
      'OSOBNAISKAZNICA',
      'OSOBNA',
      'ISKAZNICA',
      'IDENTITYCARD',
      'CARDNUMBER',
      'CARONUMBER',
      'CARDNO',
      'DOCNO',
      'CAN',
      'POSTAVITE',
      'ISPRAVU',
      'OKVIR',
      'POSTAVITEISPRAVU',
      'ISPRAVUUOKVIR',
      'POSTAVITEISPRAVUUOKVIR',
      'PREZIMEISPRAVUUOKVIR',
      'INFO',
      'SUNSET',
      'BRELA',
      'DATEOFBIRTH',
      'DATEOF',
      'BIRTH',
      'DATUMRODENJA',
      'GEBURTSDATUM',
      'PLACEOFBI',
      'PLACEOFBIRTH',
      'MISTONAROZENI',
      'MIEJSCEURODZENIA',
      'SZULETESIHELY',
      'RESIDENCE',
      'RESIDENCEPERMIT',
      'AUFENTHALT',
      'AUFENTHALTSTITEL',
      'AMTLICHE',
      'VERMERKE',
      'BEHÖRDE',
      'ÖSTERREICH',
      'DEUTSCHLAND',
      'REPUBLIKA',
      'REPUBLIC',
      'REPUBLICOF',
      'SLOVENSKA',
      'CESKA',
      'POLSKA',
      'MAGYARORSZAG',
      'HRVATSKA',
      'CROATIA',
      'OBČANSKÝ',
      'PREUKAZ',
      'IDENTITY',
      'CARD',
      'PASSPORT',
      'PASSPORTNO',
      'DOCUMENT',
      'SURNAME',
      'FORENAMES',
      'VORNAMEN',
      'VORNAMA',
      'NAMEN',
      'GIVENNAMES',
      'GVENNAMES',
      'IMEGIVENNAMES',
      'IMEGIVENNAMELS',
      'NAZWISKO',
      'IMIONA',
      'PRIEZVISKO',
      'MENO',
      'PODPIS',
      'SIGNATURE',
      'MEU',
      'VSETIN',
      'AUTHORITY',
      'VYDAL',
      'TITEL',
      'PERMIT',
      'ANMERKUNGEN',
      'REMARKS',
      'ERSATZ',
      'PRUMENI',
      'PRIJMENI',
      'PRJMENI',
      'OKMANYAZONOSITO',
      'OKMÁNYAZONOSÍTÓ',
      'CSALADINEV',
      'UTONEV',
      'DATAURODZENIA',
      'DATAMONA',
      'VOZACKADOZVOLA',
      'DRIVINGLICENCE',
    ];

    for (var w in crnaLista) {
      if (u == w || u.contains(w)) return true;
    }
    return false;
  }

  bool _sadrziBrojeve(String t) {
    return RegExp(r'[0-9]').hasMatch(t);
  }

  String _ocistiImeTekst(String raw) {
    return raw
        .replaceAll(
            RegExp(
                r'\b(vjed|dor|vrijedi|expiry|date|osobna\s*iskaznica|osobna|iskaznica|cardnumber|caronumber|card|postavite|ispravu|okvir|prezime|ime|info|sunset|brela|prumeni|prijmeni|prjmeni|csaladi|utonev|okmany|surname|given|names|namels|meno|data|hr)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'[^a-zA-ZčćžšđČĆŽŠĐáéíóúýčďěňřšťžůÁÉÍÓÚÝČĎĚŇŘŠŤŽŮäöüÄÖÜőűŐŰß\s\-]'), '')
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
        title: const Text('Skeniranje isprave'),
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
