// lib/services/podaci_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PodaciService extends ChangeNotifier {
  static final PodaciService _instance = PodaciService._internal();
  factory PodaciService() => _instance;
  PodaciService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  List> _boravci = [];
  List> get boravci => _boravci;

  bool _ucitavanje = false;
  bool get ucitavanje => _ucitavanje;

  /// Učitava sve boravke i turiste iz Supabase baze
  Future<void> ucitajBoravke() async {
    _ucitavanje = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('turisti_boravci')
          .select()
          .order('created_at', ascending: false);

      _boravci = List>.from(response);
    } catch (e) {
      debugPrint('Greška pri dohvaćanju boravaka: $e');
    } finally {
      _ucitavanje = false;
      notifyListeners();
    }
  }

  /// Sprema novi boravak s pripadajućim popisom gostiju u Supabase
  Future<bool> spremiBoravak({
    required String apartman,
    required DateTime dolazak,
    required DateTime odlazak,
    required String nacinPlacanja,
    required double cijenaPoNoci,
    required double ukupno,
    required List> osobe,
    required int nositeljIndeks,
  }) async {
    try {
      final noviZapis = {
        'apartman': apartman,
        'datum_dolaska': dolazak.toIso8601String().split('T').first,
        'datum_odlaska': odlazak.toIso8601String().split('T').first,
        'nacin_placanja': nacinPlacanja,
        'cijena_po_noci': cijenaPoNoci,
        'ukupno': ukupno,
        'osobe': osobe, // JSONB polje sa svim skeniranim osobama
        'nositelj_indeks': nositeljIndeks,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('turisti_boravci')
          .insert(noviZapis)
          .select()
          .single();

      _boravci.insert(0, response);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Greška pri spremanju boravka: $e');
      return false;
    }
  }

  /// Brisanje boravka iz baze
  Future<bool> obrisiBoravak(dynamic id) async {
    try {
      await _supabase.from('turisti_boravci').delete().eq('id', id);
      _boravci.removeWhere((item) => item['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Greška pri brisanju boravka: $e');
      return false;
    }
  }
}
