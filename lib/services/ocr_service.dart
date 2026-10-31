// lib/services/ocr_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class OcrDokumentRezultat {
  final String punoIme;
  final String brojDokumenta;

  OcrDokumentRezultat({
    required this.punoIme,
    required this.brojDokumenta,
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

      // Pokušaj 1: Normalna orijentacija
      var inputImage = InputImage.fromFile(datoteka);
      var recognizedText = await _textRecognizer.processImage(inputImage);
      var rezultat = _parsajPodatkeIzTeksta(recognizedText.text);

      // Ako podaci nisu pronađeni, moguće je da je slika vertikalna/zarotirana u galeriji
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
          .replaceAll('K<', '<<')
          .replaceAll('<K', '<<');

      // Filtriraj administrativne riječi koje stvaraju šum
      if (ociscena.contains('WYDAJ') ||
          ociscena.contains('ORGAN') ||
          ociscena.contains('PREZYD') ||
          ociscena.contains('AUTHO') ||
          ociscena.contains('DATUM') ||
          ociscena.contains('EXPIR')) {
        continue;
      }

      if (ociscena.length >= 15) {
        sveOciscene.add(ociscena);
      }
    }

    String punoIme = '';
    String brojDokumenta = '';

    List<String> mrzLinije = sveOciscene.where((l) {
      return l.contains('<') ||
          RegExp(r'^[A-Z0-9]{9}[0-9]').hasMatch(l) ||
          l.startsWith('IO') ||
          l.startsWith('ID') ||
          l.startsWith('10') ||
          l.startsWith('1D') ||
          l.startsWith('I<') ||
          l.startsWith('AR') ||
          l.startsWith('P<');
    }).toList();

    // 1. TD1 osobne iskaznice (3 linije)
    if (mrzLinije.length >= 3) {
      final zadnjeTri = mrzLinije.sublist(mrzLinije.length - 3);
      final linija1 = zadnjeTri[0];
      final linija3 = zadnjeTri[2];

      punoIme = _izvuciImeIzMrzLinije(linija3);
      brojDokumenta = _izvuciBrojIzTD1Linije(linija1);
    }
    // 2. TD3 putovnice (2 linije)
    else if (mrzLinije.length >= 2) {
      final zadnjeDvije = mrzLinije.sublist(mrzLinije.length - 2);
      final linija1 = zadnjeDvije[0];
      final linija2 = zadnjeDvije[1];

      punoIme = _izvuciImeIzMrzLinije(linija1);
      brojDokumenta = _izvuciBrojIzLinijePutovnice(linija2);
    }
    // 3. Rezervno traženje
    else {
      for (final l in mrzLinije) {
        if (l.contains('<<')) {
          final res = _izvuciImeIzMrzLinije(l);
          if (res.isNotEmpty) {
            punoIme = res;
            break;
          }
        }
      }
    }

    if (brojDokumenta.isEmpty) {
      for (final l in sveOciscene) {
        if (RegExp(r'^[A-Z0-9]{8,9}[0-9][A-Z]{3}').hasMatch(l)) {
          brojDokumenta = l.substring(0, 9);
          break;
        }
      }
    }

    return OcrDokumentRezultat(
      punoIme: punoIme,
      brojDokumenta: brojDokumenta,
    );
  }

  String _izvuciImeIzMrzLinije(String linija) {
    String radna = linija;

    if (radna.startsWith('P<') || radna.startsWith('P')) {
      radna = radna.replaceAll(RegExp(r'^P<?[A-Z]{3}'), '');
    }

    if (!radna.contains('<<')) return '';

    final dijelovi = radna.split('<<');
    if (dijelovi.length >= 2) {
      String prezime = dijelovi[0].replaceAll('<', ' ').trim();

      String imenaRaw = dijelovi[1];
      imenaRaw = imenaRaw
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

      if (imena.endsWith('K') && imena.length > 3) {
        if (imena.endsWith('AK') || imena.endsWith('EK')) {
          imena = imena.substring(0, imena.length - 1);
        }
      }

      if (prezime.isNotEmpty && imena.isNotEmpty) {
        return '${_formatiraj(prezime)} ${_formatiraj(imena)}';
      } else if (prezime.isNotEmpty) {
        return _formatiraj(prezime);
      }
    }
    return '';
  }

  String _izvuciBrojIzTD1Linije(String linija1) {
    if (linija1.length >= 14) {
      String nakonDrzave = linija1.substring(5).replaceAll('<', '');
      if (nakonDrzave.length >= 9) {
        return nakonDrzave.substring(0, 9);
      }
    }

    final match = RegExp(r'[A-Z0-9]{9}').firstMatch(
      linija1.replaceAll(RegExp(r'^(IO|ID|10|1D|I<|AR)[A-Z<]{3}'), ''),
    );
    if (match != null) {
      return match.group(0)!;
    }
    return '';
  }

  String _izvuciBrojIzLinijePutovnice(String linija2) {
    String ociscena = linija2.replaceAll('<', '');
    if (ociscena.length >= 9) {
      return ociscena.substring(0, 9);
    }
    final match = RegExp(r'^[A-Z0-9]{8,9}').firstMatch(linija2);
    if (match != null) {
      return match.group(0)!;
    }
    return '';
  }

  String _formatiraj(String tekst) {
    if (tekst.isEmpty) return '';
    return tekst.split(' ').map((r) {
      if (r.isEmpty) return '';
      return r[0].toUpperCase() +
          (r.length > 1 ? r.substring(1).toLowerCase() : '');
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
        title: const Text('Postavite dokument u okvir'),
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
                      child: const Icon(Icons.camera_alt,
                          color: Colors.black, size: 36),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
        },
      ),
    );
  }
}
