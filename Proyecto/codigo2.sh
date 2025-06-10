#!/usr/bin/bash
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
python3 eventos.py -o "$output" -s "$since_value" $A_param $T_param
#echo "Ejecutando: python3 bin/500.py -o "$output" -s "$since_value" $A_param $T_param"
if [[ ! -s "$output" ]]; then
    echo "El archivo $output está vacío. No se obtuvieron resultados desde MISP."
    exit 1
fi
load_whitelist() {
    declare -A wl_domains=()
    if [ ! -f /etc/bind/whitelist.txt ]; then
        echo "No existe el archivo whitelist.txt"
        return 0
    fi
    while IFS= read -r wl_domain; do
        wl_domain=$(echo "$wl_domain" | tr -d ' \t\r\n')
        wl_domain="${wl_domain#www.}"
        if [[ "$wl_domain" == google.* ]]; then
            wl_domain="${wl_domain%%.*}"
        fi
        wl_domains["$wl_domain"]=1
    done < /etc/bind/whitelist.txt

    declare -gA whitelist_domains
    whitelist_domains=()
    for key in "${!wl_domains[@]}"; do
        whitelist_domains["$key"]=1
    done
}

# Función para verificar si un dominio está en la whitelist
is_whitelisted() {
    local domain="$1"
    local clean_domain="${domain#www.}"
    local base_domain="$clean_domain"
    if [[ "$clean_domain" == google.* ]]; then
        base_domain="${clean_domain%%.*}"
    fi
    [[ -n "${whitelist_domains[$base_domain]}" ]]
}

# Llamar a load_whitelist antes de procesar
load_whitelist

# Ahora sí, procesas el output con la whitelist cargada
if [ -f "$output" ]; then

    output_file="atributos.txt"
    > "$output_file"
    zone_file="/etc/bind/db.rpz.local"

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
        # Limpiar espacios en las columnas 2 y 3
        gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $2)
        gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $3)
        
        col2 = tolower($2)
        domain = $3

        # Si es URL o URI, quitar protocolo y extraer dominio base
        if (col2 ~ /url|uri/) {
            gsub(/^https?:\/\//, "", domain)
            split(domain, parts, "/")
            domain = parts[1]

            # Si tiene puerto, eliminarlo
            split(domain, domain_parts, ":")
            domain = domain_parts[1]
        }

        # Si es domain o hostname, también eliminar puerto si existe
        if (col2 ~ /domain|hostname/) {
            split(domain, domain_parts2, ":")
            domain = domain_parts2[1]
        }

        # Ignorar si es IP (con formato x.x.x.x)
        if (domain ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
            next
        }

        # Imprimir línea con formato RPZ
        print domain "    IN CNAME ."
    }
    ' | sort -u > "$output_file"

    echo "Extracción terminada. Resultados en $output_file"

    total_lines=$(wc -l < "$output_file")
    echo "Se detectaron $total_lines dominios/URLs únicos en atributos.txt."

    before=$(cksum "$zone_file")

    declare -A whitelist_domains
    load_whitelist

    # Cargar dominios existentes en zona en memoria
    declare -A existing_domains
    while IFS= read -r line; do
        domain=$(echo "$line" | awk '{print $1}')
        if [[ -n "$domain" ]]; then
            existing_domains["$domain"]=1
        fi
    done < "$zone_file"

    # Preparar array para nuevas entradas
    declare -a new_entries=()

    while IFS= read -r line; do
        domain_name=$(echo "$line" | awk '{print $1}')
        if [[ -z "$domain_name" || "$domain_name" != *.* ]]; then
            echo "[INFO] Dominio inválido o vacío: '$domain_name'. Se omite."
            continue
        fi

        if is_whitelisted "$domain_name"; then
            echo "[INFO] '$domain_name' está en la whitelist. Se omite."
            continue
        fi

        if [[ -z "${existing_domains[$domain_name]}" ]]; then
            new_entries+=("$line")
            existing_domains["$domain_name"]=1
        fi
    done < "$output_file"

    if [[ ${#new_entries[@]} -gt 0 ]]; then
        printf "%s\n" "${new_entries[@]}" >> "$zone_file"
    else
        echo "No hay nuevas entradas para añadir."
    fi

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

