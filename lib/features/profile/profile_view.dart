import 'package:flutter/material.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.fundCount});
  final int fundCount;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    children: [
      const Text(
        'Perfil',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFE4F3EC),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFF176B52),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Seguimiento personal de inversiones',
                      style: TextStyle(color: Color(0xFF737D78), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.pie_chart_outline_rounded),
              title: const Text('Fondos en cartera'),
              trailing: Text('$fundCount'),
            ),
            const Divider(height: 1, indent: 56),
            const ListTile(
              leading: Icon(Icons.phone_android_rounded),
              title: Text('Almacenamiento'),
              subtitle: Text('Los datos se guardan en este dispositivo.'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Inverto · versión 0.2.1',
          style: TextStyle(color: Color(0xFF737D78), fontSize: 12),
        ),
      ),
    ],
  );
}
