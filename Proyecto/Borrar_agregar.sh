#!/bin/bash

# Archivo RPZ de BIND
zone_file="/etc/bind/db.rpz.local"

# Función para aumentar el número de serie
aumentar_serial() {
    current_serial=$(grep -A 1 'SOA' "$zone_file" | tail -n 1 | awk '{print $1}' | tr -d ';')
    if [[ -z "$current_serial" ]]; then
        echo "Error: No se pudo encontrar el número de serie actual."
        exit 1
    fi
    new_serial=$((current_serial + 1))
    sed -i "s/\([0-9]\+\)[[:space:]]*; Serial/${new_serial} ; Serial/" "$zone_file"
    #echo "Número de serial actualizado: $new_serial"
}

# Preguntar acción
echo "¿Qué deseas hacer con un dominio?"
echo "1. Agregar"
echo "2. Eliminar"
read -rp "Selecciona una opción (1 o 2): " opcion

case "$opcion" in
    1)
        read -rp "Ingresa el dominio que deseas agregar: " dominio
        entrada="$dominio IN CNAME ."
        if grep -qF "$entrada" "$zone_file"; then
            echo "El dominio ya existe en el archivo RPZ."
        else
            echo "$entrada" >> "$zone_file"
            echo "Dominio agregado correctamente."
            aumentar_serial
            sudo rndc reload
        fi
        ;;
    2)
        read -rp "Ingresa el dominio que deseas eliminar (exacto, con mayúsculas o minúsculas): " dominio
        # Validar si existe exactamente esa línea en el archivo (con espacios o tabs entre campos)
        if grep -q "^${dominio}[[:space:]]" "$zone_file"; then
            # Eliminar toda la línea que comience exactamente con ese dominio y termine en CNAME .
            sed -i "/^${dominio}[[:space:]]/d" "$zone_file"
            echo "Dominio eliminado correctamente."
            aumentar_serial
            sudo rndc reload
        else
            echo "El dominio no se encontró en el archivo RPZ."
        fi
        ;;
    *)
        echo "Opción no válida. Saliendo."
        exit 1
        ;;
esac
