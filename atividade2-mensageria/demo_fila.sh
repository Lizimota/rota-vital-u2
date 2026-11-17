#!/usr/bin/env bash
# Demonstração automática da Atividade 2 (Git Bash no Windows).
# Uso: abra o Git Bash, entre na pasta atividade2-mensageria e rode:
#   bash demo_fila.sh
# Entre uma etapa e outra o script espera você apertar Enter.

cd "$(dirname "$0")" || exit 1
export AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=x AWS_DEFAULT_REGION=us-east-1
EP="http://localhost:9324"
LOGS="${TEMP:-/tmp}/demo-fila"
mkdir -p "$LOGS"

titulo() { clear; echo -e "\n\033[1;36m=== $1 ===\033[0m\n"; }
pausa()  { echo; read -r -p $'\033[1;33m>> Enter para continuar\033[0m'; }
cmd()    { echo -e "\033[1;32m\$ $*\033[0m"; "$@"; }

parar_consumidores() {
  local f pid
  for f in "$LOGS"/c*.log; do
    [ -f "$f" ] || continue
    pid=$(head -1 "$f" | awk '/consumidor PID/{print $3}')
    [ -n "$pid" ] || continue
    if command -v taskkill >/dev/null; then taskkill //F //PID "$pid" >/dev/null 2>&1
    else kill "$pid" 2>/dev/null; fi
  done
  sleep 1
}

recriar_fila() {
  local url
  url=$(aws sqs get-queue-url --queue-name guias --endpoint-url $EP --query QueueUrl --output text 2>/dev/null)
  [ -n "$url" ] && aws sqs delete-queue --queue-url "$url" --endpoint-url $EP >/dev/null 2>&1
  cmd aws sqs create-queue --queue-name guias --attributes VisibilityTimeout=15 --endpoint-url $EP
}

consumidor() {  # $1 = nome do log
  : > "$LOGS/$1.log"
  python -u consumidor.py > "$LOGS/$1.log" 2>&1 &
  until grep -q "consumidor PID" "$LOGS/$1.log"; do sleep 0.5; done
  head -1 "$LOGS/$1.log"
}

# ---------------------------------------------------------------
titulo "1. Subindo a fila ElasticMQ (compatível com Amazon SQS)   [print 01]"
docker rm -f elasticmq >/dev/null 2>&1
docker ps -q --filter ancestor=softwaremill/elasticmq-native | xargs -r docker rm -f >/dev/null 2>&1
cmd docker run -d --rm --name elasticmq -p 9324:9324 softwaremill/elasticmq-native
until docker logs elasticmq 2>&1 | grep -q "started in"; do sleep 1; done
echo
docker logs elasticmq 2>&1 | grep -E "Started SQS|started in"
echo
docker ps --filter name=elasticmq --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
pausa

# ---------------------------------------------------------------
titulo "2. Criando a fila 'guias' com visibility timeout de 15 s   [print 02]"
recriar_fila
echo
URL=$(aws sqs get-queue-url --queue-name guias --endpoint-url $EP --query QueueUrl --output text)
cmd aws sqs get-queue-attributes --queue-url "$URL" --attribute-names VisibilityTimeout --endpoint-url $EP
pausa

# ---------------------------------------------------------------
titulo "3. Um consumidor + produtor (21 mensagens)   [print 03]"
consumidor c1
echo
cmd python produtor.py
echo
echo "Acompanhando o consumidor por 50 s (a inválida deve voltar a cada 15 s)..."
echo
timeout 50 tail -n +2 -f "$LOGS/c1.log"
pausa

titulo "Resultado com UM consumidor   [print 04]"
cat "$LOGS/c1.log"
pausa

# ---------------------------------------------------------------
titulo "4. Dois consumidores + produtor (fila recriada)"
parar_consumidores
recriar_fila
echo
echo -n "consumidor 1: "; consumidor c1
echo -n "consumidor 2: "; consumidor c2
echo
cmd python produtor.py
echo
echo "Aguardando 50 s para a mensagem inválida voltar algumas vezes..."
for i in $(seq 50 -1 1); do echo -ne "\r$i s "; sleep 1; done
echo
pausa

titulo "Resultado com DOIS consumidores, lado a lado   [print 05]"
curto() { sed -E -e "s/falhou; volta para a fila: mensagem sem requisicaoId \{'ApproximateReceiveCount': '([0-9]+)'\}/FALHOU, volta p\/ fila (ReceiveCount \1)/" -e "s/ lendo .*//" "$1"; }
if command -v pr >/dev/null; then pr -m -t -w 120 <(curto "$LOGS/c1.log") <(curto "$LOGS/c2.log")
else paste <(curto "$LOGS/c1.log") <(curto "$LOGS/c2.log") | column -t -s $'\t'; fi
echo
echo "Guias geradas: consumidor 1 = $(grep -c ' guia ' "$LOGS/c1.log")  |  consumidor 2 = $(grep -c ' guia ' "$LOGS/c2.log")"
pausa

# ---------------------------------------------------------------
parar_consumidores
docker rm -f elasticmq >/dev/null 2>&1
titulo "Fim da demonstração"
