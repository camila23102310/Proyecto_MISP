import pymisp
from pymisp import PyMISP
from datetime import datetime, timedelta
import urllib3
import argparse
import csv
import os

# Desactiva advertencias SSL (solo para entornos de prueba)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# === ARGUMENTOS ===
parser = argparse.ArgumentParser(description="Buscar eventos en MISP y extraer dominios.")
parser.add_argument("-s", "--since", required=True, help="Tiempo desde el cual buscar eventos (ej. 7d, 1m)")
parser.add_argument("-A", "--analysis", type=int, default=0, help="Nivel de análisis (0=Inicial, 1=En proceso, 2=Final)")
parser.add_argument("-T", "--threat", type=int, default=3, help="Nivel de amenaza máximo permitido (1=Alto, 2=Medio, 3=Bajo)")
parser.add_argument("-o", "--output", default="salida.csv", help="Nombre del archivo de salida")
args = parser.parse_args()
# === FUNCIONES ===
def parse_since(since):
    if since.endswith("m"):
        months = int(since[:-1])
        date = datetime.now() - timedelta(days=months * 30)
    elif since.endswith("d"):
        days = int(since[:-1])
        date = datetime.now() - timedelta(days=days)
    else:
        raise ValueError("Parámetro 'since' inválido. Usa formato 7d o 1m.")
    return date.strftime('%Y-%m-%d')

# === CARGAR VARIABLES DE ENTORNO ===
misp_url = os.getenv("misp_url")
misp_key = os.getenv("misp_key")
if not misp_url or not misp_key:
    print("Error: misp_url o misp_key no están definidos en el entorno.")
    exit(1)
# === CONEXIÓN MISP ===
misp = PyMISP(misp_url, misp_key, False, "json")
try:
    user_info = misp.get_user()
    print("Conectado correctamente como:", user_info['User']['email'])
except Exception as e:
    print("Error de conexión:", e)
    exit()

# === BÚSQUEDA DE EVENTOS ===
from_date = parse_since(args.since)
print(f"Buscando eventos desde: {from_date}")

try:
    result = misp.search(
        controller='events',
        date_from=from_date,
        pythonify=True,
        limit=50000
    )
    if not result:
        print("No se encontraron eventos.")
        exit()

    filtered = []

    for event in result:
        # Filtro más permisivo: se aplican por separado
        if event.threat_level_id > args.threat:
            continue
        if event.analysis < args.analysis:
            continue
        filtered.append(event)

    if not filtered:
        print("No hay eventos que cumplan con los filtros.")
        exit()

    # === EXPORTAR DOMINIOS ===
    with open(args.output, "w", newline="") as f:
        writer = csv.writer(f)
        #writer.writerow(["id", "tipo", "valor"])
        for event in filtered:
            for attr in event.attributes:
                if attr.category in ["Network activity", "Payload delivery"] and attr.type in ["domain", "hostname", "url", "uri"]:
                    writer.writerow([event.id, attr.type, attr.value])
            for obj in event.objects:
                if obj.get("meta-category") in ["network", "payload-delivery"]:
                    for attr in obj.get("Attribute", []):
                        if attr.get("type") in ["domain", "hostname", "url", "uri"]:
                            writer.writerow([event.id, attr["type"], attr["value"]])
    print(f"Se exportaron {args.output} con los atributos extraídos.")
except Exception as e:
    print("Error durante la búsqueda o exportación:", e)
    exit(1)
