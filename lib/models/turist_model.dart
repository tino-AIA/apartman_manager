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
}

class TuristBoravak {
  final String id;
  final String apartmanNaziv;
  final String prezimeIme; // Glavni gost / nositelj računa
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

  TuristBoravak copyWith({
    String? id,
    String? apartmanNaziv,
    String? prezimeIme,
    List<GostStavka>? gosti,
    DateTime? datumDolaska,
    DateTime? datumOdlaska,
    int? brojDana,
    int? brojOsoba,
    double? cijenaOsobaNoc,
    double? cijenaUkupno,
    String? nacinPlacanja,
    String? racunBroj,
    bool? racunIspisan,
  }) {
    return TuristBoravak(
      id: id ?? this.id,
      apartmanNaziv: apartmanNaziv ?? this.apartmanNaziv,
      prezimeIme: prezimeIme ?? this.prezimeIme,
      gosti: gosti ?? this.gosti,
      datumDolaska: datumDolaska ?? this.datumDolaska,
      datumOdlaska: datumOdlaska ?? this.datumOdlaska,
      brojDana: brojDana ?? this.brojDana,
      brojOsoba: brojOsoba ?? this.brojOsoba,
      cijenaOsobaNoc: cijenaOsobaNoc ?? this.cijenaOsobaNoc,
      cijenaUkupno: cijenaUkupno ?? this.cijenaUkupno,
      nacinPlacanja: nacinPlacanja ?? this.nacinPlacanja,
      racunBroj: racunBroj ?? this.racunBroj,
      racunIspisan: racunIspisan ?? this.racunIspisan,
    );
  }
}
