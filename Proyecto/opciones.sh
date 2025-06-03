#!/bin/bash

echo "¿Deseas iniciar el programa? (s/n): "
read -r respuesta
if [[ $respuesta == "s" || $respuesta == "S" ]]; then
    directorio_principal=$(pwd)
    echo "¿Ya has colocado tu clave? (s/n): "
    read -r clave_colocada
    if [[ $clave_colocada != "s" && $clave_colocada != "S" ]]; then
        if [ -f "$(pwd)/entrada.sh" ]; then
            bash "$(pwd)/entrada.sh"
        else
            echo "El archivo entrada.sh no existe en la carpeta."
        fi
    fi
	
    mostrar_menu() {
        echo "Selecciona una opción:"
        echo "1) Extraer desde eventos"
        echo "2) Extraer desde feeds"
        echo "3) Automatizar la extracción de eventos"
        echo "4) Automatizar la extracción desde feeds"
        echo "5) Borrar o agregar dominio"
        echo "6) Salir"
        echo -n "Elige una opción:"
    }

    while true; do
        mostrar_menu
        read -r opcion

        case $opcion in
            1)
                echo "Has seleccionado 'Extraer desde eventos'."
                if [ -f "$(pwd)/codigo2.sh" ]; then
                    echo "Ejecutando"
                    bash codigo2.sh
                else
                    echo "El archivo codigo2.sh no existe en la carpeta."
                fi
                ;;
            2)
                echo "Has seleccionado 'Extraer desde feeds'."
                if [ -f "$(pwd)/feeds.sh" ]; then
                    echo "Ejecutando "
                    bash feeds.sh
                else
                    echo "El archivo feeds.sh no existe en $(pwd)."
                fi
                ;;
		
		
            3)
                echo "Has seleccionado 'Automatizar extracción de eventos'."
                
                # Preguntar la hora al usuario siempre
                echo "¿A qué hora deseas que el código se ejecute automáticamente? (formato 24h, ej. 14:00): "
                read -r hora_ejecucion
		hora=$(echo "$hora_ejecucion" | cut -d':' -f1)
		minuto=$(echo "$hora_ejecucion" | cut -d':' -f2)
                # Verificar si es la primera ejecución
                archivo_control="primera_ejecucion_eventos.txt"
                if [ ! -f "$archivo_control" ]; then
                    # Es la primera ejecución automatizada
                    echo "Es la primera extracción automatizada de eventos."
                    # Configurar cron para la primera extracción con parámetros '-s 3m -A 2 -T ""'
                    echo "$minuto $hora * * * /home/camila/Projecto/codigo3m.sh" | crontab -
                    echo "La extracción automatizada de eventos se ejecutará todos los días a las $hora_ejecucion con parámetros '-s 3m -A 2 -T'."
                    # Crear archivo de control para futuras ejecuciones
                    touch "$archivo_control"
                else
                    # Ya no es la primera ejecución, se actualiza el cron con los nuevos parámetros
                    echo "Ya se ha configurado una extracción automatizada previamente."
                    # Configurar cron para las ejecuciones posteriores con parámetros '-s 1d -A 2 -T 2'
                    echo "$minuto $hora * * * /home/camila/Projecto/codigo1d.sh" | crontab -
                    echo "La extracción automatizada de eventos se ejecutará todos los días a las $hora_ejecucion con parámetros '-s 1d -A 2 -T 2'."
                fi
                ;;
            4)
                echo "Has seleccionado 'Automatizar extracción desde feeds'."
                echo "¿A qué hora deseas que se ejecute automáticamente 'feeds.sh'? (formato 24h, ej. 14:00): "
                read -r hora_ejecucion
                hora=$(echo "$hora_ejecucion" | cut -d':' -f1)
		minuto=$(echo "$hora_ejecucion" | cut -d':' -f2)

                echo "$minuto $hora * * * /home/camila/Projecto/feeds.sh" | crontab -

                echo "La extracción desde feeds se ejecutará todos los días a las $hora_ejecucion."
                ;;
            5)
                echo "Has seleccionado 'Borrar agregar dominio'."
                if [ -f "$(pwd)/Borrar_agregar.sh" ]; then
                    #echo "Ejecutando "
                    bash Borrar_agregar.sh
                else
                    echo "El archivo feeds.sh no existe en $(pwd)."
                fi
                ;;            	
            6)
                echo "Saliendo del programa."
                exit 0
                ;;
            *)
                echo "Opción no válida, por favor intenta de nuevo."
                ;;
        esac
    done
else
    echo "No se iniciará el programa. Saliendo."
    exit 0
fi
