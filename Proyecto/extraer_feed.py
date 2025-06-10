#!/usr/bin/env python3
import json
import requests
import subprocess
import re
import os

env_file = 'misp_vars.env'
with open(env_file, 'r') as file:
    for line in file:
        line = line.strip()
        if '=' in line:
            key, value = line.split('=', 1)
            os.environ[key] = value.strip('"')

misp_url = os.getenv('misp_url')
misp_key = os.getenv('misp_key')

feeds = "feeds.json"
with open(feeds, 'w') as file:
    pass

curl_command = [
    "curl",
    "--insecure",
    "--silent", 
    "--header", f"Authorization:{misp_key} ",
    "--header", "Accept: application/json",
    "--header", "Content-Type: application/json",
    f"{misp_url}/feeds",
    "-o", "feeds.json"
]

try:
    subprocess.run(curl_command, check=True)
except subprocess.CalledProcessError as e:
    print(f"Error al ejecutar curl: {e}")

file_path = 'feeds.json'

enabled_feed_urls = []
feed_ids = []
with open(file_path, 'r') as file:
    data = json.load(file)
    if isinstance(data, list):
        for item in data:
            feed = item.get("Feed")
            if feed and feed.get("enabled"):
                enabled_feed_urls.append(feed.get('url'))
                feed_id = feed.get("id")
                if feed_id:
                    feed_ids.append(feed_id)

os.remove(file_path)

url_file = 'url.txt'
with open(url_file, 'w') as url_out:
    url_out.write("")

for url in enabled_feed_urls:
    try:
        response = requests.get(url)
        if response.status_code == 200:
            if url.endswith('txt') or url.endswith('csv'):
                archivo_salida = f"contenido_{url.split('/')[-1]}"
                with open(archivo_salida, 'w') as f:
                    f.write(response.text)
                with open(archivo_salida, 'r') as f:
                    contenido = f.read()
                urls = re.findall(r'https?://[^\s,]+', contenido)
                with open(url_file, 'a') as url_out:
                    if urls:
                        for u in urls:
                            url_out.write(u + '\n')
                if os.path.exists(archivo_salida):
                    os.remove(archivo_salida)
            
        else:
            print(f"Error al acceder a la URL {url}: Código HTTP {response.status_code}")
    except Exception as e:
        print("Ocurrió un error:", e)
