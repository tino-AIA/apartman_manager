// lib/models/turist_model.dart

class TuristBoravak {
  final String id;
  final String nacinPlacanja; // 'Booking', 'Gotovina / Cash', 'Transakcijski račun / Bank transfer', 'Airbnb'
  final String racunBroj;     // npr. "102/26"
  final String prezimeIme;
  final String? drzavljanstvo;
  final String? brojIsprave;
  final DateTime datumDolaska;
  final DateTime datumOdlaska;
  final int brojOsoba;
  final int brojDana;
  final double cijenaUkupno;
  final double cijenaOsobaNoc;
  final bool racunIspisan;

  TuristBoravak({
    required this.id,
    required this.nacinPlacanja,
    required this.racunBroj,
    required this.prezimeIme,
    this.drzavljanstvo,
    this.brojIsprave,
    required this.datumDolaska,
    required this.datumOdlaska,
    required this.brojOsoba,
    required this.brojDana,
    required this.cijenaUkupno,
    required this.cijenaOsobaNoc,
    this.racunIspisan = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nacinPlacanja': nacinPlacanja,
      'racunBroj': racunBroj,
      'prezimeIme': prezimeIme,
      'drzavljanstvo': drzavljanstvo,
      'brojIsprave': brojIsprave,
      'datumDolaska': datumDolaska.toIso8601String(),
      'datumOdlaska': datumOdlaska.toIso8601String(),
      'brojOsoba': brojOsoba,
      'brojDana': brojDana,
      'cijenaUkupno': cijenaUkupno,
      'cijenaOsobaNoc': cijenaOsobaNoc,
      'racunIspisan': racunIspisan,
    };
  }

  factory TuristBoravak.fromMap(Map<String, dynamic> map) {
    return TuristBoravak(
      id: map['id'],
      nacinPlacanja: map['nacinPlacanja'],
      racunBroj: map['racunBroj'],
      prezimeIme: map['prezimeIme'],
      drzavljanstvo: map['drzavljanstvo'],
      brojIsprave: map['brojIsprave'],
      datumDolaska: DateTime.parse(map['datumDolaska']),
      datumOdlaska: DateTime.parse(map['datumOdlaska']),
      brojOsoba: map['brojOsoba'],
      brojDana: map['brojDana'],
      cijenaUkupno: (map['cijenaUkupno'] as num).toDouble(),
      cijenaOsobaNoc: (map['cijenaOsobaNoc'] as num).toDouble(),
      racunIspisan: map['racunIspisan'] ?? false,
    );
  }
}
