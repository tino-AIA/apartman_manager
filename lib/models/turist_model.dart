// lib/models/turist_model.dart

class GostStavka {
  String prezimeIme;
  String brojDokumenta;
  bool nositeljRacuna;
  String spol;
  String datumRodenja;
  String drzavljanstvo;
  String vrstaDokumenta;
  String gradPrebivalista;
  String drzavaPrebivalista;
  String oib;
  bool evisitorPrijavljen;
  DateTime? evisitorVrijemePrijave;

  GostStavka({
    required this.prezimeIme,
    this.brojDokumenta = '',
    this.nositeljRacuna = false,
    this.spol = '',
    this.datumRodenja = '',
    this.drzavljanstvo = '',
    this.vrstaDokumenta = 'Osobna iskaznica',
    this.gradPrebivalista = '',
    this.drzavaPrebivalista = '',
    this.oib = '',
    this.evisitorPrijavljen = false,
    this.evisitorVrijemePrijave,
  });

  Map<String, dynamic> toMap() => {
        'prezime_ime': prezimeIme,
        'broj_dokumenta': brojDokumenta,
        'nositelj_racuna': nositeljRacuna,
        'spol': spol,
        'datum_rodenja': datumRodenja,
        'drzavljanstvo': drzavljanstvo,
        'vrsta_dokumenta': vrstaDokumenta,
        'grad_prebivalista': gradPrebivalista,
        'drzava_prebivalista': drzavaPrebivalista,
        'oib': oib,
        'evisitor_prijavljen': evisitorPrijavljen,
        'evisitor_vrijeme_prijave': evisitorVrijemePrijave?.toIso8601String(),
      };

  factory GostStavka.fromMap(Map<String, dynamic> map) {
    final vPrijava = map['evisitor_vrijeme_prijave']?.toString();
    return GostStavka(
      prezimeIme: (map['prezime_ime'] ?? map['prezimeIme'])?.toString() ?? '',
      brojDokumenta: (map['broj_dokumenta'] ?? map['brojDokumenta'])?.toString() ?? '',
      nositeljRacuna: map['nositelj_racuna'] == true || map['nositeljRacuna'] == true,
      spol: (map['spol'])?.toString() ?? '',
      datumRodenja: (map['datum_rodenja'] ?? map['datumRodenja'])?.toString() ?? '',
      drzavljanstvo: (map['drzavljanstvo'])?.toString() ?? '',
      vrstaDokumenta: (map['vrsta_dokumenta'] ?? map['vrstaDokumenta'])?.toString() ?? 'Osobna iskaznica',
      gradPrebivalista: (map['grad_prebivalista'] ?? map['gradPrebivalista'])?.toString() ?? '',
      drzavaPrebivalista: (map['drzava_prebivalista'] ?? map['drzavaPrebivalista'])?.toString() ?? '',
      oib: (map['oib'])?.toString() ?? '',
      evisitorPrijavljen: map['evisitor_prijavljen'] == true,
      evisitorVrijemePrijave: vPrijava != null ? DateTime.tryParse(vPrijava) : null,
    );
  }
}

class TuristBoravak {
  final String id;
  final String apartmanNaziv;
  final String prezimeIme;
  final List<GostStavka> gosti;
  final DateTime datumDolaska;
  final DateTime datumOdlaska;
  final int brojDana;
  final int brojOsoba;
  final double cijenaOsobaNoc;
  final double cijenaUkupno;
  final String nacinPlacanja;
  final String racunBroj;
  final bool racunIspisan;
  final DateTime createdAt;

  TuristBoravak({
    required this.id,
    this.apartmanNaziv = 'Apartman A1',
    required this.prezimeIme,
    List<GostStavka>? gosti,
    required this.datumDolaska,
    required this.datumOdlaska,
    required this.brojDana,
    required this.brojOsoba,
    required this.cijenaOsobaNoc,
    required this.cijenaUkupno,
    required this.nacinPlacanja,
    required this.racunBroj,
    this.racunIspisan = false,
    DateTime? createdAt,
  })  : gosti = gosti ?? [GostStavka(prezimeIme: prezimeIme, nositeljRacuna: true)],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final dDolaska = datumDolaska.toIso8601String().split('T').first;
    final dOdlaska = datumOdlaska.toIso8601String().split('T').first;
    final gostiJson = gosti.map((g) => g.toMap()).toList();

    return {
      'id': id,
      'apartman_naziv': apartmanNaziv,
      'prezime_ime': prezimeIme,
      'gosti': gostiJson,
      'datum_dolaska': dDolaska,
      'datum_odlaska': dOdlaska,
      'broj_dana': brojDana,
      'broj_osoba': brojOsoba,
      'cijena_osoba_noc': cijenaOsobaNoc,
      'cijena_ukupno': cijenaUkupno,
      'nacin_placanja': nacinPlacanja,
      'racun_broj': racunBroj,
      'racun_ispisan': racunIspisan,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TuristBoravak.fromMap(Map<String, dynamic> map) {
    List<GostStavka> ucitaniGosti = [];
    if (map['gosti'] != null && map['gosti'] is List) {
      ucitaniGosti = (map['gosti'] as List)
          .map((item) => GostStavka.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    final String glavniGost = (map['prezime_ime'] ?? map['prezimeIme'])?.toString() ?? '';
    final dDol = (map['datum_dolaska'] ?? map['datumDolaska'])?.toString();
    final dOdl = (map['datum_odlaska'] ?? map['datumOdlaska'])?.toString();
    final rBroj = (map['racun_broj'] ?? map['racunBroj'])?.toString() ?? '';
    final cAt = (map['created_at'] ?? map['createdAt'])?.toString();

    return TuristBoravak(
      id: map['id']?.toString() ?? '',
      apartmanNaziv: (map['apartman_naziv'] ?? map['apartmanNaziv'] ?? map['apartman'])?.toString() ?? '',
      prezimeIme: glavniGost,
      gosti: ucitaniGosti.isNotEmpty
          ? ucitaniGosti
          : [GostStavka(prezimeIme: glavniGost, nositeljRacuna: true)],
      datumDolaska: dDol != null ? (DateTime.tryParse(dDol) ?? DateTime.now()) : DateTime.now(),
      datumOdlaska: dOdl != null ? (DateTime.tryParse(dOdl) ?? DateTime.now()) : DateTime.now(),
      brojDana: int.tryParse((map['broj_dana'] ?? map['brojDana'])?.toString() ?? '1') ?? 1,
      brojOsoba: int.tryParse((map['broj_osoba'] ?? map['brojOsoba'])?.toString() ?? '1') ?? 1,
      cijenaOsobaNoc: (map['cijena_osoba_noc'] ?? map['cijenaOsobaNoc'] ?? map['cijena_po_noci'] as num?)?.toDouble() ?? 0.0,
      cijenaUkupno: (map['cijena_ukupno'] ?? map['cijenaUkupno'] ?? map['ukupno'] as num?)?.toDouble() ?? 0.0,
      nacinPlacanja: (map['nacin_placanja'] ?? map['nacinPlacanja'])?.toString() ?? 'Gotovina / Cash',
      racunBroj: rBroj,
      racunIspisan: map['racun_ispisan'] == true || map['racunIspisan'] == true,
      createdAt: cAt != null ? (DateTime.tryParse(cAt) ?? DateTime.now()) : DateTime.now(),
    );
  }
}
