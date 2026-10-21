#!/bin/bash
dnf install -y httpd
systemctl enable --now httpd
echo "<h1>Hello from $(hostname -f) - ${environment}</h1>" > /var/www/html/index.html
