import 'package:flutter/material.dart';

import '../services/permissions.dart';

/// Pide el «Acceso a notificaciones», sin el que no se puede leer Spotify.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.queue_music,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('MusicList', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Para registrar lo que suena en Spotify, incluso con la '
                  'pantalla apagada, MusicList necesita acceso a las '
                  'notificaciones. Solo usa la de Spotify; las demás se ignoran.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: Permissions.openNotificationAccess,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Dar acceso a notificaciones'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Si el interruptor aparece bloqueado: Ajustes › Aplicaciones › '
                  'MusicList › ⋮ › Permitir ajustes restringidos.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
