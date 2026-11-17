#!/usr/bin/env bash
# Demonstração para o vídeo da Atividade 1 (Git Bash no Windows).
# Uso: abra o Git Bash, entre na pasta atividade1-serverless e rode:
#   bash demo_video.sh
# Entre uma etapa e outra o script espera você apertar Enter.

cd "$(dirname "$0")" || exit 1
sam() { sam.cmd "$@"; }
LOG="$TEMP/sam-api.log"
URL="http://127.0.0.1:3000/guias"

titulo() { clear; echo -e "\n\033[1;36m=== $1 ===\033[0m\n"; }
pausa()  { echo; read -r -p $'\033[1;33m>> Enter para continuar\033[0m'; }

parar_api() {
  local pid
  for pid in $(netstat -ano | grep ':3000 ' | grep LISTENING | awk '{print $NF}' | sort -u); do
    taskkill //PID "$pid" //T //F >/dev/null 2>&1
  done
  sleep 1
}

subir_api() {
  parar_api
  : > "$LOG"
  sam local start-api "$@" > "$LOG" 2>&1 &
  echo "subindo: sam local start-api $*"
  until grep -q "Running on" "$LOG"; do sleep 1; done
  echo -e "API no ar em $URL\n"
}

pedido() {
  echo -e "\033[1;32m\$ curl -X POST $URL -d '$1'\033[0m"
  curl -s -i -X POST "$URL" -H "Content-Type: application/json" -d "$1" \
    | grep -E "^HTTP|^\{"
  echo
}

# preparação: garante Timeout 3 e build atualizado (fora do vídeo)
parar_api
sed -i 's/Timeout: 10/Timeout: 3/' template.yaml
echo "Preparando (sam build)..."
sam build > /dev/null 2>&1

# 1. código
titulo "1. A função: hello_world/app.py"
cat hello_world/app.py
echo
grep -n -E "Timeout|Path|Method" template.yaml
pausa

# 2. invocação com evento
titulo "2. sam local invoke com o evento do API Gateway (2 vezes)"
for i in 1 2; do
  echo -e "\033[1;32m\$ time sam local invoke -e events/pedido.json   (vez $i)\033[0m"
  time (sam local invoke -e events/pedido.json 2>&1 | grep -E "REPORT|statusCode")
  echo
done
pausa

# 3. HTTP sem reaproveitamento
titulo "3. HTTP com sam local start-api (sem --warm-containers)"
subir_api
for i in 1 2 3; do pedido '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'; done
echo "Sem requisicaoId (espera 400):"
pedido '{"hospital":"H-Caruaru"}'
pausa

# 4. HTTP com reaproveitamento
titulo "4. HTTP com --warm-containers LAZY"
subir_api --warm-containers LAZY
for i in 1 2 3; do pedido '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'; done
pausa

# 5. timeout de 3 s
titulo "5. demorar=true com Timeout: 3"
grep -n "Timeout" template.yaml
echo
pedido '{"requisicaoId":"R-003","demorar":true}'
echo "Log do SAM:"
grep -E "timed out|Duration: 3000" "$LOG"
pausa

# 6. timeout de 10 s
titulo "6. Timeout trocado para 10 + sam build"
parar_api
sed -i 's/Timeout: 3/Timeout: 10/' template.yaml
grep -n "Timeout" template.yaml
echo -e "\n\$ sam build"
sam build 2>&1 | grep -E "Build Succeeded|Error"
subir_api --warm-containers LAZY
echo "Aguarde ~5 s..."
pedido '{"requisicaoId":"R-003","demorar":true}'
pausa

# limpeza: volta ao estado original
parar_api
sed -i 's/Timeout: 10/Timeout: 3/' template.yaml
sam build > /dev/null 2>&1
titulo "Fim da demonstração"
