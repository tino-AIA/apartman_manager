// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
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

  runApp(const ApartmanApp());
}

class ApartmanApp extends StatelessWidget {
  const ApartmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apartman Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Plava Brela
        ),
        useMaterial3: true,
      ),
      home: const GlavniEkran(),
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

  final List<Widget> _ekrani = [
    const TuristiScreen(),        // Popis turista & OCR skeniranje (povezano s bazom)
    const RacuniScreen(),         // Izdavanje računa & Print (A4 PDF + 58mm)
    const KnjigaPrometaScreen(),  // Knjiga prometa (Obrazac EP) & Excel/PDF izvoz
    const PostavkeScreen(),       // Postavke vlasnika & Sezonski cjenici
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ekrani[_odabraniIndeks],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _odabraniIndeks,
        onDestinationSelected: (idx) => setState(() => _odabraniIndeks = idx),
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
