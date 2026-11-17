# Evidências da Atividade 1

Prints da execução local (Windows 11 + Git Bash):

| Arquivo | O que mostrar |
|---|---|
| `01-versoes.png` | `sam --version`, `docker --version`, `python --version` |
| `02-sam-build.png` | `sam build` com "Build Succeeded" |
| `03-invoke-1.png` | 1ª `sam local invoke -e events/pedido.json` com a linha REPORT (Duration e Init Duration) |
| `04-invoke-2.png` | 2ª invocação com a linha REPORT |
| `05-start-api-sem-warm.png` | três curls com `invocacaoNesteAmbiente: 1` |
| `06-start-api-warm-lazy.png` | três curls com `invocacaoNesteAmbiente: 1, 2, 3` |
| `07-erro-400.png` | curl sem `requisicaoId` devolvendo 400 |
| `08-timeout-3s.png` | `demorar=true` com erro de timeout (terminal do curl e do start-api) |
| `09-timeout-10s.png` | `template.yaml` com Timeout 10 |
| `09b-timeout-10s-resposta.png` | resposta 201 com a guia G-R-003 depois do ajuste |
