// lib/screens/postavke_screen.dart
import 'package:flutter/material.dart';
import '../models/postavke_model.dart';

class PostavkeScreen extends StatefulWidget {
  const PostavkeScreen({super.key});

  @override
  State<PostavkeScreen> createState() => _PostavkeScreenState();
}

class _PostavkeScreenState extends State<PostavkeScreen> {
  // Predefinirani podaci iz vaše tablice Brela
  final _nazivObjektaCtrl = TextEditingController(text: 'Sunset Villa Brela');
  final _imePrezimeCtrl = TextEditingController(text: 'Miha Šošić');
  final _oibCtrl = TextEditingController(text: '43163137097');
  final _mjestoCtrl = TextEditingController(text: '21322 Brela');
  final _adresaCtrl = TextEditingController(text: 'Podrače 1');
  final _telefonCtrl = TextEditingController(text: '+386 41 527 274');
  final _emailCtrl = TextEditingController(text: 'info@sosic-brela.com');

  // Cijene za 4 sezone po osobi/noći
  final _izvanSezoneCtrl = TextEditingController(text: '25.00');
  final _predsezonaCtrl = TextEditingController(text: '30.00');
  final _glavnaSezonaCtrl = TextEditingController(text: '45.00');
  final _postsezonaCtrl = TextEditingController(text: '30.00');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postavke iznajmljivača'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Podaci za Knjigu prometa i Račune', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: _nazivObjektaCtrl, decoration: const InputDecoration(labelText: 'Naziv objekta', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _imePrezimeCtrl, decoration: const InputDecoration(labelText: 'Ime i prezime vlasnika', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _oibCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OIB (11 znamenki)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _mjestoCtrl, decoration: const InputDecoration(labelText: 'Mjesto i pošt. br.', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _adresaCtrl, decoration: const InputDecoration(labelText: 'Ulica i kućni broj', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _telefonCtrl, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()))),
              ],
            ),
            const Divider(height: 40),
            const Text('Sezonski cjenik (Cijena po osobi / noć)', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _izvanSezoneCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Izvan sezone (€)', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _predsezonaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Predsezona (€)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _glavnaSezonaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Glavna sezona (€)', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _postsezonaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Postsezona (€)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Postavke i cjenik uspješno spremljeni!')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('SPREMI POSTAVKE', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
