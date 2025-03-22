#!/bin/bash

echo "=== Installation propre de Pterodactyl Panel + Wings + PhpMyAdmin ==="

# 1. Mise à jour du système
sudo apt update && sudo apt upgrade -y

# 2. Installation des paquets requis
sudo apt install -y nginx mariadb-server php php-cli php-mysql php-mbstring php-xml php-bcmath php-curl php-zip php-gd php-fpm unzip curl tar redis-server npm nodejs composer git ufw

# 3. Configuration de la base de données
echo "[Étape 1/7] Configuration de MariaDB..."
sudo mysql -e "CREATE DATABASE panel;"
sudo mysql -e "CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY 'StrongPanelDBPassword';"
sudo mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 4. Téléchargement du Panel Pterodactyl
echo "[Étape 2/7] Installation du Panel Pterodactyl..."
cd /var/www/
sudo mkdir pterodactyl && cd pterodactyl
sudo curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
sudo tar -xzvf panel.tar.gz && rm panel.tar.gz

# 5. Installation des dépendances PHP
composer install --no-dev --optimize-autoloader

# 6. Configuration du Panel
cp .env.example .env
php artisan key:generate --force

# Configuration du fichier .env automatiquement
sed -i "s/DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=panel/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=ptero/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=StrongPanelDBPassword/" .env

php artisan migrate --seed --force

# Création d’un compte admin personnalisé
php artisan p:user:make --email=admin@example.com --username=admin --name-first=Admin --name-last=User --password="Yacine09212011$" --admin=1

# Permissions
chown -R www-data:www-data /var/www/pterodactyl/*
chmod -R 755 /var/www/pterodactyl/storage/*

# 7. Configuration de Nginx pour Panel
echo "[Étape 3/7] Configuration de Nginx pour le Panel..."
cat <<EOF | sudo tee /etc/nginx/sites-available/pterodactyl.conf
server {
    listen 80;
    server_name 108.61.177.138;

    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.access.log;
    error_log /var/log/nginx/pterodactyl.error.log error;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# 8. Installation de Wings
echo "[Étape 4/7] Installation de Wings..."
curl -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x /usr/local/bin/wings

cat <<EOF | sudo tee /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wings
sudo systemctl start wings

# 9. Installation de PhpMyAdmin proprement
echo "[Étape 5/7] Installation de PhpMyAdmin..."
sudo apt install phpmyadmin -y

# Lier PhpMyAdmin dans Nginx
echo "[Étape 6/7] Configuration Nginx pour PhpMyAdmin..."
cat <<EOF | sudo tee /etc/nginx/sites-available/phpmyadmin.conf
server {
    listen 80;
    server_name 108.61.177.138;

    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    access_log /var/log/nginx/phpmyadmin.access.log;
    error_log /var/log/nginx/phpmyadmin.error.log;

    location /phpmyadmin {
        root /usr/share/;
        index index.php;
        location ~ ^/phpmyadmin/(.+\.php)\$ {
            try_files \$uri =404;
            root /usr/share/;
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
        location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))\$ {
            root /usr/share/;
        }
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 10. Affichage des infos de fin
echo "[Étape 7/7] ✅ Installation terminée avec succès."
echo "------------------------------------------------------"
echo "Panel Pterodactyl  : http://108.61.177.138"
echo "PhpMyAdmin         : http://108.61.177.138/phpmyadmin"
echo "Utilisateur admin  : admin"
echo "Mot de passe admin : Yacine09212011$"
echo "------------------------------------------------------"
echo "💡 Vous pouvez ajouter PhpMyAdmin dans le panel via :"
echo " > Paramètres -> Liens rapides ou Documentation interne."
