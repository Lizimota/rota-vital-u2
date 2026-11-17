# Roteiro do vídeo (até 3 minutos)

Deixe antes: imagem do ElasticMQ já baixada (rode o `docker run` uma vez antes de gravar) e quatro terminais organizados na tela.

| Tempo | Tela | O que falar |
|---|---|---|
| 0:00 a 0:20 | Terminal 1: `docker run ... elasticmq-native` | "Essa é a fila ElasticMQ, compatível com o Amazon SQS, rodando em Docker." |
| 0:20 a 0:40 | Terminal 2: `aws sqs create-queue ... VisibilityTimeout=15` | "Criei a fila guias com visibility timeout de 15 segundos." |
| 0:40 a 1:00 | VS Code: `consumidor.py` | "O consumidor recebe até 10 mensagens, gera a guia e só depois apaga. Se der erro, não apaga, e a mensagem volta." |
| 1:00 a 1:50 | Dois consumidores + produtor | "Subi dois consumidores, cada um com seu PID, e rodei o produtor com 21 mensagens. Olhem como as guias se dividiram entre os dois e que a ordem não foi mantida." |
| 1:50 a 2:40 | Esperar a inválida voltar | "A mensagem sem requisicaoId falha e não é apagada. A cada 15 segundos ela volta, e o ApproximateReceiveCount sobe: 1, 2, 3." |
| 2:40 a 3:00 | (opcional) `ver_dlq.py` | "Com a DLQ configurada, depois de 3 tentativas ela vai para a fila de mensagens mortas." |
