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
      prezimeIme: map['prezimeIme']?.toString() ?? '',
      brojDokumenta: map['brojDokumenta']?.toString() ?? '',
      nositeljRacuna: map['nositeljRacuna'] == true,
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apartmanNaziv': apartmanNaziv,
      'prezimeIme': prezimeIme,
      'gosti': gosti.map((g) => g.toMap()).toList(),
      'datumDolaska': datumDolaska.toIso8601String().split('T').first,
      'datumOdlaska': datumOdlaska.toIso8601String().split('T').first,
      'brojDana': brojDana,
      'brojOsoba': brojOsoba,
      'cijenaOsobaNoc': cijenaOsobaNoc,
      'cijenaUkupno': cijenaUkupno,
      'nacinPlacanja': nacinPlacanja,
      'racunBroj': racunBroj,
      'racunIspisan': racunIspisan,
    };
  }

  factory TuristBoravak.fromMap(Map<String, dynamic> map) {
    List<GostStavka> ucitaniGosti = [];
    if (map['gosti'] != null && map['gosti'] is List) {
      ucitaniGosti = (map['gosti'] as List)
          .map((item) => GostStavka.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    final String glavniGost = map['prezimeIme']?.toString() ?? '';

    return TuristBoravak(
      id: map['id']?.toString() ?? '',
      apartmanNaziv: map['apartmanNaziv']?.toString() ?? 'Apartman A1',
      prezimeIme: glavniGost,
      gosti: ucitaniGosti.isNotEmpty
          ? ucitaniGosti
          : [GostStavka(prezimeIme: glavniGost, nositeljRacuna: true)],
      datumDolaska: DateTime.tryParse(map['datumDolaska']?.toString() ?? '') ?? DateTime.now(),
      datumOdlaska: DateTime.tryParse(map['datumOdlaska']?.toString() ?? '') ?? DateTime.now(),
      brojDana: int.tryParse(map['brojDana']?.toString() ?? '1') ?? 1,
      brojOsoba: int.tryParse(map['brojOsoba']?.toString() ?? '1') ?? 1,
      cijenaOsobaNoc: (map['cijenaOsobaNoc'] as num?)?.toDouble() ?? 0.0,
      cijenaUkupno: (map['cijenaUkupno'] as num?)?.toDouble() ?? 0.0,
      nacinPlacanja: map['nacinPlacanja']?.toString() ?? 'Gotovina / Cash',
      racunBroj: map['racunBroj']?.toString() ?? '1/1/1',
      racunIspisan: map['racunIspisan'] == true,
    );
  }

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
