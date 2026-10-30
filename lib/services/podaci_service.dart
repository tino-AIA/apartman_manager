// lib/services/podaci_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  SupabaseClient get _client => Supabase.instance.client;

  final List<ApartmanJedinica> apartmani = [
    ApartmanJedinica(id: 'A1', naziv: 'Apartman A1 (4+1)'),
    ApartmanJedinica(id: 'A2', naziv: 'Apartman A2 (2+2)'),
    ApartmanJedinica(id: 'Studio', naziv: 'Studio Apartman (2)'),
  ];

  List<TuristBoravak> _boravci = [];
  List<TuristBoravak> get boravci => List.unmodifiable(_boravci);

  // Učitavanje boravaka iz Supabase baze
  Future<void> ucitajIzSupabase() async {
    try {
      final data = await _client
          .from('turisti_boravci')
          .select()
          .order('datum_dolaska', ascending: true);

      _boravci = (data as List).map((row) {
        List<GostStavka> gosti = [];
        if (row['gosti_json'] != null) {
          try {
            final parsed = row['gosti_json'] is String
                ? jsonDecode(row['gosti_json'])
                : row['gosti_json'];
            gosti = (parsed as List)
                .map((g) => GostStavka(
                      prezimeIme: g['prezimeIme'] ?? '',
                      brojDokumenta: g['brojDokumenta'] ?? '',
                      nositeljRacuna: g['nositeljRacuna'] ?? false,
                    ))
                .toList();
          } catch (_) {}
        }

        return TuristBoravak(
          id: row['id'].toString(),
          apartmanNaziv: row['apartman_naziv'] ?? 'Apartman A1',
          prezimeIme: row['prezime_ime'] ?? '',
          gosti: gosti,
          datumDolaska: DateTime.parse(row['datum_dolaska']),
          datumOdlaska: DateTime.parse(row['datum_odlaska']),
          brojDana: (row['broj_dana'] as num).toInt(),
          brojOsoba: (row['broj_osoba'] as num).toInt(),
          cijenaOsobaNoc: (row['cijena_osoba_noc'] as num).toDouble(),
          cijenaUkupno: (row['cijena_ukupno'] as num).toDouble(),
          nacinPlacanja: row['nacin_placanja'] ?? 'Gotovina / Cash',
          racunBroj: row['racun_broj'] ?? '',
          racunIspisan: row['racun_ispisan'] ?? false,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Info: Učitavanje iz baze nije uspjelo (provjeriti mrežu ili tablicu): $e');
    }
  }

  // Dodavanje novog boravka
  Future<void> dodajBoravak(TuristBoravak b) async {
    _boravci.add(b);
    await _renumerirajISpremiSve();
  }

  // Ažuriranje postojećeg boravka
  Future<void> azurirajBoravak(String id, TuristBoravak novi) async {
    final idx = _boravci.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _boravci[idx] = novi;
      await _renumerirajISpremiSve();
    }
  }

  // Brisanje boravka i kaskadna renumeracija
  Future<void> obrisiBoravak(String id) async {
    try {
      await _client.from('turisti_boravci').delete().eq('id', id);
    } catch (_) {}

    _boravci.removeWhere((e) => e.id == id);
    await _renumerirajISpremiSve();
  }

  // Kaskadna renumeracija računa i Knjige EP od broja 1
  Future<void> _renumerirajISpremiSve() async {
    _boravci.sort((a, b) => a.datumDolaska.compareTo(b.datumDolaska));

    for (int i = 0; i < _boravci.length; i++) {
      final godina = _boravci[i].datumDolaska.year.toString().substring(2);
      final noviBroj = '${i + 1}/$godina';

      _boravci[i] = _boravci[i].copyWith(
        racunBroj: noviBroj,
      );

      try {
        final payload = {
          'id': _boravci[i].id,
          'apartman_naziv': _boravci[i].apartmanNaziv,
          'prezime_ime': _boravci[i].prezimeIme,
          'gosti_json': jsonEncode(_boravci[i].gosti.map((g) => g.toMap()).toList()),
          'datum_dolaska': _boravci[i].datumDolaska.toIso8601String(),
          'datum_odlaska': _boravci[i].datumOdlaska.toIso8601String(),
          'broj_dana': _boravci[i].brojDana,
          'broj_osoba': _boravci[i].brojOsoba,
          'cijena_osoba_noc': _boravci[i].cijenaOsobaNoc,
          'cijena_ukupno': _boravci[i].cijenaUkupno,
          'nacin_placanja': _boravci[i].nacinPlacanja,
          'racun_broj': _boravci[i].racunBroj,
          'racun_ispisan': _boravci[i].racunIspisan,
        };

        await _client.from('turisti_boravci').upsert(payload);
      } catch (e) {
        debugPrint('Greška pri sinkronizaciji sa Supabase: $e');
      }
    }

    notifyListeners();
  }

  double dohvatiCijenuZaDatum(DateTime d) {
    if (d.month == 7 || d.month == 8) return 40.0;
    if (d.month == 6 || d.month == 9) return 30.0;
    return 25.0;
  }
}
