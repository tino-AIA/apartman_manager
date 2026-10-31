// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'services/podaci_service.dart';
import 'screens/login_screen.dart';
import 'screens/postavke_screen.dart';
import 'screens/turisti_screen.dart';
import 'screens/racuni_screen.dart';
import 'screens/knjiga_prometa_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicijalizacija Supabase veze s bazom
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Ako već postoji prijavljen korisnik, učitaj podatke iz Supabasea
  if (Supabase.instance.client.auth.currentUser != null) {
    await PodaciService().ucitajIzSupabase();
  }

  runApp(const ApartmanApp());
}

class ApartmanApp extends StatelessWidget {
  const ApartmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final jePrijavljen = Supabase.instance.client.auth.currentUser != null;

    return MaterialApp(
      title: 'Apartman Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Plava Brela
        ),
        useMaterial3: true,
      ),
      home: jePrijavljen ? const GlavniEkran() : const LoginScreen(),
    );
  }
}

class GlavniEkran extends StatefulWidget {
  const GlavniEkran({super.key});

  @override
  State<GlavniEkran> createState() => _GlavniEkranState();
}

class _GlavniEkranState extends State<GlavniEkran> {
  int _odabraniIndeks = 0;

  final List<String> _naslovi = const [
    'Popis turista',
    'Izdani računi',
    'Knjiga prometa (EP)',
    'Postavke iznajmljivača',
  ];

  Future<void> _odjaviSe() async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odjava'),
        content: const Text('Želite li se odjaviti iz aplikacije?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odjavi se', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (potvrda == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_naslovi[_odabraniIndeks]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Odjava',
            onPressed: _odjaviSe,
          ),
        ],
      ),
      body: IndexedStack(
        index: _odabraniIndeks,
        children: const [
          TuristiScreen(),        // Popis turista & OCR skeniranje
          RacuniScreen(),         // Izdavanje računa & Print (A4 PDF + 58mm)
          KnjigaPrometaScreen(),  // Knjiga prometa (Obrazac EP)
          PostavkeScreen(),       // Postavke vlasnika & Sezonski cjenici
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _odabraniIndeks,
        onDestinationSelected: (idx) {
          setState(() => _odabraniIndeks = idx);
          // Osvježi podatke kada se korisnik prebaci na Turisti, Računi ili Knjiga EP
          if (idx == 0 || idx == 1 || idx == 2) {
            PodaciService().ucitajIzSupabase();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Turisti',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Računi',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Knjiga EP',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Postavke',
          ),
        ],
      ),
    );
  }
}
