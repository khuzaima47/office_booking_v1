#!/usr/bin/fish

function psql
    docker compose exec -u postgres db psql
end

function phx
    . (sed 's/^/export /' .env.dev | psub) # set env vars from .env.dev
    cd ./logis_app
    iex -S mix phx.server
end

function deploy_all
    rclone -P sync ./ dov:/home/ubuntu/logi/ \
        --filter "- __pycache__/**" \
        --filter "- .idea/**" \
        --filter "- .vscode/**" \
        --filter "+ /caddy/**" \
        --filter "+ /cscripts/**" \
        --filter "+ /db/**" \
        --filter "+ /static_files/**" \
        --filter "+ /easyocr/**" \
        --filter "+ /.env.prod" \
        --filter "+ /docker-compose-prod.yml" \
        --filter "+ /tasks.fish" \
        --filter "- **"
    deploy_flask
    deploy_logi
end

function deploy_flask
    rclone -P sync flask_app/ dov:/home/ubuntu/logi/flask_app/ \
        --filter "- __pycache__/**" \
        --filter "- .idea/**" \
        --filter "- .vscode/**" \
        --filter "+ /app/**" \
        --filter "+ /other/**" \
        --filter "+ /templates/**" \
        --filter "+ /Dockerfile" \
        --filter "+ /init.sh" \
        --filter "+ /poetry.lock" \
        --filter "+ /pyproject.toml" \
        --filter "+ /wait-for-it.sh" \
        --filter "- **"
end

function deploy_logi
    rclone -P sync logis_app/ dov:/home/ubuntu/logi/logis_app/ \
        --filter "- .idea/**" \
        --filter "- .vscode/**" \
        --filter "- _build/**" \
        --filter "- /deps/**" \
        --filter "- /assets/**" \
        --filter "+ /config/**" \
        --filter "+ /lib/**" \
        --filter "+ /Dockerfile" \
        --filter "+ /mix.exs" \
        --filter "+ /mix.lock" \
        --filter "+ /wait-for-it.sh" \
        --filter "- **"
end

if type -q $argv[1]
    $argv[1]
else
    echo "Unknown function" "'$argv[1]'"
    echo "Available functions:"
    list_functions
end

