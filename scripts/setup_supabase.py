#!/usr/bin/env python3
"""
Automatiza la instalación de herramientas necesarias y ejecuta el script de setup para Supabase.

Funciones principales:
- Comprueba/instala `psql` (intento via apt-get en Debian/Ubuntu).
- Comprueba/instala `supabase` CLI (prefiere npm, si no descarga el binario de GitHub releases).
- Ejecuta `database/postgresql/supabase_setup.sh`.

Uso:
  python3 scripts/setup_supabase.py [--env PATH] [--supabase-version vX.Y.Z]

Nota: Algunas operaciones requieren `sudo` (instalación via apt) y acceso a `npm` si se usa esa ruta.
"""

from __future__ import annotations
import argparse
import os
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.request


def run(cmd: str, check=True):
    print(f"$ {cmd}")
    return subprocess.run(cmd, shell=True, check=check)


def ensure_psql():
    if shutil.which("psql"):
        print("psql encontrado en PATH.")
        return True
    print("psql no encontrado. Intentando instalar via apt-get (requiere sudo)...")
    try:
        run("sudo apt-get update && sudo apt-get install -y postgresql-client")
    except subprocess.CalledProcessError:
        print("Instalación automática de psql falló. Por favor instala manualmente.")
        return False
    return bool(shutil.which("psql"))


def download_and_extract_supabase(version: str, tools_dir: str) -> str:
    asset = f"supabase_{version}_linux_amd64.tar.gz"
    url = f"https://github.com/supabase/cli/releases/download/{version}/{asset}"
    os.makedirs(tools_dir, exist_ok=True)
    dest = os.path.join(tools_dir, asset)
    print(f"Descargando {url} -> {dest}")
    try:
        urllib.request.urlretrieve(url, dest)
    except Exception as e:
        raise RuntimeError(f"Fallo al descargar {url}: {e}")
    print("Extrayendo...")
    with tarfile.open(dest, "r:gz") as tf:
        tf.extractall(path=tools_dir)
    # el ejecutable suele ser tools/supabase
    supabase_path = os.path.join(tools_dir, "supabase")
    if os.path.exists(supabase_path):
        st = os.stat(supabase_path)
        os.chmod(supabase_path, st.st_mode | stat.S_IEXEC)
        print(f"Supabase extraído en {supabase_path}")
        return supabase_path
    # Buscamos cualquier binario extraído
    for entry in os.listdir(tools_dir):
        p = os.path.join(tools_dir, entry)
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    raise FileNotFoundError("No se encontró el ejecutable de supabase tras extraer el tarball.")


def ensure_supabase(version: str = "v1.71.6") -> str:
    path = shutil.which("supabase")
    if path:
        print(f"supabase CLI encontrado en: {path}")
        return path

    # Intentar npm
    if shutil.which("npm"):
        print("npm encontrado; intentando: npm install -g supabase")
        try:
            run("npm install -g supabase")
            path = shutil.which("supabase")
            if path:
                print(f"supabase instalado via npm en: {path}")
                return path
        except subprocess.CalledProcessError:
            print("npm install -g supabase falló; intentar descarga directa.")

    # Descargar binario a tools/
    tools_dir = os.path.join(os.getcwd(), "tools")
    try:
        p = download_and_extract_supabase(version, tools_dir)
        print(f"Usando supabase en {p}")
        return p
    except Exception as e:
        print(f"No fue posible obtener supabase CLI: {e}")
        raise


def run_setup_script(env_file: str | None = None, supabase_exec: str | None = None):
    script = os.path.join("database", "postgresql", "supabase_setup.sh")
    if not os.path.exists(script):
        raise FileNotFoundError(f"No se encontró el script {script}")
    os.chmod(script, os.stat(script).st_mode | stat.S_IEXEC)

    env = os.environ.copy()
    if env_file:
        env["SUPABASE_ENV_FILE"] = env_file

    # Si supabase_exec es un binario en tools, queremos usar su carpeta en PATH
    if supabase_exec:
        supabase_dir = os.path.dirname(os.path.abspath(supabase_exec))
        env["PATH"] = supabase_dir + os.pathsep + env.get("PATH", "")

    print(f"Ejecutando {script} (con SUPABASE_ENV_FILE={env.get('SUPABASE_ENV_FILE')})")
    subprocess.check_call([script], env=env)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", help="Ruta al fichero .env.supabase", default=None)
    parser.add_argument("--supabase-version", help="Versión release de supabase (ej. v1.71.6)", default="v1.71.6")
    args = parser.parse_args()

    ok = ensure_psql()
    if not ok:
        print("psql no instalado. Continúo pero algunas operaciones pueden fallar.")

    supabase_exec = None
    try:
        supabase_exec = ensure_supabase(args.supabase_version)
    except Exception:
        print("No se pudo asegurar supabase CLI. Salida.")
        sys.exit(1)

    try:
        run_setup_script(env_file=args.env, supabase_exec=supabase_exec)
    except subprocess.CalledProcessError as e:
        print(f"El script de setup falló: {e}")
        sys.exit(1)

    print("Setup completado. Verifica en Supabase Studio o con psql.")


if __name__ == "__main__":
    main()
