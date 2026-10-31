// lib/services/ocr_service.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mrz_parser/mrz_parser.dart';

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

      final inputImage = InputImage.fromFilePath(odabranaSlika.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      return _parsajPodatkeIzTeksta(recognizedText.text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri učitavanju iz galerije: $e')),
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
          const SnackBar(
              content: Text('Potrebna je dozvola za kameru za skeniranje.')),
        );
      }
      return null;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera nije pronađena na uređaju.')),
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
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

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

  // Glavna ICAO 9303 logika
  OcrDokumentRezultat _parsajPodatkeIzTeksta(String tekst) {
    // 1. Očisti linije i pripremi kandidate za MRZ zonu
    final linije = tekst
        .split('\n')
        .map((l) => l.trim().toUpperCase().replaceAll(' ', ''))
        .where((l) => l.length >= 28) // ICAO linije imaju minimalno 30 znakova
        .toList();

    // Tražimo MRZ blok (TD1: 3 linije duljine oko 30; TD3: 2 linije duljine oko 44)
    List<String> mrzKandidati = [];
    for (final l in linije) {
      if (l.contains('<<') ||
          l.startsWith('P<') ||
          l.startsWith('I<') ||
          l.startsWith('ID') ||
          l.startsWith('AR')) {
        mrzKandidati.add(l);
      }
    }

    // 2. Pokušaj službenog ICAO parsiranja putem mrz_parser paketa
    try {
      // Ako imamo 3 linije (TD1 - osobne iskaznice)
      if (mrzKandidati.length >= 3) {
        final triLinije = mrzKandidati.sublist(mrzKandidati.length - 3);
        // Osiguraj fiksnu ICAO duljinu od 30 znakova po liniji
        final normalizirane = triLinije.map((l) => l.padRight(30, '<').substring(0, 30)).toList();
        final rezultat = MRZParser.parse(normalizirane);
        return OcrDokumentRezultat(
          punoIme: '${_formatiraj(rezultat.surnames)} ${_formatiraj(rezultat.givenNames)}'.trim(),
          brojDokumenta: rezultat.documentNumber,
        );
      }

      // Ako imamo 2 linije (TD3 - putovnice ili TD2)
      if (mrzKandidati.length >= 2) {
        final dvijeLinije = mrzKandidati.sublist(mrzKandidati.length - 2);
        final sirina = dvijeLinije.first.length > 38 ? 44 : 36;
        final normalizirane = dvijeLinije.map((l) => l.padRight(sirina, '<').substring(0, sirina)).toList();
        final rezultat = MRZParser.parse(normalizirane);
        return OcrDokumentRezultat(
          punoIme: '${_formatiraj(rezultat.surnames)} ${_formatiraj(rezultat.givenNames)}'.trim(),
          brojDokumenta: rezultat.documentNumber,
        );
      }
    } catch (_) {
      // Ako kontrolna suma nije prošla zbog zamućenja jednog slova, idemo na robustan fallback
    }

    // 3. Robustan fallback ako parser odbaci kontrolnu sumu
    String ime = '';
    String brojDokumenta = '';

    for (final l in mrzKandidati) {
      if (l.contains('<<') && !l.startsWith('ID') && !l.startsWith('AR') && !l.startsWith('I<')) {
        String clean = l.startsWith('P<') ? l.replaceAll(RegExp(r'^P<[A-Z]{3}'), '') : l;
        final parts = clean.split('<<');
        if (parts.length >= 2) {
          final prezime = parts[0].replaceAll(RegExp(r'[^A-Z]'), ' ').trim();
          final imena = parts[1].split('<').where((s) => s.isNotEmpty).join(' ');
          ime = '${_formatiraj(prezime)} ${_formatiraj(imena)}';
          break;
        }
      }
    }

    for (final l in mrzKandidati) {
      final docMatch = RegExp(r'[A-Z0-9]{8,10}').firstMatch(l.replaceAll(RegExp(r'^(ID|AR|IO|P<)[A-Z<]{1,4}'), ''));
      if (docMatch != null && !docMatch.group(0)!.contains('SPECIMEN')) {
        brojDokumenta = docMatch.group(0)!;
        break;
      }
    }

    return OcrDokumentRezultat(
      punoIme: ime,
      brojDokumenta: brojDokumenta,
    );
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
