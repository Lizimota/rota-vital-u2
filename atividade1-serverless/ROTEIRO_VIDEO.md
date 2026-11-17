# Roteiro do vídeo (até 3 minutos)

Deixe antes: Docker aberto, `sam build` já rodado uma vez (para não perder tempo baixando imagem), dois terminais lado a lado e o VS Code com `app.py` e `template.yaml`.

| Tempo | Tela | O que falar |
|---|---|---|
| 0:00 a 0:20 | VS Code com `app.py` | "Essa é a função que gera a guia de transporte do Rota Vital. Ela lê o body, valida o requisicaoId e devolve a guia. A variável global contador mostra se o ambiente foi reaproveitado." |
| 0:20 a 0:35 | `template.yaml` | "No template a rota é POST /guias e o Timeout está em 3 segundos." |
| 0:35 a 1:05 | Terminal: `sam local invoke -e events/pedido.json` duas vezes | "Invocando com o evento do API Gateway. Olhem a linha REPORT: a primeira levou X, a segunda Y." |
| 1:05 a 1:45 | `sam local start-api` + 3 curls, depois `--warm-containers LAZY` + 3 curls | "Sem warm containers o contador fica em 1 sempre, cada chamada é um container novo. Com LAZY, vai 1, 2, 3: o ambiente foi reaproveitado." |
| 1:45 a 2:25 | curl com `demorar:true` | "Agora a função dorme 5 segundos com Timeout de 3. Deu timeout e o curl recebeu erro." |
| 2:25 a 2:55 | Troca para Timeout 10, `sam build`, curl de novo | "Com Timeout 10 a guia volta com 201 depois de 5 segundos." |
| 2:55 a 3:00 | | "É isso, obrigada." |
