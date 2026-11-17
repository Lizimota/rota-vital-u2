# Atividade individual 2: Mensageria (Rota Vital)

Infraestrutura de Software · ADS · CESAR School · 2026.2 · Prof. Raoni Monteiro de Oliveira
Aluna: Eliziane

Fila compatível com o Amazon SQS, um produtor e dois consumidores. O produtor publica pedidos de guia de transporte do Rota Vital; os consumidores retiram, geram a guia e só então confirmam (apagam) a mensagem.


**Vídeo da demonstração (2:00):** https://drive.google.com/file/d/1J1qE5Jh1LV92anGYNE9QPX6Xrfz57SsW/view?usp=drivesdk

> No vídeo, os trechos de espera sem fala (consumidor aguardando a reentrega e a contagem de 50 s) estão acelerados para caber em 3 minutos; os horários reais aparecem nos logs.

## Caminho escolhido

**Caminho A: ElasticMQ local em Docker.** O ElasticMQ implementa a mesma API do Amazon SQS, então o código é o mesmo do SQS mudando só o endereço. Não precisa de conta nem cartão.

## Estrutura

```
atividade2-mensageria/
├── produtor.py             # publica 20 pedidos válidos + 1 inválido
├── consumidor.py           # recebe, processa, e só depois apaga
├── criar_filas_com_dlq.py  # opcional: fila "guias" com DLQ (maxReceiveCount=3)
├── ver_dlq.py              # opcional: mostra o que caiu na DLQ
├── demo_fila.sh            # roda toda a demonstração (usado nos prints e no vídeo)
└── evidencias/             # prints dos comandos e saídas
```

Em relação ao código do enunciado, acrescentei só o horário (`HH:MM:SS`) nas mensagens do consumidor, para ficar visível que a mensagem inválida volta a cada 15 s, e a leitura do endereço por variável de ambiente (`SQS_ENDPOINT`), para o mesmo código servir no SQS real.

## Pré-requisitos

- Docker Desktop
- AWS CLI v2
- Python 3.12 e boto3: `pip install boto3`
- No Windows: Git Bash ou WSL

## Como rodar

### 1. Subir a fila (terminal 1, deixar rodando)

```bash
docker run --rm -p 9324:9324 softwaremill/elasticmq-native
```

### 2. Criar a fila com visibility timeout de 15 s (terminal 2)

```bash
export AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=x AWS_DEFAULT_REGION=us-east-1
aws sqs create-queue --queue-name guias --attributes VisibilityTimeout=15 \
  --endpoint-url http://localhost:9324

# conferir o atributo
aws sqs get-queue-attributes --queue-url http://localhost:9324/000000000000/guias \
  --attribute-names VisibilityTimeout --endpoint-url http://localhost:9324
```

(Use a `QueueUrl` que a CLI devolver no comando anterior.)

### 3. Um consumidor

```bash
python consumidor.py      # terminal 2
python produtor.py        # terminal 3
```

O consumidor gera as 20 guias e a mensagem inválida volta a cada 15 s com `ApproximateReceiveCount` subindo (1, 2, 3...).

### 4. Dois consumidores

Parar tudo (Ctrl+C nos consumidores). Para não misturar com a mensagem inválida do teste anterior, reiniciar o ElasticMQ (Ctrl+C e subir de novo) e recriar a fila do passo 2. Depois:

```bash
python consumidor.py      # terminal 2 (mostra o PID)
python consumidor.py      # terminal 3 (outro PID)
python produtor.py        # terminal 4
```

Anotar quais guias saíram em cada PID e se a ordem R-001, R-002... foi mantida.

### 5. Opcional: DLQ

```bash
python criar_filas_com_dlq.py   # recria "guias" com DLQ "guias-dlq", maxReceiveCount=3
python consumidor.py
python produtor.py
# esperar ~45 s (3 tentativas de 15 s)
python ver_dlq.py
```

Depois da 3ª falha a mensagem inválida some da fila principal e aparece na `guias-dlq`.

### Caminho B (se quiser usar o SQS real)

Criar a fila Standard `guias` no console com visibility timeout de 15 s, configurar as chaves com `aws configure` (nunca no código) e rodar:

```bash
SQS_ENDPOINT="" python consumidor.py
SQS_ENDPOINT="" python produtor.py
```

## Resultados registrados

Valores da execução na minha máquina (Windows 11, Git Bash, Docker Desktop, ElasticMQ 1.7.1, AWS CLI 2.40.2, boto3 1.42.62). Prints em [`evidencias/`](evidencias/).

**Um consumidor (PID 8392):**

```
18:30:50 8392 guia G-R-001 H-Recife
...                                   (R-001 a R-020, em ordem)
18:30:51 8392 guia G-R-020 H-Recife
18:30:51 falhou; volta para a fila: mensagem sem requisicaoId {'ApproximateReceiveCount': '1'}
18:31:06 falhou; volta para a fila: mensagem sem requisicaoId {'ApproximateReceiveCount': '2'}
18:31:21 falhou; volta para a fila: mensagem sem requisicaoId {'ApproximateReceiveCount': '3'}
...                                   (continuou voltando a cada 15 s)
```

**Dois consumidores (PIDs 4468 e 7884):**

```
consumidor PID 4468                          consumidor PID 7884
18:48:12 4468 guia G-R-001 H-Recife          18:48:12 7884 guia G-R-002 H-Recife
18:48:13 4468 guia G-R-003 H-Recife          18:48:13 7884 guia G-R-004 H-Recife
...      (R-005 a R-019, ímpares)            ...      (R-006 a R-020, pares)
18:48:13 FALHOU (ReceiveCount 1)             18:48:43 FALHOU (ReceiveCount 3)
18:48:28 FALHOU (ReceiveCount 2)
18:48:58 FALHOU (ReceiveCount 4)

Guias geradas: consumidor 1 = 10  |  consumidor 2 = 10
```

| Experimento | Resultado |
|---|---|
| Um consumidor | 20 guias geradas em ordem (R-001 a R-020); a inválida voltou às 18:30:51, 18:31:06, 18:31:21... com ReceiveCount 1, 2, 3... (chegou a 20 em ~5 min) |
| Dois consumidores | PID 4468 gerou 10 guias (ímpares), PID 7884 gerou 10 guias (pares); processaram ao mesmo tempo, então não há uma ordem global; a inválida alternou entre os dois |
| DLQ (opcional) | não executado; o script `criar_filas_com_dlq.py` está pronto para quem quiser testar |

## Respostas

**1. Por que o consumidor só apaga a mensagem depois de processar? O que aconteceria se apagasse antes?**

Porque apagar é a forma de dizer para a fila "terminei, pode descartar". Enquanto eu não apago, a mensagem só fica escondida por um tempo, e se o consumidor travar, cair ou der erro no meio, ela volta e outro consumidor pode tentar de novo. Se eu apagasse logo ao receber e o processamento falhasse depois, o pedido sumiria sem a guia ter sido gerada. No Rota Vital isso seria um transporte de bolsa de sangue que ninguém emitiu e ninguém percebeu, porque a fila já achava que estava tudo certo.

**2. Com dois consumidores, como as mensagens se dividiram? A ordem foi mantida? O que a documentação do SQS diz sobre ordem nas filas padrão?**

As 20 mensagens se dividiram certinho: **10 para cada consumidor**. No meu teste o PID 4468 ficou com as ímpares (R-001, R-003...) e o PID 7884 com as pares (R-002, R-004...). Essa alternância foi coincidência do momento em que cada um pediu mensagens: cada `receive_message` pode pegar até 10 de uma vez, e em outra execução a divisão pode sair desigual ou embaralhada.
Sobre a ordem: com **um** consumidor as guias saíram de R-001 a R-020 em sequência. Com **dois**, cada um processou a sua parte ao mesmo tempo (tudo às 18:48:13), então não existe mais uma ordem única: a R-004 pode ficar pronta antes da R-003. Ou seja, a ordem de envio **não é mantida** quando há mais de um consumidor.
A documentação do SQS diz que a fila padrão faz *best-effort ordering*: ela tenta entregar na ordem, mas não garante, e as mensagens podem chegar fora da ordem em que foram enviadas. Se a ordem importa, a opção é a fila **FIFO**, que garante ordem dentro de um mesmo grupo de mensagens (`MessageGroupId`) e faz deduplicação, com um limite menor de vazão.

**3. A fila padrão garante entrega pelo menos uma vez, e a mesma mensagem pode chegar duas vezes. O que isso exige do consumidor? Como vocês o tornariam idempotente?**

Exige que processar a mesma mensagem duas vezes dê o mesmo resultado que processar uma vez. Senão eu poderia emitir duas guias para a mesma requisição e mandar dois motoristas buscar a mesma bolsa.
Para tornar idempotente eu usaria o `requisicaoId` como chave: antes de gerar a guia, o consumidor tenta gravar esse id numa tabela de "guias emitidas" com uma condição de "só grava se não existir" (chave primária num banco relacional ou `ConditionExpression` no DynamoDB). Se a gravação falhar porque já existe, ele não gera de novo, só apaga a mensagem. Como o número da guia já é derivado do id (`G-R-001`), gerar de novo também não cria uma guia diferente. Outra opção é guardar o `MessageId` processado, mas a chave de negócio é mais segura, porque o produtor pode reenviar o mesmo pedido como mensagem nova.

**4. Expliquem o visibility timeout com o que viram na mensagem inválida. Para que serve uma DLQ?**

Quando um consumidor recebe a mensagem, ela não sai da fila: fica invisível para os outros por 15 s (o visibility timeout que configurei). A mensagem inválida dava erro, o consumidor não apagava, e 15 s depois ela reaparecia. Deu para ver isso no horário dos logs (18:30:51, 18:31:06, 18:31:21, sempre 15 s de diferença) e no `ApproximateReceiveCount` subindo 1, 2, 3, até 20. No teste com dois consumidores ela inclusive pulou de um processo para o outro: as tentativas 1 e 2 caíram no PID 4468, a 3 no PID 7884 e a 4 de novo no 4468, porque quando ela volta a ficar visível qualquer consumidor pode pegá-la.
O problema é que uma mensagem que nunca vai dar certo fica voltando para sempre, gastando processamento e poluindo o log. No meu teste ela passou de 20 tentativas e continuaria indefinidamente. A **DLQ** (fila de mensagens mortas) resolve isso: depois de um número de tentativas (`maxReceiveCount`, por exemplo 3) a fila tira a mensagem do fluxo principal e manda para a DLQ, onde alguém pode investigar, corrigir e reenviar. Deixei no repositório o script `criar_filas_com_dlq.py`, que configura isso no ElasticMQ.

**5. No Rota Vital, qual a diferença entre o hospital chamar a emissão de guia diretamente (síncrono) e passar por uma fila (assíncrono)? O que se ganha e o que se perde?**

No **síncrono**, o sistema do hospital chama o serviço de guias e espera a resposta. A vantagem é a simplicidade e a resposta na hora: o hospital já recebe a guia ou o erro. A desvantagem é o acoplamento: se o serviço de guias estiver fora do ar ou lento, o hospital fica travado ou perde o pedido, e num pico de emergências todo mundo compete pelo mesmo serviço ao mesmo tempo.
No **assíncrono**, o hospital só publica o pedido e segue. Ganha-se resiliência (o pedido fica guardado na fila mesmo se o emissor cair), absorção de picos (os consumidores vão no ritmo deles), escala fácil (é só subir mais consumidores, como vimos com dois) e reprocessamento automático em caso de falha. Perde-se a resposta imediata: o hospital precisa de outro jeito de saber que a guia saiu (consulta de status, notificação, webhook). Também fica mais complexo de operar e depurar, a ordem não é garantida na fila padrão e é preciso tratar mensagens duplicadas com idempotência.

## Uso de IA

- **Ferramenta:** Claude (Anthropic).
- **Finalidade:** apoio na organização do repositório e do README, script de demonstração (`demo_fila.sh`), script opcional da DLQ e revisão das respostas.
- **Como validei:** rodei a fila, o produtor e os dois consumidores na minha máquina com o ElasticMQ, conferi a divisão das mensagens e a reentrega a cada 15 s nos logs (prints em `evidencias/`) e conferi na documentação do SQS os pontos sobre ordem, entrega pelo menos uma vez, visibility timeout e DLQ. As respostas foram ajustadas com os meus resultados.

## Referências

- [ElasticMQ](https://github.com/softwaremill/elasticmq)
- [Visibility timeout](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html)
- [Filas padrão](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html)
- [Filas de mensagens mortas](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)
