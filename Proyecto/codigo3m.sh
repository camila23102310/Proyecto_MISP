#!/bin/bash
env_file="misp_vars.env"
if [ -f "$env_file" ]; then
	while IFS= read -r line; do
		line=$(echo "$line" | xargs)
		if [[ "$line" == *=* ]]; then
			key=$(echo "$line" | cut -d '=' -f 1)
			value=$(echo "$line" | cut -d '=' -f 2-)
			export "$key"="$value"
		fi
	done < "$env_file"
	#echo "misp_url: $misp_url"
	#echo "misp_key: $misp_key"
else
	echo "El archivo $env_file no existe."
fi
output="domains7.csv"

> "$output"
python3 500.py -o $output -s 30d -A 2

if [ -f "$output" ]; then
	output_file="atributos.txt"
	> "$output_file"
	zone_file="/etc/bind/db.rpz.local"
	#echo "Leyendo el archivo $output..."
	while IFS= read -r line; do
		line=$(echo "$line" | tr -d '\r')
		line=$(echo "$line" | xargs)
		second_column=$(echo "$line" | awk -F',' '{print $2}')
		third_column=$(echo "$line" | awk -F',' '{print $3}')
		if [[ "$second_column" =~ ^(domain|hostname)$ ]]; then
			echo "$third_column    IN CNAME ." >> "$output_file"
		elif [[ "$second_column" =~ ^(url|uri)$ ]]; then
			domain=$(echo "$third_column" | sed 's/^https\?:\/\///' | sed 's/\/.*//')  # Extrae el dominio de la URL
			echo "$domain    IN CNAME ." >> "$output_file"
		
		else
			echo "'$third_column' no es un valor válido"
		fi	
	done < "$output"
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
	echo "Actualizacion del archivo RPZ completada"
	rm -f "$output" "$output_file"
fi
