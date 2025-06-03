# Proyecto_MISP
Este proyecto busca integraR el servidor BIND con la plataforma MISP para automatizar la actualización de las RPZ, con el propósito de bloquear en tiempo real dominios y FQDNs maliciosos, mejorando así la seguridad cibernética y el rendimiento del servicio DNS en micro, pequeñas y medianas empresas.
Aquí tienes el resumen en español, listo para copiar y pegar en tu README de GitHub:

Servidor DNS BIND9 con RPZ y Página de Bloqueo Flask
Este repositorio describe la configuración de un servidor DNS BIND9 en Ubuntu (versiones 22.04 y 24.04), incluyendo Zonas de Política de Respuesta (RPZ) para bloquear dominios maliciosos, una página de bloqueo personalizada basada en Flask y Nginx para hacer de proxy.

Tabla de Contenidos
Configuración de Ubuntu
Guest Additions
Instalación y Configuración de BIND9
Configuración de Red (Netplan)
Captura de Paquetes
Carpetas Compartidas
Integración con MISP
Zona de Política de Respuesta (RPZ)
Añadir un Dominio Personalizado para Bloqueo
Página de Bloqueo Flask
Configuración del Proxy Nginx
Integración con Mininet
Optimización del Rendimiento
Configuración de Ubuntu
Probado en Ubuntu 22.04 y 24.04 con las siguientes especificaciones:

Memoria Base: 6000MB 
4 Procesadores 
Disco de 60GB 
Notas de Instalación:

22.04: Instalación normal, descargar actualizaciones, borrar disco.
24.04: Usar conexión por cable, instalar Ubuntu, instalación iterativa, selección predeterminada, borrar disco.
Guest Additions
Para instalar Guest Additions para una mejor integración de la VM:

Bash

sudo apt update [cite: 1]
sudo apt install linux-headers-$(uname -r) build-essential dkms [cite: 1]
# Luego, desde el menú de VirtualBox: Dispositivos -> Insertar Imagen de CD de las Guest Additions [cite: 1]
# Navega al CD-ROM montado en la terminal y ejecuta:
./autorun.sh [cite: 1]
sudo reboot [cite: 1]
Instalación y Configuración de BIND9
Instalar BIND9 y vim:

Bash

sudo apt update && sudo apt install bind9 -y [cite: 1]
sudo apt-get install vim [cite: 1]
Configurar named.conf.options:

Bash

cd /etc/bind [cite: 1]
sudo vim named.conf.options [cite: 1]
Añade o modifica lo siguiente dentro del bloque options:

options {
    querylog yes; [cite: 5]
    directory "/var/cache/bind"; [cite: 5]
    recursion yes; [cite: 5]
    allow-recursion { localhost; 192.168.0.0/24; }; [cite: 5]
    dnssec-validation auto; [cite: 11]
    listen-on { any; }; [cite: 11]
    response-policy {
        zone "rpz.local"; [cite: 12]
    };
};
Verificar configuración:

Bash

sudo named-checkconf [cite: 1]
Configuración de Red (Netplan)
Deshabilitar systemd-resolved y configurar Netplan:

Bash

sudo systemctl disable --now systemd-resolved [cite: 2]
cd /etc/netplan/ [cite: 2]
sudo vim 01-network-manager-all.yaml [cite: 2]
Ejemplo de configuración de Netplan (01-network-manager-all.yaml):

YAML

network:
  version: 2 [cite: 2]
  ethernets:
    enp0s3:
      addresses:
      - 192.168.0.164/24 [cite: 2]
      nameservers:
        addresses:
        - 127.0.0.1  # Apunta a tu servidor BIND [cite: 2]
      routes:
      -   to: default [cite: 2]
          via: 192.168.0.1 [cite: 2]
Aplicar cambios de Netplan:

Bash

sudo netplan apply [cite: 2]
Eliminar resolv.conf y volver a crearlo para que apunte a localhost:

Bash

sudo rm resolv.conf [cite: 2] # El archivo original se menciona como /etc/resolv.conf. [cite: 3]
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolv.conf'
Captura de Paquetes
Usa tcpdump para capturar paquetes DNS:

Bash

tcpdump -i enp0s3 -w captura.pcap [cite: 3]
sudo chmod 666 captura.pcap [cite: 3]
sudo tcpdump -i enp0s3 port 53 [cite: 3]
Carpetas Compartidas
Para configurar carpetas compartidas entre Ubuntu y Windows (asumiendo VirtualBox):

Crea una carpeta en Ubuntu (ej. ~/Escritorio/windows).
Crea una carpeta en Windows (ej. linux).
En VirtualBox: Configuración de la VM -> Carpetas Compartidas -> Añadir.
Busca la carpeta creada en Windows.
Establece el "Punto de montaje" a /home/camila/Escritorio/windows (o tu ruta de carpeta en Ubuntu).
Marca "Automontar" y "Hacer permanente".
Añade tu usuario al grupo vboxsf: sudo adduser camila vboxsf 
Reinicia.
Integración con MISP
Instalación:

Bash

sudo apt-get update -y && sudo apt-get upgrade -y [cite: 3]
sudo apt-get install mysql-client -y [cite: 3]
wget https://raw.githubusercontent.com/MISP/MISP/2.4/INSTALL/INSTALL.sh [cite: 3]
chmod +x INSTALL.sh [cite: 3]
./INSTALL.sh -A [cite: 3]
Reglas de Firewall para MISP:

Bash

sudo ufw allow 80/tcp [cite: 3]
sudo ufw allow 443/tcp [cite: 3]
Accede a MISP en https://<ip de tu instancia misp>/users/login (ej. https://192.168.0.164/users/login).
Credenciales por defecto: Usuario: admin@admin.test, Contraseña: admin.

Uso de MISP-Extractor (Ejemplos):

Bash

python3 bin/MISP-Extractor.py -u https://test1.waltervalderrama.co -k 0jMhQpgHsza8DEJsIwsiLHGo4mXVglV2PzeCVDg1 -d domains -o dominios_maliciosos.csv [cite: 4]
python3 bin/MISP-Extractor.py -u https://192.168.1.164 -k 0jMhQpgHsza8DEJsIwsiLHGo4mXVglV2PzeCVDg1 -d domains -o dominios_maliciosos.csv [cite: 4]
sudo misp_url=https://192.168.1.164 misp_key=0jMhQpgHsza8DEJsIwsiLHGo4mXVglV2PzeCVDg1 python3 500.py -s 10d -A 2 -T 3 [cite: 4]
python3 bin/MISP-Extractor2.py -u https://valderramahouse.ddns.net:5555 -k 2tRsqT8fKCXEFu52zZ7f8vm060bpe3wDJ4nOYZSw -d domains -s 30d [cite: 4]
Para encontrar MISP-Extractor.py: find / -name "MISP-Extractor.py" 2>/dev/null 

Zona de Política de Respuesta (RPZ)
Configura RPZ en named.conf.local:

Bash

sudo vim /etc/bind/named.conf.local [cite: 12]
Añade la siguiente definición de zona:

zone "rpz.local" {
    type master; [cite: 13]
    file "/etc/bind/db.rpz.local"; [cite: 13]
    allow-query { localhost; }; [cite: 13]
    allow-transfer { localhost; }; [cite: 13]
};
Crea el archivo de base de datos RPZ:

Bash

sudo cp /etc/bind/db.empty /etc/bind/db.rpz.local [cite: 13]
sudo vim /etc/bind/db.rpz.local [cite: 13]
Edita db.rpz.local para incluir dominios bloqueados. El CNAME . indica bloqueo (NXDOMAIN):

; BIND reverse data file for empty rfc1918 zone
; [cite: 14] DO NOT EDIT THIS FILE - it is used for multiple zones.
; [cite: 15] Instead, copy it, edit named.conf, and use that copy.
; [cite: 16] $TTL    86400
@       IN      SOA     localhost. root.localhost. ( [cite: 17]
                              1         ; Serial [cite: 17]
                         604800         ; Refresh [cite: 18]
                           86400         ; Retry [cite: 18]
                        2419200         ; Expire [cite: 18]
                          86400 )       ; [cite: 19] Negative Cache TTL
;
@       IN      NS      localhost. [cite: 20]
doubleclick.net      CNAME   . [cite: 21]
pornhub.com          CNAME   . [cite: 21]
$ORIGIN rpz.example.com. [cite: 22]
malicious1.org          CNAME . [cite: 22]
Configura el registro de RPZ en named.conf:

Bash

sudo vim /etc/bind/named.conf [cite: 23]
Añade el bloque de registro:

logging {
    channel rpzlog {
        file "/var/log/named/rpz.log" versions unlimited size 100m; [cite: 24]
        print-time yes; [cite: 24]
        print-category yes; [cite: 24]
        print-severity yes; [cite: 24]
        severity info; [cite: 24]
    };
    category rpz { rpzlog; }; [cite: 24]
};
Crea el directorio de logs y establece permisos:

Bash

sudo mkdir /var/log/named/ [cite: 25]
sudo chown bind:bind /var/log/named/ -R [cite: 25]
Verifica y reinicia BIND9:

Bash

sudo named-checkconf [cite: 25]
sudo named-checkzone rpz.local /etc/bind/db.rpz.local # El comando original usa 'rpz', pero la zona es 'rpz.local'
sudo systemctl restart bind9 [cite: 25]
Para habilitar solo IPv4 para BIND (opcional):

Bash

sudo nano /etc/default/named [cite: 26]
OPTIONS="-u bind -4" [cite: 26]
Añadir un Dominio Personalizado para Bloqueo
Para redirigir un dominio a una IP específica (ej. tu página de bloqueo):

Bash

sudo vim /etc/bind/named.conf.local [cite: 26]
Añade la definición de la zona:

zone "bloqueo.com" {
    type master; [cite: 26]
    file "/etc/bind/zones/db.bloqueo.com"; [cite: 26]

};
Crea el directorio y el archivo de la zona:

Bash

sudo mkdir /etc/bind/zones [cite: 26]
sudo vim /etc/bind/zones/db.bloqueo.com [cite: 26]
Rellena db.bloqueo.com:

;
$TTL    604800 [cite: 27]
@       IN      SOA     bloqueo.com. root.bloqueo.com. ( [cite: 27]
                             17777777         ; Serial [cite: 27]
                         604800         ; Refresh [cite: 28]
                           86400         ; Retry [cite: 28]
                        2419200         ; Expire [cite: 28]
                         604800 )       ; [cite: 29] Negative Cache TTL

;
@               IN      NS      bloqueo.com. [cite: 30]
;
@               IN      A       192.168.1.16 [cite: 31]

;
www             IN      A       192.168.1.16 [cite: 32]
Verifica y reinicia BIND:

Bash

sudo named-checkconf [cite: 32]
sudo named-checkzone bloqueo.com  /etc/bind/zones/db.bloqueo.com [cite: 32]
sudo systemctl restart named [cite: 32]
Página de Bloqueo Flask
Esta aplicación Flask sirve una página de bloqueo para dominios bloqueados y permite la inclusión temporal en una lista blanca.

Instalación:

Bash

sudo pip3 install flask [cite: 33]
mkdir ~/pagina-bloqueo [cite: 33]
cd ~/pagina-bloqueo [cite: 33]
vim app.py [cite: 33]
Contenido de app.py:
(El código app.py proporcionado es extenso. Las funcionalidades clave incluyen: redirigir hosts que no son Flask a la página de bloqueo, mostrar el dominio bloqueado, y ofrecer una opción de "Continuar esta vez". El endpoint /continuar gestiona la adición de dominios a una lista blanca temporal, su eliminación de RPZ, la actualización del número de serie SOA de RPZ y la recarga de BIND.)




Para ejecutar la aplicación Flask:

Bash

python3 app.py
La aplicación se ejecutará en http://0.0.0.0:5000.

Configuración del Proxy Nginx
Nginx se utiliza para proxyar las solicitudes a la aplicación Flask, manejando tanto HTTP como HTTPS.

Redirección HTTP a Flask:

Bash

sudo vim /etc/nginx/sites-available/default_http_redirect [cite: 48]
Nginx

server {
    listen 80 default_server; [cite: 49]
    server_name _; [cite: 49]

    location / {
        proxy_pass http://127.0.0.1:5000; [cite: 49]
        proxy_set_header Host $host; [cite: 50]
        proxy_set_header X-Real-IP $remote_addr; [cite: 50]
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; [cite: 50]
        proxy_set_header X-Forwarded-Proto $scheme; [cite: 50]
    }
}
Configuración HTTPS (con Certbot):
Obtén el certificado SSL (ej. con el desafío DNS de Certbot):

Bash

sudo certbot certonly --manual --preferred-challenges dns -d error.waltervalderrama.co [cite: 48]
Añade el bloque del servidor HTTPS:

Nginx

server {
    listen 443 ssl http2; [cite: 51]
    server_name error.waltervalderrama.co; [cite: 51]
    ssl_certificate /ruta/a/fullchain.pem; # Actualiza con la ruta de tu certificado [cite: 51]
    ssl_certificate_key /ruta/a/privkey.pem; # Actualiza con la ruta de tu clave [cite: 51]

    location / {
        proxy_pass http://127.0.0.1:5000; [cite: 52]
        proxy_set_header Host $host; [cite: 52]
        proxy_set_header X-Real-IP $remote_addr; [cite: 52]
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; [cite: 52]
        proxy_set_header X-Forwarded-Proto $scheme; [cite: 52]
    }
}
Habilita la configuración de Nginx y recarga:

Bash

sudo ln -s /etc/nginx/sites-available/default_http_redirect /etc/nginx/sites-enabled/ [cite: 52]
sudo nginx -t [cite: 52]
sudo systemctl reload nginx [cite: 52]
Integración con Mininet
Comandos para configurar el reenvío de red y ejecutar scripts de Mininet:

Bash

sudo sysctl -w net.ipv4.ip_forward=1 [cite: 33]
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE [cite: 33]
sudo iptables -t nat -L -n -v [cite: 33]
sudo mn [cite: 33]
sudo python3 oto.py [cite: 33]
sudo ./dns_queries.sh [cite: 33]
Optimización del Rendimiento
Para optimizar el rendimiento de BIND9:

Bash

ulimit -n 65536 [cite: 52]
sudo sysctl -w net.core.rmem_max=16777216 [cite: 52]
sudo sysctl -w net.core.wmem_max=16777216 [cite: 52]
sudo sysctl -w net.core.netdev_max_backlog=5000 [cite: 52]
sudo sysctl -w net.core.somaxconn=1024 [cite: 52]

ulimit -n 65536 && sudo named -u bind [cite: 52]
sudo sysctl -w net.ipv4.udp_mem="65536 87380 16777216" [cite: 52]
sudo sysctl -w net.ipv4.udp_rmem_min=16384 [cite: 52]
sudo sysctl -w net.ipv4.udp_wmem_min=16384 [cite: 52]
Añade estas opciones a named.conf.options:

recursive-clients 10000; [cite: 53]
max-cache-size 216M; [cite: 53]
clients-per-query 100; [cite: 53]
max-clients-per-query 10000; [cite: 53]
