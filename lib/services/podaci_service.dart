// lib/services/podaci_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

class ApartmanModel {
  final String id;
  final String naziv;
  final int kapacitet;
  final List<dynamic> cjenik;

  ApartmanModel({
    required this.id,
    required this.naziv,
    this.kapacitet = 0,
    this.cjenik = const [],
  });

  factory ApartmanModel.fromMap(Map<String, dynamic> map) {
    return ApartmanModel(
      id: map['id']?.toString() ?? '',
      naziv: map['naziv']?.toString() ?? '',
      kapacitet: int.tryParse((map['max_osoba'] ?? map['kapacitet'])?.toString() ?? '0') ?? 0,
      cjenik: (map['cjenik_sezone'] ?? map['cjenik']) as List<dynamic>? ?? [],
    );
  }
}

class PodaciService extends ChangeNotifier {
  static final PodaciService _instance = PodaciService._internal();
  factory PodaciService() => _instance;
  PodaciService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  PostavkeIznajmljivaca _postavke = PostavkeIznajmljivaca(
    nazivObjekta: '',
    imePrezime: '',
    oib: '',
    mjesto: '',
    adresa: '',
    telefon: '',
    email: '',
  );
  PostavkeIznajmljivaca get postavke => _postavke;

  List<ApartmanModel> _apartmani = [];
  List<ApartmanModel> get apartmani => _apartmani;

  List<TuristBoravak> _boravci = [];
  List<TuristBoravak> get boravci => _boravci;

  bool _ucitavanje = false;
  bool get ucitavanje => _ucitavanje;

  int _izvuciBrojRacuna(String racunBroj) {
    if (racunBroj.isEmpty) return 0;
    final dijelovi = racunBroj.split('/');
    return int.tryParse(dijelovi.first) ?? 0;
  }

  Future<void> ucitajIzSupabase() async {
    _ucitavanje = true;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;

      // 1. Postavke vlasnika
      var postavkeQuery = _supabase.from('postavke_vlasnik').select();
      final pRes = user != null
          ? await postavkeQuery.eq('user_id', user.id).maybeSingle()
          : await postavkeQuery.limit(1).maybeSingle();

      if (pRes != null) {
        _postavke = PostavkeIznajmljivaca(
          nazivObjekta: pRes['naziv_objekta']?.toString() ?? '',
          imePrezime: pRes['ime_prezime']?.toString() ?? '',
          oib: pRes['oib']?.toString() ?? '',
          mjesto: pRes['mjesto']?.toString() ?? '',
          adresa: pRes['adresa']?.toString() ?? '',
          telefon: pRes['telefon']?.toString() ?? '',
          email: pRes['email']?.toString() ?? '',
          pdvNapomena: pRes['pdv_napomena']?.toString() ??
              'Obveznik nije u sustavu PDV-a, sukladno odredbama čl. 90. st. 2. Zakona o PDV-u. PDV nije obračunat.',
        );
      }

      // 2. Smještajne jedinice
      var apartmaniQuery = _supabase.from('smjestajne_jedinice').select();
      final apartmaniRes = user != null
          ? await apartmaniQuery.eq('user_id', user.id).order('naziv', ascending: true)
          : await apartmaniQuery.order('naziv', ascending: true);

      _apartmani = (apartmaniRes as List<dynamic>)
          .map((e) => ApartmanModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      // 3. Boravci
      var boravciQuery = _supabase.from('turisti_boravci').select();
      final boravciRes = user != null
          ? await boravciQuery.eq('user_id', user.id)
          : await boravciQuery;

      _boravci = (boravciRes as List<dynamic>)
          .map<TuristBoravak>((e) => TuristBoravak.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Sortiraj po broju računa
      _boravci.sort((a, b) => _izvuciBrojRacuna(a.racunBroj).compareTo(_izvuciBrojRacuna(b.racunBroj)));

      // Automatski zatvori rupe ako ih ima
      await _zatvoriRupeURacunima();
    } catch (e) {
      debugPrint('Greška pri učitavanju iz Supabasea: $e');
    } finally {
      _ucitavanje = false;
      notifyListeners();
    }
  }

  /// Zatvara rupe tako da računi idu kontinuirano 1, 2, 3, 4, 5...
  Future<void> _zatvoriRupeURacunima() async {
    if (_boravci.isEmpty) return;

    _boravci.sort((a, b) => _izvuciBrojRacuna(a.racunBroj).compareTo(_izvuciBrojRacuna(b.racunBroj)));

    bool biloIzmjena = false;

    for (int i = 0; i < _boravci.length; i++) {
      final staraGodina = _boravci[i].racunBroj.contains('/')
          ? _boravci[i].racunBroj.split('/')[1]
          : ((_boravci[i].datumDolaska.year % 100).toString().padLeft(2, '0'));

      final noviBroj = '${i + 1}/$staraGodina';

      if (_boravci[i].racunBroj != noviBroj) {
        biloIzmjena = true;
        final stari = _boravci[i];

        final azurirani = TuristBoravak(
          id: stari.id,
          apartmanNaziv: stari.apartmanNaziv,
          prezimeIme: stari.prezimeIme,
          gosti: stari.gosti,
          datumDolaska: stari.datumDolaska,
          datumOdlaska: stari.datumOdlaska,
          brojDana: stari.brojDana,
          brojOsoba: stari.brojOsoba,
          cijenaOsobaNoc: stari.cijenaOsobaNoc,
          cijenaUkupno: stari.cijenaUkupno,
          nacinPlacanja: stari.nacinPlacanja,
          racunBroj: noviBroj,
          racunIspisan: stari.racunIspisan,
        );

        _boravci[i] = azurirani;

        try {
          await _supabase
              .from('turisti_boravci')
              .update({'racun_broj': noviBroj})
              .eq('id', stari.id);
        } catch (e) {
          debugPrint('Greška pri ažuriranju broja računa ${stari.id}: $e');
        }
      }
    }

    if (biloIzmjena) {
      _boravci.sort((a, b) => _izvuciBrojRacuna(a.racunBroj).compareTo(_izvuciBrojRacuna(b.racunBroj)));
    }
  }

  /// Novi račun UVIJEK dobiva maksimalni broj računa + 1 (ide na sam kraj)
  String generirajSljedeciBrojRacuna() {
    final dvoznamenkastaGodina = (DateTime.now().year % 100).toString().padLeft(2, '0');
    final suffix = '/$dvoznamenkastaGodina';

    int maxBroj = 0;
    for (var b in _boravci) {
      if (b.racunBroj.endsWith(suffix)) {
        final rbr = _izvuciBrojRacuna(b.racunBroj);
        if (rbr > maxBroj) {
          maxBroj = rbr;
        }
      }
    }

    return '${maxBroj + 1}/$dvoznamenkastaGodina';
  }

  double dohvatiCijenuZaDatum(DateTime datum, {String? apartmanNaziv}) {
    if (_apartmani.isEmpty) return 25.0;

    ApartmanModel? odabrani;
    if (apartmanNaziv != null) {
      odabrani = _apartmani.firstWhere(
        (a) => a.naziv == apartmanNaziv,
        orElse: () => _apartmani.first,
      );
    } else {
      odabrani = _apartmani.first;
    }

    if (odabrani.cjenik.isNotEmpty) {
      for (var p in odabrani.cjenik) {
        if (p is Map) {
          final pocM = int.tryParse(p['pocetniMjesec']?.toString() ?? '');
          final pocD = int.tryParse(p['pocetniDan']?.toString() ?? '');
          final zavM = int.tryParse(p['zavrsniMjesec']?.toString() ?? '');
          final zavD = int.tryParse(p['zavrsniDan']?.toString() ?? '');

          if (pocM != null && pocD != null && zavM != null && zavD != null) {
            final start = DateTime(datum.year, pocM, pocD);
            final end = DateTime(datum.year, zavM, zavD);
            if ((datum.isAfter(start) || datum.isAtSameMomentAs(start)) &&
                (datum.isBefore(end) || datum.isAtSameMomentAs(end))) {
              final c = (p['cijena'] as num?)?.toDouble();
              if (c != null && c > 0) return c;
            }
          }
        }
      }
    }

    return 25.0;
  }

  Future<void> dodajBoravak(TuristBoravak boravak) async {
    final mapaZaSpremanje = boravak.toMap();
    mapaZaSpremanje['created_at'] = DateTime.now().toIso8601String();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      mapaZaSpremanje['user_id'] = user.id;
    }

    // 1. Spremi u Supabase
    await _supabase.from('turisti_boravci').upsert(mapaZaSpremanje);

    // 2. Dodaj u listu
    _boravci.removeWhere((b) => b.id == boravak.id);
    _boravci.add(boravak);

    // 3. Poredaj isključivo po broju računa (novi ostaje zadnji)
    _boravci.sort((a, b) => _izvuciBrojRacuna(a.racunBroj).compareTo(_izvuciBrojRacuna(b.racunBroj)));
    notifyListeners();
  }

  Future<void> azurirajBoravak(String id, TuristBoravak boravak) async {
    await _supabase
        .from('turisti_boravci')
        .update(boravak.toMap())
        .eq('id', id);

    final index = _boravci.indexWhere((b) => b.id == id);
    if (index != -1) {
      _boravci[index] = boravak;
      _boravci.sort((a, b) => _izvuciBrojRacuna(a.racunBroj).compareTo(_izvuciBrojRacuna(b.racunBroj)));
      notifyListeners();
    }
  }

  Future<void> obrisiBoravak(dynamic id) async {
    await _supabase.from('turisti_boravci').delete().eq('id', id.toString());
    _boravci.removeWhere((b) => b.id.toString() == id.toString());

    // Automatsko zatvaranje rupa bez potrebe za magičnim gumbom
    await _zatvoriRupeURacunima();
    notifyListeners();
  }
}
