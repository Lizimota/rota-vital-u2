# Atividade individual 1: Serverless (Rota Vital)

Infraestrutura de Software · ADS · CESAR School · 2026.2 · Prof. Raoni Monteiro de Oliveira
Aluna: Eliziane

Função HTTP que recebe uma requisição do Rota Vital e devolve a **guia de transporte** da requisição.

## Caminho escolhido

**Caminho A: AWS SAM CLI local** (Docker + SAM CLI + Python 3.12). Tudo roda no meu computador, sem conta na AWS. O evento usado no `sam local invoke` tem o mesmo formato que o Lambda recebe do API Gateway na nuvem.

## Estrutura

```
atividade1-serverless/
├── template.yaml            # SAM: rota POST /guias, Timeout 3 s, 128 MB
├── hello_world/
│   ├── app.py               # handler que gera a guia
│   └── requirements.txt
├── events/
│   ├── pedido.json          # gerado com sam local generate-event (R-001)
│   ├── pedido-demorado.json # demorar=true (teste de timeout)
│   └── pedido-invalido.json # sem requisicaoId (espera 400)
└── evidencias/              # prints dos comandos e saídas
```

O projeto foi criado com `sam init` (AWS Quick Start Templates > Hello World Example > Python 3.12 > zip). No `template.yaml` troquei `/hello` por `/guias` e `get` por `post`, e renomeei a função para `GuiaTransporteFunction`.

### Ajuste que precisei fazer no código do enunciado

O evento criado por `sam local generate-event ... --body '...'` vem com o body **codificado em Base64** (`"isBase64Encoded": true`). O código original fazia `json.loads(event["body"])` direto e quebrava com `JSONDecodeError` no Passo 3. Criei a função `ler_body`, que decodifica o Base64 quando esse campo é `true`. O curl via `start-api` manda texto puro, então funciona dos dois jeitos. O resto do handler é igual ao do enunciado.

## Pré-requisitos

- Docker Desktop rodando
- AWS SAM CLI (`sam --version`)
- Python 3.12
- No Windows: usar Git Bash ou WSL

## Como rodar

Todos os comandos dentro da pasta `atividade1-serverless/`.

### Passo 3: invocar com evento

```bash
# (o evento já está no repositório; este é o comando que o gerou)
sam local generate-event apigateway aws-proxy --method POST --path guias \
  --body '{"requisicaoId":"R-001","hospital":"H-Recife","bolsas":["O-NEG-0142"]}' \
  > events/pedido.json

sam build
sam local invoke -e events/pedido.json   # 1ª vez
sam local invoke -e events/pedido.json   # 2ª vez
```

Resposta esperada:

```json
{"statusCode": 201, "body": "{\"guia\": \"G-R-001\", \"hospital\": \"H-Recife\", \"bolsas\": [\"O-NEG-0142\"], \"invocacaoNesteAmbiente\": 1}"}
```

O tempo aparece na linha `REPORT RequestId: ... Duration: ... ms ... Init Duration: ... ms` do log. Também dá para medir o comando inteiro com `time sam local invoke -e events/pedido.json`.

### Passo 4: acionar por HTTP

```bash
sam local start-api
```

Em outro terminal, três vezes:

```bash
curl -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
  -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'
```

Depois parar o servidor (Ctrl+C), subir com reaproveitamento de container e repetir os três curls:

```bash
sam local start-api --warm-containers LAZY
```

Teste extra do erro 400:

```bash
curl -i -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
  -d '{"hospital":"H-Caruaru"}'
```

### Passo 5: limite de tempo

Com o servidor no ar (`Timeout: 3`):

```bash
curl -i -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
  -d '{"requisicaoId":"R-003","demorar":true}'
# ou: sam local invoke -e events/pedido-demorado.json
```

Depois trocar `Timeout: 3` por `Timeout: 10` no `template.yaml`, rodar `sam build`, subir o `start-api` de novo e repetir.

## Resultados registrados

Valores medidos na minha máquina (Windows 11, Git Bash, Docker Desktop 29.9.3, SAM CLI 1.172.1). Prints em [`evidencias/`](evidencias/).

| Experimento | Resultado |
|---|---|
| `sam local invoke` 1ª vez | Duration 137,71 ms · Init Duration 0,05 ms · comando inteiro (`real`) **59,9 s** |
| `sam local invoke` 2ª vez | Duration 86,18 ms · Init Duration 0,81 ms · comando inteiro (`real`) **9,6 s** |
| 3 curls sem `--warm-containers` | `invocacaoNesteAmbiente`: 1, 1, 1 |
| 3 curls com `--warm-containers LAZY` | `invocacaoNesteAmbiente`: 1, 2, 3 |
| `demorar=true` com Timeout 3 | `Function 'GuiaTransporteFunction' timed out after 3 seconds`, Duration 3000 ms; curl recebeu **HTTP 502 Bad Gateway** com `{"message":"Internal server error"}` |
| `demorar=true` com Timeout 10 | **HTTP 201 Created** depois de ~5 s, guia `G-R-003` |

## Respostas

**1. Por que a primeira invocação demorou mais que a segunda? O que acontece na fase de Init?**

Na primeira execução o ambiente ainda não existe. Ele precisa ser criado do zero: o Docker baixa a imagem do runtime Python 3.12 (só na primeira vez da máquina), sobe o container, carrega o runtime e importa o meu `app.py`, rodando o código que está fora do handler (como `contador = 0`). Isso é a fase de **Init**, o famoso cold start. Só depois vem a fase **Invoke**, que roda o `lambda_handler`.
No `sam local invoke` cada comando cria um container novo, então as duas execuções passam pelo Init. A diferença grande no meu caso (59,9 s na primeira contra 9,6 s na segunda) veio principalmente da preparação da imagem: na primeira vez apareceu `Local image was not found` e `Building image...`, e na segunda `Local image is up-to-date`. A execução do handler em si foi curta nas duas (137 ms e 86 ms). O `Init Duration` saiu quase zero (0,05 ms e 0,81 ms) porque o emulador local não mede o Init como a AWS mede; na nuvem esse número aparece de verdade no CloudWatch. Na nuvem a lógica é parecida: a primeira chamada paga o Init, e as seguintes, se caírem num ambiente já quente, pulam essa etapa e ficam bem mais rápidas.

**2. O que o campo `invocacaoNesteAmbiente` mostrou com e sem `--warm-containers`? O que isso diz sobre guardar estado numa variável global?**

Sem `--warm-containers`, as três chamadas devolveram `1`: cada requisição subiu um container novo, a variável `contador` nasceu zerada todas as vezes. Com `--warm-containers LAZY`, voltou `1`, `2`, `3`, porque o mesmo container foi reaproveitado e a variável global continuou na memória entre as chamadas.
A conclusão é que variável global **não é lugar para guardar estado de negócio**. Ela só sobrevive se a plataforma decidir reaproveitar o ambiente, e isso eu não controlo: o ambiente pode ser destruído a qualquer momento, e com várias chamadas simultâneas a AWS sobe vários ambientes, cada um com o seu contador. Global serve para cache (conexão com banco, configuração carregada). Estado de verdade, como "quantas guias já emiti", vai para um serviço externo (DynamoDB, RDS, S3).

**3. O que aconteceu com `demorar = true`? Qual o tempo máximo de uma execução no Lambda, e o que fazer com um trabalho mais longo?**

Com `Timeout: 3`, a função dormiu 5 s e foi interrompida aos 3 s. O SAM registrou `Function 'GuiaTransporteFunction' timed out after 3 seconds` (Duration 3000 ms) e o curl recebeu `HTTP 502 Bad Gateway` com `Internal server error` em vez da guia. Depois de subir para `Timeout: 10` e rodar `sam build`, a mesma chamada devolveu 201 com a guia em uns 5 s.
O máximo no Lambda é **15 minutos (900 s)**. Para trabalho mais longo dá para quebrar o processo em etapas orquestradas pelo **Step Functions**, colocar os itens numa **fila (SQS)** e processar em partes, ou mandar o trabalho para um serviço sem esse limite, como um container no **ECS/Fargate** ou um job do **AWS Batch**. Também vale lembrar que, atrás do API Gateway, o limite prático de resposta HTTP é bem menor (29 s por padrão), então chamada síncrona demorada já é sinal de que o desenho tem que ser assíncrono.

**4. Custo de 1 milhão de execuções com 128 MB e 100 ms (us-east-1, sem faixa gratuita)**

- Requisições: 1.000.000 × (US$ 0,20 / 1.000.000) = **US$ 0,20**
- Memória em GB: 128 MB = 128 / 1024 = 0,125 GB
- GB-s por execução: 0,125 GB × 0,1 s = 0,0125 GB-s
- GB-s totais: 0,0125 × 1.000.000 = 12.500 GB-s
- Computação: 12.500 × US$ 0,0000166667 = **US$ 0,2083**
- **Total: US$ 0,20 + US$ 0,21 ≈ US$ 0,41** por milhão de execuções

Dentro da faixa sempre gratuita (1 milhão de requisições e 400 mil GB-s por mês), esse volume sairia de graça.

**5. Em que parte do Rota Vital uma função assim faria sentido, e em qual não faria?**

Faz sentido em tarefas curtas, sem estado e com demanda irregular: emitir a guia de transporte quando chega uma requisição, gerar o PDF da guia, mandar a notificação ao motorista ou ao hospital, validar os dados da requisição, reagir a um evento de "bolsa reservada". São coisas que levam milissegundos, acontecem em picos (emergências não têm hora) e não precisam de servidor ligado o tempo todo, então se paga só pelo uso.
Não faria sentido no rastreamento em tempo real do transporte (conexão contínua via WebSocket, GPS mandando posição a cada segundo, que fica caro e esbarra em limites de tempo), em processos longos como relatórios pesados de fechamento, nem como lugar para guardar o estado das requisições: isso precisa de banco de dados. Também deixaria fora o que exige latência baixa e previsível o tempo todo, onde o cold start pode atrapalhar, a não ser que se pague por concorrência provisionada.

## Uso de IA

- **Ferramenta:** Claude (Anthropic).
- **Finalidade:** apoio na organização do repositório e do README, revisão do código do enunciado (foi a IA que apontou que o evento gerado pelo SAM vem em Base64 e quebraria o `json.loads`) e revisão das respostas.
- **Como validei:** rodei todos os comandos do passo a passo na minha máquina, conferi as saídas (prints em `evidencias/`), refiz a conta de custo à mão e conferi o limite de 15 minutos e a fase de Init na documentação oficial do Lambda. As respostas foram reescritas com os meus resultados.

## Referências

- [Ciclo de vida do ambiente de execução do Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html)
- [Cotas do Lambda](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [Preços do Lambda](https://aws.amazon.com/lambda/pricing/)
- [Instalação do SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
