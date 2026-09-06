#!/usr/bin/env python3
"""
Descargador de musica LEGAL (herramienta de PC, no parte de la app movil).

Alcance: SOLO contenido que puedes descargar legalmente:
  - Dominio publico
  - Creative Commons
  - Contenido tuyo o con permiso del autor

Fuente principal: Internet Archive (archive.org), filtrando por licencia libre.
Modo URL: usa yt-dlp para bajar de una URL concreta que TENGAS DERECHO a bajar.

Esta herramienta NO busca canciones de Spotify en YouTube ni descarga catalogo
comercial con copyright. Eso seria infraccion y no esta soportado.

Uso:
  python download.py search "kevin macleod"          # busca en Internet Archive
  python download.py search "jazz" --limit 30
  python download.py search "beethoven" --include-unknown-license
  python download.py url https://archive.org/details/<id>
  python download.py url "<URL de contenido tuyo/PD/CC>" --audio-only
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

import requests

# La consola de Windows suele ser cp1252 y revienta con Unicode (acentos en
# titulos, simbolos). Forzamos UTF-8 y reemplazamos lo que no se pueda pintar.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

IA_SEARCH = "https://archive.org/advancedsearch.php"
IA_META = "https://archive.org/metadata/{identifier}"
IA_DL = "https://archive.org/download/{identifier}/{filename}"

AUDIO_EXT = (".mp3", ".flac", ".ogg", ".oga", ".m4a", ".wav", ".opus")

DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "downloads")

LEGAL_NOTICE = (
    "Recuerda: usa esto SOLO con contenido de dominio publico, Creative Commons "
    "o tuyo. Descargar musica con copyright sin permiso es ilegal."
)


# ---------- utilidades ----------

def sanitize(name: str) -> str:
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name)
    return name.strip().strip(".") or "audio"


def human_license(url: str | None) -> str:
    if not url:
        return "-"
    u = url.lower()
    if "publicdomain" in u:
        return "Dominio publico"
    if "creativecommons.org" in u:
        m = re.search(r"/licenses/([a-z-]+)/", u)
        return f"CC {m.group(1).upper()}" if m else "Creative Commons"
    return url


def is_open_license(licenseurl: str | None) -> bool:
    if not licenseurl:
        return False
    u = licenseurl.lower()
    return "creativecommons.org" in u or "publicdomain" in u


# ---------- Internet Archive: buscar ----------

def search_ia(query: str, limit: int):
    params = {
        "q": f"({query}) AND mediatype:audio",
        "fl[]": ["identifier", "title", "creator", "year", "licenseurl"],
        "rows": str(limit),
        "sort[]": "downloads desc",
        "output": "json",
    }
    r = requests.get(IA_SEARCH, params=params, timeout=30)
    r.raise_for_status()
    return r.json().get("response", {}).get("docs", [])


def cmd_search(args):
    print(f"Buscando en Internet Archive: {args.query!r} ...\n")
    docs = search_ia(args.query, args.limit)

    if not args.include_unknown_license:
        filtered = [d for d in docs if is_open_license(d.get("licenseurl"))]
        hidden = len(docs) - len(filtered)
        docs = filtered
        if hidden:
            print(f"({hidden} resultados ocultos por licencia no confirmada. "
                  f"Usa --include-unknown-license para verlos.)\n")

    if not docs:
        print("Sin resultados con licencia libre confirmada.")
        return

    for i, d in enumerate(docs, 1):
        title = _first(d.get("title")) or d.get("identifier")
        creator = _first(d.get("creator")) or "-"
        year = d.get("year") or "-"
        lic = human_license(d.get("licenseurl"))
        print(f"[{i:2}] {title}")
        print(f"     {creator} | {year} | {lic}")

    print()
    try:
        sel = input("Numeros a descargar (ej: 1 3 5), Enter para cancelar: ").strip()
    except EOFError:
        sel = ""
    if not sel:
        print("Cancelado (nada seleccionado).")
        return

    picks = _parse_selection(sel, len(docs))
    for idx in picks:
        d = docs[idx - 1]
        if not is_open_license(d.get("licenseurl")) and not args.include_unknown_license:
            continue
        download_ia_item(d, args.out)

    print("\n" + LEGAL_NOTICE)


def _first(v):
    if isinstance(v, list):
        return v[0] if v else None
    return v


def _parse_selection(sel: str, n: int):
    out = []
    for tok in re.split(r"[\s,]+", sel):
        if tok.isdigit():
            k = int(tok)
            if 1 <= k <= n:
                out.append(k)
    return out


# ---------- Internet Archive: descargar ----------

def download_ia_item(doc, out_dir):
    identifier = doc["identifier"]
    item_title = _first(doc.get("title")) or identifier
    creator = _first(doc.get("creator")) or ""
    lic = human_license(doc.get("licenseurl"))

    print(f"\n>> {item_title}  [{lic}]")
    meta = requests.get(IA_META.format(identifier=identifier), timeout=30).json()
    files = meta.get("files", [])
    audio = [f for f in files if f.get("name", "").lower().endswith(AUDIO_EXT)]
    # Preferimos mp3 para no depender de ffmpeg.
    audio.sort(key=lambda f: 0 if f["name"].lower().endswith(".mp3") else 1)

    if not audio:
        print("   (sin archivos de audio)")
        return

    dest_dir = os.path.join(out_dir, sanitize(f"{creator} - {item_title}" if creator else item_title))
    os.makedirs(dest_dir, exist_ok=True)

    for f in audio:
        name = f["name"]
        url = IA_DL.format(identifier=identifier, filename=requests.utils.quote(name))
        path = os.path.join(dest_dir, sanitize(name))
        if os.path.exists(path):
            print(f"   = ya existe: {name}")
            continue
        print(f"   -> {name}")
        _download_file(url, path)
        if path.lower().endswith(".mp3"):
            _tag_mp3(path, title=f.get("title") or os.path.splitext(name)[0],
                     artist=creator or _first(doc.get("creator")) or "",
                     album=item_title)
    print(f"   Guardado en: {dest_dir}")


def _download_file(url, path):
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        tmp = path + ".part"
        with open(tmp, "wb") as fh:
            for chunk in r.iter_content(chunk_size=1 << 16):
                fh.write(chunk)
        os.replace(tmp, path)


def _tag_mp3(path, title, artist, album):
    try:
        from mutagen.easyid3 import EasyID3
        from mutagen.id3 import ID3NoHeaderError
        try:
            tags = EasyID3(path)
        except ID3NoHeaderError:
            from mutagen.mp3 import MP3
            m = MP3(path)
            m.add_tags()
            m.save()
            tags = EasyID3(path)
        if title:
            tags["title"] = title
        if artist:
            tags["artist"] = artist
        if album:
            tags["album"] = album
        tags.save()
    except Exception as e:
        print(f"   (no se pudieron escribir tags: {e})")


# ---------- Modo URL (yt-dlp) ----------

def cmd_url(args):
    if shutil.which("yt-dlp") is None:
        sys.exit("yt-dlp no esta en el PATH. Instala con: pip install yt-dlp")

    print(LEGAL_NOTICE + "\n")
    os.makedirs(args.out, exist_ok=True)
    out_tmpl = os.path.join(args.out, "%(title)s.%(ext)s")

    cmd = ["yt-dlp", "-o", out_tmpl, "--add-metadata"]

    has_ffmpeg = shutil.which("ffmpeg") is not None
    if args.audio_only:
        if has_ffmpeg:
            cmd += ["-x", "--audio-format", "mp3", "--embed-thumbnail"]
        else:
            print("(ffmpeg no encontrado: bajo el mejor audio sin convertir a mp3)\n")
            cmd += ["-f", "bestaudio"]
    cmd.append(args.url)

    print("Ejecutando:", " ".join(cmd), "\n")
    subprocess.run(cmd, check=False)


# ---------- CLI ----------

def build_parser():
    p = argparse.ArgumentParser(
        description="Descargador de musica LEGAL (dominio publico / CC / contenido propio).",
        epilog=LEGAL_NOTICE,
    )
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("search", help="Buscar y descargar de Internet Archive")
    s.add_argument("query", help="Texto a buscar")
    s.add_argument("--limit", type=int, default=20, help="Numero de resultados")
    s.add_argument("--include-unknown-license", action="store_true",
                   help="Incluir resultados sin licencia libre confirmada")
    s.add_argument("--out", default=DEFAULT_OUT, help="Carpeta de descargas")
    s.set_defaults(func=cmd_search)

    u = sub.add_parser("url", help="Descargar de una URL (tuyo / PD / CC) con yt-dlp")
    u.add_argument("url", help="URL del contenido que tienes derecho a bajar")
    u.add_argument("--audio-only", action="store_true", help="Extraer solo el audio")
    u.add_argument("--out", default=DEFAULT_OUT, help="Carpeta de descargas")
    u.set_defaults(func=cmd_url)

    return p


def main():
    args = build_parser().parse_args()
    try:
        args.func(args)
    except KeyboardInterrupt:
        print("\nInterrumpido.")
    except requests.HTTPError as e:
        sys.exit(f"Error HTTP: {e}")


if __name__ == "__main__":
    main()
