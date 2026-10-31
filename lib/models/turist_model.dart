// lib/models/turist_model.dart

class GostStavka {
  String prezimeIme;
  String brojDokumenta;
  bool nositeljRacuna;

  GostStavka({
    required this.prezimeIme,
    this.brojDokumenta = '',
    this.nositeljRacuna = false,
  });

  Map<String, dynamic> toMap() => {
        'prezimeIme': prezimeIme,
        'brojDokumenta': brojDokumenta,
        'nositeljRacuna': nositeljRacuna,
      };

  factory GostStavka.fromMap(Map<String, dynamic> map) {
    return GostStavka(
      prezimeIme: (map['prezimeIme'] ?? map['prezime_ime'])?.toString() ?? '',
      brojDokumenta: (map['brojDokumenta'] ?? map['broj_dokumenta'])?.toString() ?? '',
      nositeljRacuna: map['nositeljRacuna'] == true || map['nositelj_racuna'] == true,
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
  }) : gosti = gosti ?? [GostStavka(prezimeIme: prezimeIme, nositeljRacuna: true)];

  Map<String, dynamic> toMap() {
    final dDolaska = datumDolaska.toIso8601String().split('T').first;
    final dOdlaska = datumOdlaska.toIso8601String().split('T').first;
    final gostiJson = gosti.map((g) => g.toMap()).toList();

    return {
      'id': id,
      // camelCase nazivi
      'apartmanNaziv': apartmanNaziv,
      'prezimeIme': prezimeIme,
      'gosti': gostiJson,
      'datumDolaska': dDolaska,
      'datumOdlaska': dOdlaska,
      'brojDana': brojDana,
      'brojOsoba': brojOsoba,
      'cijenaOsobaNoc': cijenaOsobaNoc,
      'cijenaUkupno': cijenaUkupno,
      'nacinPlacanja': nacinPlacanja,
      'racunBroj': racunBroj,
      'racunIspisan': racunIspisan,

      // snake_case nazivi (za bazu s NOT NULL ograničenjima)
      'apartman_naziv': apartmanNaziv,
      'prezime_ime': prezimeIme,
      'datum_dolaska': dDolaska,
      'datum_odlaska': dOdlaska,
      'broj_dana': brojDana,
      'broj_osoba': brojOsoba,
      'cijena_osoba_noc': cijenaOsobaNoc,
      'cijena_ukupno': cijenaUkupno,
      'nacin_placanja': nacinPlacanja,
      'racun_broj': racunBroj,
      'racun_ispisan': racunIspisan,
    };
  }

  factory TuristBoravak.fromMap(Map<String, dynamic> map) {
    List<GostStavka> ucitaniGosti = [];
    if (map['gosti'] != null && map['gosti'] is List) {
      ucitaniGosti = (map['gosti'] as List)
          .map((item) => GostStavka.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    final String glavniGost = (map['prezimeIme'] ?? map['prezime_ime'])?.toString() ?? '';

    final dDol = (map['datumDolaska'] ?? map['datum_dolaska'])?.toString();
    final dOdl = (map['datumOdlaska'] ?? map['datum_odlaska'])?.toString();

    final rBroj = (map['racunBroj'] ?? map['racun_broj'])?.toString() ?? '';

    return TuristBoravak(
      id: map['id']?.toString() ?? '',
      apartmanNaziv: (map['apartmanNaziv'] ?? map['apartman_naziv'] ?? map['apartman'])?.toString() ?? '',
      prezimeIme: glavniGost,
      gosti: ucitaniGosti.isNotEmpty
          ? ucitaniGosti
          : [GostStavka(prezimeIme: glavniGost, nositeljRacuna: true)],
      datumDolaska: dDol != null ? (DateTime.tryParse(dDol) ?? DateTime.now()) : DateTime.now(),
      datumOdlaska: dOdl != null ? (DateTime.tryParse(dOdl) ?? DateTime.now()) : DateTime.now(),
      brojDana: int.tryParse((map['brojDana'] ?? map['broj_dana'])?.toString() ?? '1') ?? 1,
      brojOsoba: int.tryParse((map['brojOsoba'] ?? map['broj_osoba'])?.toString() ?? '1') ?? 1,
      cijenaOsobaNoc: (map['cijenaOsobaNoc'] ?? map['cijena_osoba_noc'] ?? map['cijena_po_noci'] as num?)?.toDouble() ?? 0.0,
      cijenaUkupno: (map['cijenaUkupno'] ?? map['cijena_ukupno'] ?? map['ukupno'] as num?)?.toDouble() ?? 0.0,
      nacinPlacanja: (map['nacinPlacanja'] ?? map['nacin_placanja'])?.toString() ?? 'Gotovina / Cash',
      racunBroj: rBroj,
      racunIspisan: map['racunIspisan'] == true || map['racun_ispisan'] == true,
    );
  }
}
