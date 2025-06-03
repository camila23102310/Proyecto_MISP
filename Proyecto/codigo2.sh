#!/usr/bin/env bash
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


echo "Introduce el valor para el parámetro '-s' (por ejemplo, 7d o 1m):"
read -r since_value

# Validar si el valor proporcionado tiene formato correcto
if [[ ! "$since_value" =~ ^[0-9]+[dD]$ && ! "$since_value" =~ ^[0-9]+[mM]$ ]]; then
    echo "El valor para -s no es válido. Debe ser en el formato 7d o 1m."
    exit 1
fi

# Preguntar si el usuario quiere proporcionar valores para -A y -T
echo "¿Deseas proporcionar un valor para el parámetro '-A' (Análisis)? [s/n]"
read -r answer_a
if [[ "$answer_a" == "s" || "$answer_a" == "S" ]]; then
    echo "Introduce el valor para el parámetro '-A' (por ejemplo, 0 para Inicial, 1 para Ongoing, 2 para Completado):"
    read -r A_value
    A_param="-A $A_value"
else
    A_param=""
fi

echo "¿Deseas proporcionar un valor para el parámetro '-T' (Nivel de amenaza)? [s/n]"
read -r answer_t
if [[ "$answer_t" == "s" || "$answer_t" == "S" ]]; then
    echo "Introduce el valor para el parámetro '-T' (por ejemplo, 1 para Alto, 2 para Medio, 3 para Bajo, 4 para No definido):"
    read -r T_value
    T_param="-T $T_value"
else
    T_param=""
fi

# Definir archivo de salida
output="resultados.csv"

# Limpiar archivo de salida
> "$output"

# Ejecutar script Python con los parámetros proporcionados por el usuario
python3 500.py -o "$output" -s "$since_value" $A_param $T_param
#echo "Ejecutando: python3 bin/500.py -o "$output" -s "$since_value" $A_param $T_param"
if [[ ! -s "$output" ]]; then
    echo "El archivo $output está vacío. No se obtuvieron resultados desde MISP."
    exit 1
fi

is_whitelisted() {
	local domain="$1"

	if [ ! -f /etc/bind/whitelist.txt ]; then
		return 1
	fi

	# Quitar 'www.' si lo tiene
	local clean_domain="${domain#www.}"

	# Extraer el base_domain para google (sin TLD)
	local base_domain="$clean_domain"
	if [[ "$clean_domain" == google.* ]]; then
		base_domain="${clean_domain%%.*}"  # quitar todo después del primer punto
	fi

	while IFS= read -r wl_domain; do
		wl_domain=$(echo "$wl_domain" | tr -d ' \t\r\n')
		local clean_wl="${wl_domain#www.}"
		local wl_base="$clean_wl"

		if [[ "$clean_wl" == google.* ]]; then
			wl_base="${clean_wl%%.*}"
		fi

		if [[ "$base_domain" == "$wl_base" ]]; then
			return 0
		fi
	done < /etc/bind/whitelist.txt

	return 1
}
if [ -f "$output" ]; then
	output_file="atributos.txt"
	> "$output_file"
	zone_file="/etc/bind/db.rpz.local"
	whitelist="/etc/bind/whitelist.txt"
	
	total_output_lines=$(wc -l < "$output")
	echo "El archivo $output tiene $total_output_lines líneas."
	echo "¿Cuántas líneas quieres procesar desde $output? (Presiona Enter para procesar todas)"
	read -r lines_from_output

	if [[ -z "$lines_from_output" || ! "$lines_from_output" =~ ^[0-9]+$ || "$lines_from_output" -gt "$total_output_lines" ]]; then
		lines_from_output=$total_output_lines
	fi
	echo "Se procesarán $lines_from_output líneas."

	head -n "$lines_from_output" "$output" | awk -F',' '
    	{
        	# Limpiar espacios al inicio y final
        	gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $2)
        	gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $3)
        	col2=tolower($2)
        	if (col2 ~ /domain|hostname/) {
            		print $3 "    IN CNAME ."
        	} else if (col2 ~ /url|uri/) {
            		gsub(/^https?:\/\//, "", $3)
            		split($3, parts, "/")
            		print parts[1] "    IN CNAME ."
        	}
        	# else {
        	#     print "Valor inválido: " $3 > "/dev/stderr"
        	# }
    	}' | sort -u > "$output_file"

    	echo "Extracción terminada. Resultados en $output_file"  
    
	total_lines=$(wc -l < "$output_file")
	echo "Se detectaron $total_lines dominios/URLs únicos en atributos.txt."
	before=$(cksum "$zone_file")
	declare -A existing_domains
	while IFS= read -r line; do
		domain=$(echo "$line" | awk '{print $1}')
	    # Evitar claves vacías
	    	if [[ -n "$domain" ]]; then
			existing_domains["$domain"]=1
	    	fi
	done < "$zone_file"

	# Leer dominios del archivo temporal de salida
	while IFS= read -r line; do
	    	domain_name=$(echo "$line" | awk '{print $1}')

	    # Validar: no vacío y que tenga al menos un punto (dominio válido)
	    	if [[ -z "$domain_name" || "$domain_name" != *.* ]]; then
			echo "[INFO] Dominio inválido o vacío: '$domain_name'. Se omite."
			continue
	    	fi

	    # Verificar whitelist
	    	if is_whitelisted "$domain_name"; then
			echo "[INFO] '$domain_name' está en la whitelist. Se omite."
			continue
	    	fi

	    # Añadir solo si no existe ya
	    	if [[ -z "${existing_domains[$domain_name]}" ]]; then
			echo "$line" >> "$zone_file"
			existing_domains["$domain_name"]=1
			#echo "[INFO] Añadido: $domain_name"
	    	fi

	done < "$output_file"

	after=$(cksum "$zone_file")

	

	if [[ "$before" != "$after" ]]; then
		current_serial=$(grep -A 1 'SOA' "$zone_file" | tail -n 1 | awk '{print $1}' | tr -d ';')
		if [[ -z "$current_serial" ]]; then
			echo "Error: No se pudo encontrar el número de serie actual."
			exit 1
		fi
		new_serial=$((current_serial + 1))
		sed -i "s/\([0-9]\+\)[[:space:]]*; Serial/${new_serial} ; Serial/" "$zone_file"
		sudo rndc reload
		echo "Zona recargada."
	else
		echo "No hubo cambios en la zona. No se recargó."
	fi

	rm -f "$output" "$output_file"
fi

