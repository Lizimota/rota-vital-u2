# Evidências da Atividade 2

Prints da execução local (Windows 11 + Git Bash + ElasticMQ):

| Arquivo | O que mostrar |
|---|---|
| `01-elasticmq-no-ar.png` | terminal com `docker run ... elasticmq-native` rodando |
| `02-fila-criada.png` | `aws sqs create-queue` devolvendo a QueueUrl e `get-queue-attributes` com VisibilityTimeout 15 |
| `03-produtor.png` | `python produtor.py` com "21 mensagens enviadas" |
| `04-um-consumidor.png` | 20 guias geradas e a inválida voltando com ReceiveCount 1, 2, 3 (horários a cada ~15 s) |
| `05-dois-consumidores.png` | os dois terminais lado a lado, cada um com seu PID e suas guias |
