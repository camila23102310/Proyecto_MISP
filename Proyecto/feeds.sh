#!/bin/bash
cd /home/camila/Projecto || exit 1
echo "Ejecutando extraer_feed.py..."
python3 extraer_feed.py

# Verificar si la ejecución del script Python fue exitosa
if [ $? -ne 0 ]; then
	    echo "Error al ejecutar extraer_feed.py. Abortando."
	    exit 1
fi
input_file="url.txt"
zone_file="/etc/bind/db.rpz.local"
output_file="output_file.txt"
> "$output_file"

if [ -s "$input_file" ]; then
	sed -i 's/,/\n/g' "$input_file"
	while IFS= read -r url; do
		if [[ "$url" =~ ^https?://([0-9]{1,3}\.){3}[0-9]{1,3} ]]; then
			:
		elif [[ "$url" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$ ]]; then
			echo "$url  IN CNAME ." >> "$output_file"
		else
			domain=$(echo "$url" | sed 's/^https\?:\/\///' | sed 's/\/.*//')
			echo "$domain  IN CNAME ." >> "$output_file"
		fi
	done < "$input_file"
fi
if [ -s "$output_file" ]; then
	while IFS= read -r line; do
		if ! grep -qF "$line" "$zone_file"; then
			echo "$line" >> "$zone_file"
		fi
	done < "$output_file"
	current_serial=$(grep -A 1 'SOA' "$zone_file" | tail -n 1 | awk '{print $1}' | tr -d ';')
	if [[ -z "$current_serial" ]]; then
		echo "Error: No se pudo encontrar el número de serie actual."
		exit 1
	fi
	new_serial=$((current_serial + 1))
	sed -i "s/\([0-9]\+\)[[:space:]]*; Serial/${new_serial} ; Serial/" "$zone_file"
	#echo "Recargando la zona..."
	sudo rndc reload
	echo "Actualización del archivo RPZ completada"
	rm -f "$output_file" "$input_file"
else
	echo "error"
fi
