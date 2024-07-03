# Use a imagem oficial do Nginx
FROM nginx

# Copie os arquivos do certificado auto-assinado para o diretório do Nginx
COPY cert.pem /etc/nginx/cert.pem
COPY cert.key /etc/nginx/cert.key

# Copie o arquivo de configuração do Nginx para habilitar o suporte à HTTPS
COPY nginx.conf /etc/nginx/nginx.conf

# Exponha a porta 443 para acessar o Nginx via HTTPS
EXPOSE 443

# Comando padrão para iniciar o Nginx
CMD ["nginx", "-g", "daemon off;"]