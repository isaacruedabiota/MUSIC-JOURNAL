import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../providers/spotify_settings_provider.dart';

/// Pantalla que facilita conectar Spotify sin editar codigo:
/// el usuario pega su Client ID, abre el dashboard y copia el Redirect URI.
class SpotifySettingsScreen extends StatefulWidget {
  const SpotifySettingsScreen({super.key});

  @override
  State<SpotifySettingsScreen> createState() => _SpotifySettingsScreenState();
}

class _SpotifySettingsScreenState extends State<SpotifySettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final current = context.read<SpotifySettingsProvider>().clientId;
    // No prellenamos con el placeholder de codigo.
    _controller = TextEditingController(
      text: SpotifyConfig.isConfigured ? current : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDashboard() async {
    final uri = Uri.parse(SpotifyConfig.dashboardUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _snack('No se pudo abrir el navegador. Copia la URL manualmente:\n'
          '${SpotifyConfig.dashboardUrl}');
    }
  }

  Future<void> _copyRedirectUri() async {
    await Clipboard.setData(
        const ClipboardData(text: SpotifyConfig.redirectUri));
    _snack('Redirect URI copiado');
  }

  Future<void> _save() async {
    final id = _controller.text.trim();
    if (id.isEmpty) {
      _snack('Pega tu Client ID primero');
      return;
    }
    await context.read<SpotifySettingsProvider>().setClientId(id);
    if (!mounted) return;
    _snack('Client ID guardado. Ya puedes conectar Spotify.');
    Navigator.pop(context);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SpotifySettingsProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Conectar Spotify')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Pasos (solo la primera vez)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const _Step(
              n: 1, text: 'Abre el dashboard de Spotify e inicia sesion.'),
          const _Step(n: 2, text: 'Pulsa "Create app" (nombre y descripcion libres).'),
          _StepRich(
            n: 3,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('En "Redirect URIs" pega: '),
                _CopyChip(
                  label: SpotifyConfig.redirectUri,
                  onTap: _copyRedirectUri,
                ),
              ],
            ),
          ),
          const _Step(n: 4, text: 'Marca "Web API" y guarda.'),
          const _Step(
              n: 5,
              text: 'Copia el "Client ID" y pegalo abajo. (No hace falta el '
                  'Client Secret.)'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openDashboard,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir dashboard de Spotify'),
          ),
          const Divider(height: 40),
          Text('Tu Client ID',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'p. ej. 3f9a2b1c...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Pegar del portapapeles',
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _controller.text = data!.text!.trim();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
          if (settings.isConfigured) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Configurado',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await context.read<SpotifySettingsProvider>().clear();
                    _controller.clear();
                    _snack('Client ID borrado');
                  },
                  child: const Text('Borrar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _StepRich(n: n, child: Text(text));
  }
}

class _StepRich extends StatelessWidget {
  const _StepRich({required this.n, required this.child});
  final int n;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text('$n',
                style: TextStyle(
                    fontSize: 12, color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CopyChip extends StatelessWidget {
  const _CopyChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.copy, size: 16),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
