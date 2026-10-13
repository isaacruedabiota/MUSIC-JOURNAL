import 'package:flutter/material.dart';

import '../services/ajustes.dart';
import '../services/descargas.dart';

/// Ajustes: dónde se guardan las descargas. Se conserva al instalar
/// versiones nuevas de la app.
class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key, required this.ajustes});

  final Ajustes ajustes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Se reconstruye al elegir carpeta.
          ListenableBuilder(
            listenable: ajustes,
            builder: (context, _) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Carpeta de descargas'),
              subtitle: Text(ajustes.carpetaNombre ?? 'Sin elegir'),
              trailing: FilledButton.tonal(
                onPressed: ajustes.elegirCarpeta,
                child: const Text('Elegir'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Android no deja usar la raíz ni la carpeta Download entera: elige '
            'o crea una carpeta como Music.\n\n'
            'Las canciones se piden a $servidorDescargas (hay que estar en la '
            'misma Wi-Fi).',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
