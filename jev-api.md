# Jev (TypeSafe) via OpenRouter — referência para a POC

Levantado em 2026-10-06 da documentação pública do OpenRouter e da TypeSafe (fontes no fim).

## Endpoint e autenticação

```
POST https://openrouter.ai/api/alpha/decisions
Authorization: Bearer <OPENROUTER_API_KEY>
Content-Type: application/json
```

- Uma chave OpenRouter basta (não precisa de conta TypeSafe).
- Existe uma segunda superfície, `POST https://openrouter.ai/api/v1/systemone`, usada pelo SDK `@typesafe-ai/sdk`. Para HTTP direto use `/api/alpha/decisions` (é "alpha": o contrato pode mudar).
- A página de API reference mostra `https://openrouter.ai/api/v1/api/alpha/decisions`; tutorial e exemplos usam `/api/alpha/decisions`. Se o primeiro der 404, testar o outro.

## Modelo

- `typesafe/jev-1.13` (fixo) ou `~typesafe/jev-latest` (alias que acompanha a versão atual).
- A resposta traz a versão datada, ex. `typesafe/jev-1.13-20260917` → gravar em `JevModeloVersao`.
- Para a POC, fixar `typesafe/jev-1.13` (reprodutibilidade dos limiares).

## Requisição

Obrigatórios: `model`, `state`, `questions`. Opcionais: `provider`, `session_id` (≤256), `user` (≤256), `trace`.

- `state`: string, objeto JSON ou array de textos. Recomendado: objeto com nomes descritivos em snake_case. Só texto.
- `questions`: objeto `{ chave: pergunta }`. Todas as perguntas veem o mesmo state, rodam em paralelo e não veem as respostas umas das outras.
- Limite: 32.000 tokens (state + questions).
- Precisão menor fora do inglês → escrever chaves, `instructions` e `criteria` em inglês.

### Tipos de pergunta

| type | instructions | criteria (obrigatório) | Limites |
|---|---|---|---|
| `noul` | string ou objeto | `{ "true": ..., "false": ... }` | — |
| `choice` | string ou objeto | `{ opcao: descrição, ... }` | até 255 opções |
| `score` | string ou objeto | array ordenado do menor para o maior | 2 a 10 níveis |

Cada critério pode ser string ou objeto com `what`, `not_for`, `examples` (score aceita também `signals`). Instructions em objeto aceitam `question`, `focus`, `compare`, `inspect`. Referencie campos do state com crase: `` `supplier.age_days` ``.

### Boas práticas (doc TypeSafe)

- Perguntas atômicas e específicas; combinar em código.
- Mandar fatos já computados como rótulos (`price_vs_info_record: "20_pct_above"`) em vez de números crus para o modelo calcular.
- Só o necessário no state; não colar valores do banco dentro das instructions.
- Regras duras antes do Jev; política (limiares → ação) em código, não no modelo.

## Resposta 200

```json
{
  "id": "gen-dec-...",
  "model": "typesafe/jev-1.13-20260917",
  "provider": "TypeSafe",
  "answers": {
    "q_noul":   { "type": "noul",   "noul": 0.96 },
    "q_choice": { "type": "choice", "choice": "payments", "confidence": 0.75,
                  "probabilities": { "account": 0, "frontend": 0.16, "payments": 0.84 } },
    "q_score":  { "type": "score",  "score": 1.99, "confidence": 0.99,
                  "probabilities": { "0": 0, "1": 0.01, "2": 0.99 },
                  "legend": { "0": "...", "1": "...", "2": "..." } }
  },
  "usage": { "input_tokens": 476, "output_tokens": 70, "cost": 0.000019992 }
}
```

- `noul`: probabilidade de "true" (0–1); sem `confidence`. Confiança equivalente: `|2p − 1|`.
- `choice`: `choice` = opção de maior probabilidade; `confidence = (p_max − 1/n) / (1 − 1/n)`.
- `score`: `score` é o índice base 0 ponderado pela probabilidade (ex. 1.99); `confidence` mede a concentração.
- `confidence` não é probabilidade de acerto.
- `usage.cost` em USD; saída gratuita, cobra só entrada.

## Erros

Corpo: `{ "error": { "code", "message", "metadata" }, "user_id", "openrouter_metadata" }`.

| Código | Significado | Na POC |
|---|---|---|
| 400 | parâmetros inválidos | INDISPONIVEL + log (bug do payload) |
| 401 / 403 | chave ausente/inválida | INDISPONIVEL |
| 402 | sem créditos | INDISPONIVEL |
| 413 | payload grande | INDISPONIVEL |
| 429 | rate limit | INDISPONIVEL (backoff no lote) |
| 500 / 502 / 503 / 524 / 529 | provedor/infra | INDISPONIVEL |

Validar a forma da resposta (type esperado, campos presentes); se não bater, tratar como INDISPONIVEL. Nunca usar default.

## Desempenho, custo e calibração

- Latência: doc TypeSafe cita ~100 ms na maioria das consultas.
- Preço: por token de entrada; ver página do modelo no OpenRouter.
- Calibração: limiares a partir do custo de cada erro, testados em dados rotulados (rotular exemplos, chamar uma vez, salvar respostas, varrer limiares). Começar conservador.

## Mapeamento para a POC (ação `registrarAvaliacao`)

| Chave Jev | type | Parâmetro ABAP |
|---|---|---|
| `fornecedor_ficticio` | noul | `ProbFornecedorFicticio` = `noul` |
| `desvio_pagamento` | noul | `ProbDesvioPagamento` |
| `sobrepreco` | noul | `ProbSobrepreco` |
| `fracionamento` | noul | `ProbFracionamento` |
| `fraude_interna` | noul | `ProbFraudeInterna` |
| `atipicidade` | score, 5 níveis | `Atipicidade` = `round(score) + 1` (índice 0–4 → 1–5) |
| `acao` | choice `liberar`/`aprovacao`/`bloquear` | `JevAcaoSugerida` = `choice` em maiúsculas; `JevProbLiberar/Aprovacao/Bloquear` = `probabilities` |
| (resposta) `model` | — | `JevModeloVersao` |

Todas as probabilidades arredondadas a 4 casas.

## Fontes

- https://openrouter.ai/docs/guides/community/jev-tutorial
- https://openrouter.ai/docs/guides/community/jev
- https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-questions-and-answers-request
- https://openrouter.ai/docs/guides/community/typesafe-sdk
- https://openrouter.ai/blog/tutorials/how-to-use-jev/
- https://docs.typesafe.ai/concepts/state
- https://docs.typesafe.ai/confidence
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one
