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

  OcrDokumentRezultat _parsajPodatkeIzTeksta(String tekst) {
    final siroveLinije = tekst.split('\n');
    List<String> mrzKandidati = [];

    for (var l in siroveLinije) {
      String ociscena = l.trim().toUpperCase().replaceAll(' ', '');
      ociscena = ociscena
          .replaceAll('«', '<<')
          .replaceAll('{', '<')
          .replaceAll('(', '<');

      if (ociscena.contains('<') && ociscena.length >= 15) {
        mrzKandidati.add(ociscena);
      }
    }

    String punoIme = '';
    String brojDokumenta = '';

    if (mrzKandidati.length >= 3) {
      final triLinije = mrzKandidati.sublist(mrzKandidati.length - 3);
      final linija1 = triLinije[0];
      final linija3 = triLinije[2];

      punoIme = _izvuciImeIzMrzLinije(linija3);
      brojDokumenta = _izvuciBrojDokumentaIzLinije1(linija1);
    } else if (mrzKandidati.length >= 2) {
      final dvijeLinije = mrzKandidati.sublist(mrzKandidati.length - 2);
      final linija1 = dvijeLinije[0];
      final linija2 = dvijeLinije[1];

      punoIme = _izvuciImeIzMrzLinije(linija1);
      brojDokumenta = _izvuciBrojIzLinijePutovnice(linija2);
    } else {
      for (final l in mrzKandidati) {
        if (l.contains('<<')) {
          final potencijalnoIme = _izvuciImeIzMrzLinije(l);
          if (potencijalnoIme.isNotEmpty) {
            punoIme = potencijalnoIme;
            break;
          }
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

      if (imena.endsWith('k') || imena.endsWith('K')) {
        if (imena.length > 3 &&
            (imena.endsWith('ak') || imena.endsWith('AK'))) {
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

  String _izvuciBrojDokumentaIzLinije1(String linija1) {
    String cista = linija1
        .replaceAll(RegExp(r'^(IO|ID|10|1D|I<|AR)[A-Z<]{1,4}'), '')
        .replaceAll('<', '');

    final match = RegExp(r'[A-Z0-9]{8,10}').firstMatch(cista);
    if (match != null) {
      return match.group(0)!;
    }
    return '';
  }

  String _izvuciBrojIzLinijePutovnice(String linija2) {
    final match = RegExp(r'^[A-Z0-9]{8,10}').firstMatch(linija2);
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
