// lib/services/ocr_service.dart
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

  /// Glavna metoda: otvara modalni meni za odabir kamere ili galerije
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

  // 1. Odabir slike iz galerije uređaja
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
          SnackBar(content: Text('Greška pri učitavanju slike iz galerije: $e')),
        );
      }
      return null;
    }
  }

  // 2. Snimanje kamerom u realnom vremenu
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

  // ICAO 9303 MRZ parser: Putovnice (TD3) i Osobne iskaznice (TD1)
  OcrDokumentRezultat _parsajPodatkeIzTeksta(String tekst) {
    final rawLinije = tekst
        .split('\n')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    String ime = '';
    String brojDokumenta = '';

    List<String> mrzLinije = [];
    for (final l in rawLinije) {
      final cista = l.replaceAll(' ', '');
      if (cista.contains('<<') ||
          cista.startsWith('I<') ||
          cista.startsWith('IO') ||
          cista.startsWith('ID') ||
          cista.startsWith('P<') ||
          cista.startsWith('P')) {
        mrzLinije.add(cista);
      }
    }

    // A) TD3 Format (Putovnice): 1. red počinje sa P< ili P i sadrži PREZIME<<IME
    for (final l in mrzLinije) {
      if (l.startsWith('P<') || (l.startsWith('P') && l.contains('<<'))) {
        final bezPrefiksa = l.replaceAll(RegExp(r'^P<?[A-Z]{3}'), '');
        final dijelovi = bezPrefiksa.split('<<');
        if (dijelovi.length >= 2) {
          final p = _formatirajVelikaPocetna(dijelovi[0].replaceAll('<', ' ').trim());
          final i = _formatirajVelikaPocetna(dijelovi[1].replaceAll('<', ' ').trim());
          if (p.isNotEmpty && i.isNotEmpty) {
            ime = '$p $i';
            break;
          }
        }
      }
    }

    // B) TD1 Format (Osobne iskaznice s 3 reda): 3. red sadrži PREZIME<<IME
    if (ime.isEmpty) {
      for (final l in mrzLinije) {
        if (l.contains('<<') && !l.startsWith('P<')) {
          final dijelovi = l.split('<<');
          if (dijelovi.length >= 2) {
            String p = dijelovi[0]
                .replaceAll(RegExp(r'^[A-Z0-9<]{2,5}'), '')
                .replaceAll('<', ' ')
                .trim();
            String i = dijelovi[1].replaceAll('<', ' ').trim();
            if (p.isNotEmpty && i.isNotEmpty) {
              ime = '${_formatirajVelikaPocetna(p)} ${_formatirajVelikaPocetna(i)}';
              break;
            }
          }
        }
      }
    }

    // C) Izdvajanje broja dokumenta iz MRZ-a
    for (final l in mrzLinije) {
      // Putovnica: 2. red počinje brojem dokumenta (8-10 alfanumeričkih znakova)
      if (RegExp(r'^[A-Z0-9]{8,10}').hasMatch(l) &&
          !l.contains('<<') &&
          !l.startsWith('IO') &&
          !l.startsWith('ID')) {
        final match = RegExp(r'^[A-Z0-9]{8,10}').firstMatch(l);
        if (match != null) {
          brojDokumenta = match.group(0)!;
          break;
        }
      }
      // Osobna iskaznica: npr. IOHRV... ili IDHRV...
      if (l.startsWith('IOHRV') || l.startsWith('IDHRV') || l.startsWith('I<HRV')) {
        final ostatak = l.substring(5).replaceAll('<', '');
        if (ostatak.length >= 9) {
          brojDokumenta = ostatak.substring(0, 9);
          break;
        }
      }
    }

    // D) Fallback mehanizam ako MRZ nije bio potpuno vidljiv
    if (ime.isEmpty) {
      for (final l in rawLinije) {
        if (l.contains('ZAGREB') ||
            l.contains('PREBIVALIŠTE') ||
            l.contains('POLICIJSKA') ||
            l.contains('DATUM') ||
            l.contains('REPUBLIC') ||
            l.contains('PASSPORT')) {
          continue;
        }
        final rijeci = l.split(RegExp(r'\s+'));
        if (rijeci.length == 2 &&
            rijeci.every((r) => RegExp(r'^[A-ZČĆŽŠĐ]{3,}$').hasMatch(r))) {
          ime = '${_formatirajVelikaPocetna(rijeci[0])} ${_formatirajVelikaPocetna(rijeci[1])}';
          break;
        }
      }
    }

    if (brojDokumenta.isEmpty) {
      for (final l in rawLinije) {
        final match = RegExp(r'\b[A-Z0-9]{8,10}\b').firstMatch(l);
        if (match != null) {
          brojDokumenta = match.group(0)!;
          break;
        }
      }
    }

    return OcrDokumentRezultat(
      punoIme: ime,
      brojDokumenta: brojDokumenta,
    );
  }

  String _formatirajVelikaPocetna(String tekst) {
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

// Sučelje kamere s maksimalnom rezolucijom i okvirom
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
      ResolutionPreset.max, // Maksimalna oštrina za precizno čitanje MRZ linija
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
