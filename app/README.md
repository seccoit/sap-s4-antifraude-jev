# zpocjev.antifraude: POC antifraude em pedidos (Jev, modo sombra)

App Fiori Elements V4 (List Report + Object Page) sobre o serviço próprio
`/sap/opu/odata4/sap/zui_poc_jev_o4/srvd/sap/zui_poc_jev/0001/` (entity set `Pedido`).
As anotações de UI vêm do DDLX no backend; o app não tem `annotation.xml` local.

## O que o app faz
- **List Report** de `Pedido`, com semáforos e filtros vindos da CDS. A ação de tabela
  **"Avaliar selecionados com Jev"** processa até 50 pedidos, no máximo 3 ao mesmo tempo.
- **Object Page** com as seções das facets (dados, fornecedor, histórico, velocidade, itens,
  avaliações), mais a seção custom **"Jev (modo sombra)"**, que mostra o aviso, a última chamada
  (status, latência) e o payload enviado. O botão **"Avaliar com Jev (modo sombra)"** fica no cabeçalho.
- **Fluxo:**
  - `BLOQUEIO_REGRA`: não chama o Jev e registra a ação com `JevDisponivel=false`.
  - Nos demais casos, chama `POST /jev/decisions` (timeout de 1500 ms). O proxy encaminha para o Jev
    (TypeSafe via OpenRouter, `POST https://openrouter.ai/api/alpha/decisions`, modelo `typesafe/jev-1.13`).
    - Em sucesso, executa `registrarAvaliacao` com as probabilidades, arredondadas em 4 casas.
    - Em falha, timeout, HTTP 4xx/5xx ou resposta fora do formato, registra `INDISPONIVEL`
      (`JevModeloVersao = INDISPONIVEL:TIMEOUT`, `INDISPONIVEL:HTTP_402`, `INDISPONIVEL:RESPOSTA_INVALIDA`...).
  - Nada é bloqueado no pedido real.
- **Payload do Jev:** `{ state, questions }` (o `model` é definido pelo servidor). O `state` está em inglês,
  agrupado em `supplier`, `order`, `velocity`, `buyer` e `baseline`, com rótulos prontos ao lado dos números
  (ex.: `price_vs_info_record: "10_pct_below"`). Com menos de 3 pedidos anteriores do fornecedor
  (`MIN_PEDIDOS_HISTORICO`), os rótulos de valor vs média, z-score e participação no comprador
  viram `insufficient_history`. O número cru é mantido, e as perguntas dizem que isso não é desvio. Usa lista branca: nunca inclui `SupplierName`,
  `Supplier`, `CreatedByUser` nem o número do pedido. As 7 perguntas usam as chaves do contrato
  (5 `noul`, `atipicidade` como `score` de 5 níveis, `acao` como `choice` liberar/aprovacao/bloquear).
- **Mapeamento da resposta:** `noul` vira `Prob*`; `Atipicidade = round(score) + 1`;
  `JevAcaoSugerida` = `choice` em maiúsculas (**só sinal de comparação**: quem classifica é o ABAP, pelos limiares; na tela aparece como "Sugestão do modelo"); `JevProb*` = `probabilities`; `JevModeloVersao` = `model`.
  O `usage.cost` aparece na seção "Jev (modo sombra)".

## Estrutura
| Caminho | Papel |
|---|---|
| `webapp/manifest.json` | FE V4, Manifest 2.0.0, ResponsiveTable, ações custom, seção custom, controller extensions |
| `webapp/jev/JevClient.js` | cliente do Jev: `buildRequest` (state + perguntas), `parseResponse` (valida e mapeia), timeout, limite de 3 |
| `webapp/jev/AvaliacaoService.js` | orquestra leitura, Jev e ação OData (`bindContext(...).setParameter().invoke()`) |
| `webapp/ext/controller/*.controller.js` | `ControllerExtension` (só `onInit`) com os handlers `.extension.…` |
| `webapp/ext/fragment/JevSombra.fragment.xml` | seção "Jev (modo sombra)" |
| `ui5-middleware/jevProxy.js` | rota `/jev`: Jev real se houver `OPENROUTER_API_KEY` (chave e `model` injetados no servidor), senão simulador |
| `mock-jev/simulator.js`, `mock-jev/server.js` | simulador determinístico no mesmo formato do Jev real, com latência aleatória e falhas |
| `test/unit/*.test.js` | testes em Node (`npm test`) |

## Como rodar
```bash
npm install
cp .env.example .env      # preencha host, client, usuário e senha do S/4
npm start                 # http://localhost:8080/index.html
npm test                  # testes unitários (cliente, simulador, orquestrador, proxy)
npx ui5lint               # linter UI5
```
O proxy `/sap` lê o endereço do S/4 de `UI5_MIDDLEWARE_SIMPLE_PROXY_BASEURI` (terminando em `/sap`) e o
client de `UI5_MIDDLEWARE_SIMPLE_PROXY_QUERY` (ex.: `{"sap-client":"100"}`). Se preferir não gravar a
senha em arquivo, defina as variáveis no shell antes do `npm start`. No PowerShell 5.1, encadeie
comandos com `;` em vez de `&&`.

**Demonstrar a falha segura:** abra `index.html?jev-sim=timeout#/Pedido('4500001403')` e clique
em Avaliar. O resultado é gravado como INDISPONIVEL. `jev-sim=erro` força um HTTP 503 e
`jev-sim=ok` força o sucesso. Sem o parâmetro, o simulador estoura o timeout em cerca de 15% das
chamadas e responde 503 em cerca de 5%.

## Como ligar o Jev real (OpenRouter)
1. No `.env` (fora do git), preencha `OPENROUTER_API_KEY=<sua chave>`. Não coloque a chave em nenhum outro arquivo.
2. Reinicie: `npm start`. O log do servidor mostra `/jev -> Jev real (openrouter.ai, modelo typesafe/jev-1.13)`
   e `GET http://localhost:8080/jev/health` responde `"modo":"real"`.
3. Avalie um pedido. Em erro, o `JevModeloVersao` mostra o motivo (ex.: `INDISPONIVEL:HTTP_401` para chave inválida e `HTTP_402` para falta de créditos).
   Se `/api/alpha/decisions` responder 404, defina `JEV_URL=https://openrouter.ai/api/v1/api/alpha/decisions`.
4. Opcionais: `JEV_MODEL` (padrão `typesafe/jev-1.13`) e `JEV_TIMEOUT_MS`. O parâmetro `?jev-sim=` só afeta o simulador.
5. Para exercitar o modo real sem gastar créditos: `npm run mock-jev` (porta 4005) e, no `.env`,
   `OPENROUTER_API_KEY=teste-local` e `JEV_URL=http://localhost:4005/api/alpha/decisions`.
6. Em produção (BSP/FLP), a rota `/jev` precisa de um destino equivalente no servidor (SICF, proxy reverso
   ou BTP Destination) que injete a chave. Este middleware só existe no servidor de desenvolvimento.

## Roadmap
- **Distância do valor até a alçada de aprovação** (estratégia de liberação) como indicador de
  `fracionamento`: pedidos logo abaixo do limite de uma alçada, repetidos ao mesmo fornecedor, são o
  sinal clássico de compra fracionada. **Requer uma CDS nova no backend** (estratégia/limites de
  liberação por pedido, ex. `distance_to_release_limit_pct`) e o campo correspondente em `Pedido`.
  Depois, entra no `state.order` e no `focus` da pergunta `fracionamento`.

## Pendências
- **Versão SAPUI5:** o S/4 alvo entrega **1.114**. O app usa 1.136 (Manifest 2.0.0, `invoke()`)
  e roda localmente com o framework 1.136.23. Para fazer deploy nesse S/4 é preciso: (a) subir o
  SAP_UI no servidor (Basis); (b) fazer o bootstrap pela CDN pinada (só demo); ou (c) fazer o
  downgrade do manifest para 1.x, com `minUI5Version 1.114` e `execute()` no lugar de `invoke()`.
- A API `/api/alpha/decisions` é "alpha": o contrato pode mudar. A validação de forma no `parseResponse` transforma qualquer mudança em INDISPONIVEL, nunca em dado errado.
- Calibrar os limiares (0,20 / 0,60) com pedidos rotulados antes de sair do modo sombra.
- 429 (limite de requisições) vira INDISPONIVEL; o lote ainda não faz backoff.
