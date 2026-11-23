"""Check public release settings and build a signed Google Play bundle.

Run: python3 tool/build_play_release.py --check
Run: python3 tool/build_play_release.py
Secrets stay in ignored local files and are never printed.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]


def validate(config_path):
    problems = []
    config = {}
    try:
        config = json.loads(config_path.read_text())
        if not isinstance(config, dict):
            raise ValueError()
    except (OSError, ValueError):
        config = {}
        problems.append('config/release.local.json yok veya okunamıyor.')
    for field in [
        'DEVELOPER_NAME',
        'SUPPORT_EMAIL',
        'PRIVACY_POLICY_URL',
        'IZ_MOVIE_API_URL',
    ]:
        if not isinstance(config.get(field), str) or not config[field].strip():
            problems.append(f'{field} doldurulmalı.')
    email = str(config.get('SUPPORT_EMAIL', '')).strip()
    if email and not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
        problems.append('Destek e-postası geçersiz.')
    uri = urlparse(str(config.get('PRIVACY_POLICY_URL', '')).strip())
    if uri.scheme != 'https' or not uri.hostname or uri.username:
        problems.append('Gizlilik sayfası herkese açık bir HTTPS adresi olmalı.')
    if uri.hostname in {'localhost', 'example.com', '127.0.0.1'}:
        problems.append('Gizlilik sayfası örnek/yerel bir adres olamaz.')
    api_uri = urlparse(str(config.get('IZ_MOVIE_API_URL', '')).strip())
    if api_uri.scheme != 'https' or not api_uri.hostname or api_uri.username:
        problems.append('İZ Katalog API herkese açık bir HTTPS adresinde olmalı.')
    if api_uri.hostname in {'localhost', 'example.com', '127.0.0.1'}:
        problems.append('İZ Katalog API örnek/yerel bir adres olamaz.')
    key_file = ROOT / 'android/key.properties'
    if not key_file.exists():
        problems.append('Android yükleme anahtarı ayarı (android/key.properties) eksik.')
    else:
        properties = {}
        for line in key_file.read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key, value = line.split('=', 1)
                properties[key.strip()] = value.strip()
        for key in ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']:
            if not properties.get(key):
                problems.append(f'Android imza ayarında {key} eksik.')
        keystore = Path(properties.get('storeFile', ''))
        if not keystore.is_absolute():
            keystore = ROOT / 'android' / keystore
        if not keystore.is_file():
            problems.append('Yükleme anahtarı dosyası bulunamadı.')
        if keystore.name == 'debug.keystore' or properties.get('keyAlias') == 'androiddebugkey':
            problems.append('Google Play için geliştirme anahtarı kullanılamaz.')
    return config, problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Yalnızca yerel ayarları kontrol et')
    args = parser.parse_args()
    config_path = ROOT / 'config/release.local.json'
    config, problems = validate(config_path)
    if problems:
        print('Yayın için tamamlanması gerekenler:')
        for problem in problems:
            print(f'- {problem}')
        return 2
    if args.check:
        print('Yerel ayarlar tamam. Web adresi ve imza derleme sırasında doğrulanacak.')
        return 0
    try:
        with urllib.request.urlopen(config['PRIVACY_POLICY_URL'], timeout=20) as response:
            page = response.read(262144).decode('utf-8', errors='replace')
            if response.status != 200 or config['SUPPORT_EMAIL'] not in page:
                raise ValueError()
    except Exception:
        print('Gizlilik sayfası açılamadı veya destek e-postasını içermiyor. Yayını durdurdum.')
        return 2
    try:
        health_url = config['IZ_MOVIE_API_URL'].rstrip('/') + '/health'
        with urllib.request.urlopen(health_url, timeout=20) as response:
            health = json.loads(response.read(65536))
            if response.status != 200 or health.get('status') != 'ok':
                raise ValueError()
    except Exception:
        print('İZ Katalog API sağlık kontrolü başarısız. Yayını durdurdum.')
        return 2
    flutter = shutil.which('flutter')
    if not flutter:
        print('Flutter bulunamadı.')
        return 2
    subprocess.run([flutter, '--no-version-check', 'test', '--no-pub'], cwd=ROOT, check=True)
    subprocess.run([flutter, '--no-version-check', 'analyze', '--no-pub'], cwd=ROOT, check=True)
    subprocess.run([
        flutter, '--no-version-check', 'build', 'appbundle', '--release', '--no-pub',
        f'--dart-define-from-file={config_path}',
    ], cwd=ROOT, check=True)
    print('İmzalı paket: build/app/outputs/bundle/release/app-release.aab')
    print('Play Console yükleme ve test aşaması henüz yapılmadı.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
