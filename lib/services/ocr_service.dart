// lib/services/ocr_service.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

class OcrDokumentRezultat {
  final String punoIme;
  final String brojDokumenta;

  OcrDokumentRezultat({
    required this.punoIme,
    required this.brojDokumenta,
  });
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrDokumentRezultat?> skenirajDokument(BuildContext context) async {
    // Provjera dozvole za kameru
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Potrebna je dozvola za kameru za skeniranje.')),
        );
      }
      return null;
    }

    // Otvaranje ekrana kamere za snimanje dokumenta
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
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

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

  // Prepoznavanje imena i broja dokumenta (MRZ ili standardni format osobne/putovnice)
  OcrDokumentRezultat _parsajPodatkeIzTeksta(String tekst) {
    final linije = tekst
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String ime = '';
    String brojDokumenta = '';

    // 1. Provjera MRZ zone (donji redovi na putovnicama i novim osobnim iskaznicama: IDHRV..., P<HRV...)
    for (final linija in linije) {
      final ocisceno = linija.replaceAll(' ', '');
      if (ocisceno.startsWith('IDHRV') || ocisceno.startsWith('I<HRV') || ocisceno.startsWith('P<HRV') || ocisceno.startsWith('P<')) {
        // Format putovnice / osobne: npr. P<HRVMULLER<<GERHARD<<<<<<<<<<<<<<<<<<<<<
        if (linija.contains('<<')) {
          final dijelovi = linija.split('<<');
          if (dijelovi.length >= 2) {
            final prezime = dijelovi[0].replaceAll(RegExp(r'^[A-Z0-9<]{2,5}'), '').replaceAll('<', ' ').trim();
            final restIme = dijelovi[1].replaceAll('<', ' ').trim();
            ime = '$prezime $restIme'.trim();
          }
        }
      }

      // Detekcija 9-znamenkastog broja isprave (npr. hrvatska osobna ili europski ID)
      final docMatch = RegExp(r'\b[A-Z0-9]{8,10}\b').firstMatch(ocisceno);
      if (docMatch != null && brojDokumenta.isEmpty && !ocisceno.contains('HRV') && !ocisceno.contains('SPECIMEN')) {
        brojDokumenta = docMatch.group(0) ?? '';
      }
    }

    // 2. Ako MRZ nije pronađen, uzimamo najvjerojatniji redak teksta s imenom
    if (ime.isEmpty) {
      for (final l in linije) {
        // Tražimo redak koji ima 2 riječi sastavljene samo od slova (ime i prezime)
        if (RegExp(r'^[A-ZČĆŽŠĐa-zčćžšđ]{3,}\s+[A-ZČĆŽŠĐa-zčćžšđ]{3,}$').hasMatch(l)) {
          ime = l;
          break;
        }
      }
    }

    // Ako ništa nije prepoznato, uzmi prvu liniju kao rezervu
    if (ime.isEmpty && linije.isNotEmpty) {
      ime = linije.first;
    }

    return OcrDokumentRezultat(
      punoIme: ime,
      brojDokumenta: brojDokumenta,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}

// Jednostavno sučelje kamere s okvirom za dokument
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
      ResolutionPreset.high,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Postavite dokument u okvir')),
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Center(child: CameraPreview(_controller)),
                // Prozirni vodič / okvir za osobnu iskaznicu
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    height: MediaQuery.of(context).size.width * 0.88 * 0.63, // omjer osobne/kartice
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2),
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
                        } catch (e) {
                          // Greška pri okidanju slike
                        }
                      },
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
