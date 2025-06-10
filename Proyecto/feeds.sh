#!/bin/bash

echo "Ejecutando extraer_feed.py..."
python3 extraer_feed.py || { echo "Error al ejecutar extraer_feed.py. Abortando."; exit 1; }

output="url.txt"


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

    output_file="atributos2.txt"
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

    head -n "$lines_from_output" "$output" | \
        sed -E 's~https?://~~' | \
        cut -d/ -f1 | \
        sed -E 's/^www\.//' | \
        sed -E 's/:.*//' | \
        sort -u | \
        awk '{print $1 "    IN CNAME ."}' > "$output_file"
    echo "Extracción terminada. Resultados en $output_file"  
    
    total_lines=$(wc -l < "$output_file")
    echo "Se detectaron $total_lines dominios/URLs únicos en atributos.txt."
    before=$(cksum "$zone_file")

    # Cargar whitelist en memoria
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

