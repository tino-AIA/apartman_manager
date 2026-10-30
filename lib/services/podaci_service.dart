// lib/services/podaci_service.dart
import 'package:flutter/material.dart';
import '../models/turist_model.dart';

class ApartmanJedinica {
  final String id;
  final String naziv;
  ApartmanJedinica({required this.id, required this.naziv});
}

class PodaciService extends ChangeNotifier {
  static final PodaciService _instance = PodaciService._internal();
  factory PodaciService() => _instance;
  PodaciService._internal();

  final List<ApartmanJedinica> apartmani = [
    ApartmanJedinica(id: 'A1', naziv: 'Apartman A1 (4+1)'),
    ApartmanJedinica(id: 'A2', naziv: 'Apartman A2 (2+2)'),
    ApartmanJedinica(id: 'Studio', naziv: 'Studio Apartman (2)'),
  ];

  final List<TuristBoravak> _boravci = [];

  List<TuristBoravak> get boravci => List.unmodifiable(_boravci);

  // Dodavanje novog boravka i automatska dodjela broja računa od 1
  void dodajBoravak(TuristBoravak b) {
    _boravci.add(b);
    _renumerirajRacune();
    notifyListeners();
  }

  // Uređivanje postojećeg boravka
  void azurirajBoravak(String id, TuristBoravak novi) {
    final idx = _boravci.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _boravci[idx] = novi;
      _renumerirajRacune();
      notifyListeners();
    }
  }

  // Brisanje i kaskadna renumeracija (račun 4 postaje 3, 5 postaje 4...)
  void obrisiBoravak(String id) {
    _boravci.removeWhere((e) => e.id == id);
    _renumerirajRacune();
    notifyListeners();
  }

  // Automatsko renumeriranje od broja 1 za tekuću godinu
  void _renumerirajRacune() {
    _boravci.sort((a, b) => a.datumDolaska.compareTo(b.datumDolaska));
    for (int i = 0; i < _boravci.length; i++) {
      final godina = _boravci[i].datumDolaska.year.toString().substring(2);
      final noviBroj = '${i + 1}/$godina';
      _boravci[i] = _boravci[i].copyWith(
        id: (i + 1).toString(),
        racunBroj: noviBroj,
      );
    }
  }

  // Određivanje cijene po noćenju prema periodu u Brelima
  double dohvatiCijenuZaDatum(DateTime d) {
    if (d.month == 7 || d.month == 8) return 40.0; // Vrhunac sezone
    if (d.month == 6 || d.month == 9) return 30.0; // Predsezona i podsezona
    return 25.0; // Izvan sezone (npr. listopad - svibanj)
  }
}
