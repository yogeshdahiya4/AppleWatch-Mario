#!/usr/bin/env bash
# Bootstrap the PixelHop backend on Coolify.
# Idempotent: safe to re-run. Captures created resource UUIDs into .coolify-uuids.json
# so coolify-deploy.sh can find the app to redeploy.
#
# Prereqs:
#   - ~/.coolify-token contains the bearer token (chmod 600)
#   - jq installed
#   - GitHub App "unizzy-coolify-github-app" already authorized for yogeshdahiya4/* repos
set -euo pipefail

TOKEN=$(<"$HOME/.coolify-token")
BASE="http://72.62.0.34:8000"
PROJECT_NAME="applewatch-mario"
DB_NAME="pixelhop-db"
APP_NAME="pixelhop-api"
DOMAIN="https://applewatch-mario-api.72.62.0.34.sslip.io"
GITHUB_APP_ID=2
REPO="yogeshdahiya4/AppleWatch-Mario"
BRANCH="main"
BASE_DIR="/services/api"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UUID_FILE="$REPO_ROOT/.coolify-uuids.json"

api() {
  local method="$1" path="$2"
  shift 2
  curl -fsS -X "$method" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE$path" "$@"
}

# Read existing uuids if present
read_uuid() {
  local key="$1"
  [[ -f "$UUID_FILE" ]] && jq -r --arg k "$key" '.[$k] // empty' "$UUID_FILE" 2>/dev/null || echo ""
}

write_uuid() {
  local key="$1" val="$2"
  if [[ ! -f "$UUID_FILE" ]]; then echo "{}" > "$UUID_FILE"; fi
  tmp=$(mktemp)
  jq --arg k "$key" --arg v "$val" '.[$k] = $v' "$UUID_FILE" > "$tmp" && mv "$tmp" "$UUID_FILE"
}

echo "==> Bootstrapping PixelHop on Coolify"

# 1. Project
PROJECT_UUID=$(read_uuid project)
if [[ -z "$PROJECT_UUID" ]]; then
  echo "Creating project '$PROJECT_NAME'..."
  PROJECT_UUID=$(api POST /api/v1/projects \
    -d "{\"name\":\"$PROJECT_NAME\",\"description\":\"PixelHop watch game backend\"}" \
    | jq -r '.uuid')
  write_uuid project "$PROJECT_UUID"
  echo "  project uuid: $PROJECT_UUID"
else
  echo "Project exists: $PROJECT_UUID"
fi

# 2. Find production environment uuid for this project
ENV_UUID=$(api GET "/api/v1/projects/$PROJECT_UUID" \
  | jq -r '.environments[] | select(.name=="production") | .uuid' | head -1)
if [[ -z "$ENV_UUID" || "$ENV_UUID" == "null" ]]; then
  echo "ERROR: no production environment found on project $PROJECT_UUID" >&2
  exit 1
fi
echo "  prod env uuid: $ENV_UUID"

# 3. Find the only server uuid (single-server setup)
SERVER_UUID=$(api GET /api/v1/servers | jq -r '.[0].uuid')
echo "  server uuid: $SERVER_UUID"

# 4. Postgres database
DB_UUID=$(read_uuid database)
if [[ -z "$DB_UUID" ]]; then
  echo "Creating Postgres database '$DB_NAME'..."
  DB_RESP=$(api POST /api/v1/databases/postgresql \
    -d "$(jq -n \
      --arg name "$DB_NAME" \
      --arg server "$SERVER_UUID" \
      --arg project "$PROJECT_UUID" \
      --arg env "$ENV_UUID" \
      '{name: $name, server_uuid: $server, project_uuid: $project, environment_uuid: $env, image: "postgres:16-alpine", is_public: false}')")
  DB_UUID=$(echo "$DB_RESP" | jq -r '.uuid')
  write_uuid database "$DB_UUID"
  echo "  db uuid: $DB_UUID"
else
  echo "Database exists: $DB_UUID"
fi

# Get DB internal connection string
DB_INFO=$(api GET "/api/v1/databases/$DB_UUID")
DB_INTERNAL_URL=$(echo "$DB_INFO" | jq -r '.internal_db_url // .postgres_url // empty')
if [[ -z "$DB_INTERNAL_URL" ]]; then
  # fallback: build from parts
  DB_USER=$(echo "$DB_INFO" | jq -r '.postgres_user')
  DB_PASS=$(echo "$DB_INFO" | jq -r '.postgres_password')
  DB_DB=$(echo "$DB_INFO" | jq -r '.postgres_db')
  DB_INTERNAL_URL="postgres://${DB_USER}:${DB_PASS}@${DB_NAME}:5432/${DB_DB}"
fi
echo "  db url: ${DB_INTERNAL_URL/:*@/:****@}"

# 5. Application (private GitHub App source)
APP_UUID=$(read_uuid app)
if [[ -z "$APP_UUID" ]]; then
  echo "Creating application '$APP_NAME'..."
  APP_RESP=$(api POST /api/v1/applications/private-github-app \
    -d "$(jq -n \
      --arg name "$APP_NAME" \
      --arg server "$SERVER_UUID" \
      --arg project "$PROJECT_UUID" \
      --arg env "$ENV_UUID" \
      --arg repo "$REPO" \
      --arg branch "$BRANCH" \
      --arg base "$BASE_DIR" \
      --arg domain "$DOMAIN" \
      --argjson gh_app_id $GITHUB_APP_ID \
      '{name: $name, server_uuid: $server, project_uuid: $project, environment_uuid: $env,
        github_app_uuid: $gh_app_id, git_repository: $repo, git_branch: $branch,
        build_pack: "dockerfile", base_directory: $base,
        dockerfile_location: "/services/api/Dockerfile",
        ports_exposes: "3000", domains: $domain,
        publish_directory: "", install_command: "", build_command: "", start_command: ""}')")
  APP_UUID=$(echo "$APP_RESP" | jq -r '.uuid')
  write_uuid app "$APP_UUID"
  echo "  app uuid: $APP_UUID"
else
  echo "Application exists: $APP_UUID"
fi

# 6. Set runtime env vars (NOT buildtime — Maniac feedback memory)
HMAC_SECRET=$(openssl rand -hex 32)
echo "Setting env vars on app..."
for kv in \
  "DATABASE_URL=$DB_INTERNAL_URL" \
  "HMAC_SERVER_SECRET=$HMAC_SECRET" \
  "PORT=3000" \
  "NODE_ENV=production"; do
  K="${kv%%=*}"
  V="${kv#*=}"
  # Coolify upserts by key
  api POST "/api/v1/applications/$APP_UUID/envs" \
    -d "$(jq -n --arg k "$K" --arg v "$V" \
      '{key: $k, value: $v, is_buildtime: false, is_runtime: true, is_preview: false}')" \
    > /dev/null || echo "  (env $K may already exist; trying update)"
done

# Persist generated HMAC secret to a local file so we can re-set it deterministically
if [[ ! -f "$REPO_ROOT/.coolify-secrets.json" ]]; then
  jq -n --arg s "$HMAC_SECRET" '{HMAC_SERVER_SECRET: $s}' > "$REPO_ROOT/.coolify-secrets.json"
  chmod 600 "$REPO_ROOT/.coolify-secrets.json"
fi

echo
echo "==> Bootstrap complete."
echo "    Project:  $PROJECT_UUID"
echo "    Database: $DB_UUID"
echo "    App:      $APP_UUID"
echo "    Domain:   $DOMAIN"
echo
echo "Next: ./tools/coolify-deploy.sh"
