# Descargador de música legal (herramienta de PC)

Herramienta de línea de comandos, **separada de la app móvil** (yt-dlp no puede
ejecutarse dentro de una app iOS/Android). Se ejecuta en tu ordenador.

## Alcance legal — léelo

Esta herramienta está pensada **exclusivamente** para música que puedes descargar
legalmente:

- ✅ **Dominio público**
- ✅ **Creative Commons**
- ✅ **Contenido tuyo** o con permiso explícito del autor

**No** busca canciones de Spotify en YouTube ni descarga catálogo comercial con
copyright — eso sería infracción y no está soportado. La responsabilidad del uso
es de quien la ejecuta.

## Instalación

```bash
cd tools/legal_music_downloader
pip install -r requirements.txt
```

- **yt-dlp** ya lo tienes instalado.
- **ffmpeg** (opcional): solo hace falta para convertir a mp3 en el modo `url`.
  En Windows: `winget install Gyan.FFmpeg` (o descárgalo de ffmpeg.org).
  Sin ffmpeg, el modo `url --audio-only` baja el mejor audio sin convertir.

## Uso

### Buscar y descargar del Internet Archive (fuente legal por defecto)

Filtra por licencia libre (dominio público / Creative Commons) automáticamente:

```bash
python download.py search "kevin macleod"
python download.py search "jazz" --limit 30
python download.py search "beethoven" --include-unknown-license
```

Te lista resultados con su **licencia visible**; eliges los números y los descarga
a `downloads/`, etiquetando los mp3 (título, artista, álbum).

### Descargar una URL concreta (contenido tuyo / PD / CC)

```bash
python download.py url https://archive.org/details/<identificador>
python download.py url "<URL que tienes derecho a bajar>" --audio-only
```

Usa **yt-dlp** como motor de descarga.

## Fuentes legales recomendadas

- **Internet Archive** — https://archive.org (dominio público + CC)
- **Free Music Archive** — https://freemusicarchive.org (CC)
- **Jamendo** — https://www.jamendo.com (CC)
- **ccMixter** — http://ccmixter.org (CC)

## Relación con la app

La app Music Journal detecta y registra lo que escuchas. En un futuro módulo de
**wishlist**, podría exportar una lista de canciones que quieras conseguir por
vías legales; esta herramienta cubre el lado de descarga de fuentes libres.
