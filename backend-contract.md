# Contrato do backend — POC antifraude (ZPOC_JEV)

Status em 2026-10-07: **ativo e publicado** (pacote `ZPOC_JEV` + subpacote `ZPOC_JEV_WRAP`, transporte `S4HK913463`).

> **Refatoração clean core (07/10/2026): o contrato do front NÃO mudou.** Os nomes de entidades, campos, navegações, ação e parâmetros são os mesmos, e os valores são idênticos aos de antes (regressão em `clean-core-analysis.md` §11).
> Há três diferenças, todas não quebrantes:
> 1. `SuplrHistStdDevAmount` e `AmountZScore` agora são **campos calculados (elementos virtuais)**: aparecem normalmente no `$select`/resposta, mas **não servem para `$filter` nem `$orderby`**.
> 2. Dois campos técnicos novos em `Pedido`, ocultos na UI: `SuplrHistSumAmount` (Decimal 15,2) e `SuplrHistSumSqAmount` (Double), usados para calcular os dois campos acima. O front pode ignorá-los.
> 3. Semântica: `SharedBankAccount`/`SharedBankOtherCount` contam só pelo cadastro do BP; `CreatorPostedGR` ignora recebimentos estornados. Nos dados atuais, os valores não mudaram.

## Endpoint

```
/sap/opu/odata4/sap/zui_poc_jev_o4/srvd/sap/zui_poc_jev/0001/
```
- Service binding `ZUI_POC_JEV_O4` (OData V4 - UI), service definition `ZUI_POC_JEV`, versão `0001`.
- `$metadata` responde 200. Namespace do schema: `com.sap.gateway.srvd.zui_poc_jev.v0001`.
- Regra: confira os tipos Edm exatos no `$metadata`. A tabela abaixo dá o tipo ABAP e o Edm esperado.

## Entity sets

| Entity set | CDS | Chave | Navegações |
|---|---|---|---|
| `Pedido` | `ZC_POC_JEV_PEDIDO` (raiz RAP, só leitura + ação) | `PurchaseOrder` (Edm.String, 10, com zeros: `'4500001403'`) | `_Avaliacao` (0..*, composição → `Avaliacao`), `_Item` (0..* → `Item`) |
| `Avaliacao` | `ZC_POC_JEV_AVAL` (filha, só leitura) | `EvaluationUUID` (Edm.Guid) | `_Pedido` (1 → `Pedido`) |
| `Item` | `ZC_POC_JEV_ITEM` (só leitura) | `PurchaseOrder` + `PurchaseOrderItem` (Edm.String 5, ex. `'00010'`) | — |
| `SupplierVH`, `CompanyCodeVH`, `PurchasingOrganizationVH`, `PurchasingGroupVH` | value helps padrão | — | — |

Escopo dos pedidos: EKKO `BSTYP='F'`, `BSART='NB'`, sem intercompany (`RESWK=''`), sem eliminados. Itens sem eliminação e sem devolução.
O único texto identificador é `SupplierName`, usado só na exibição. Nenhum indicador traz CNPJ, endereço ou banco em texto, e o payload do Jev não deve incluir `SupplierName`.

**Botão da ação:** o serviço **não** anota a ação na UI: não há `#FOR_ACTION` no lineItem nem na identification. O front cria o próprio botão "Avaliar com Jev" e chama a ação por código.

**Tipos Edm:** os tipos marcados como "esperado" seguem o mapeamento padrão do RAP V4 (abap_boolean → Edm.Boolean, int1 → Edm.Byte, int4 → Edm.Int32, dec(p,s) → Edm.Decimal Precision p / Scale s, dats → Edm.Date, timestampl → Edm.DateTimeOffset ou Edm.Decimal, sysuuid_x16 → Edm.Guid). O `$metadata` responde HTTP 200, mas **o conteúdo não foi lido**: a ferramenta disponível retorna só status e tempos. Antes de codificar, o front deve abrir `.../0001/$metadata` e conferir pelo menos: os campos booleanos de `Pedido`/`Item`/`Avaliacao`, `Atipicidade` e os parâmetros da ação `registrarAvaliacao`.

## Pedido: campos

| Campo | Tipo ABAP → Edm | Significado |
|---|---|---|
| PurchaseOrder | ebeln → String(10) | chave |
| Supplier | lifnr → String(10) | código do fornecedor; `@ObjectModel.text.element: SupplierName` + `@UI.textArrangement: #TEXT_FIRST` (a UI mostra "Nome (código)") |
| SupplierName | md_supplier_name → String(80) | **novo**: nome do fornecedor (via `_Supplier` → `I_Supplier.SupplierName`). **Só para exibição: NÃO enviar no payload do Jev.** Também existe em `Item`. |
| CreatedByUser | ernam → String(12) | criador do pedido (= "comprador") |
| CreationDate | dats → Date | data de criação (EKKO-AEDAT) |
| CompanyCode, PurchasingOrganization, PurchasingGroup | String | organização |
| PaymentTerms / SupplierDefaultPaymentTerms | String(4) | condição do pedido / padrão do fornecedor (LFM1, fallback LFB1) |
| DocumentCurrency | waers → String(5) | moeda |
| POTotalAmount | dec(15,2) → Decimal | soma do NETWR dos itens |
| **Fornecedor** | | |
| SupplierAgeDays | int4 → Int32 | idade do cadastro na data do pedido (dias) |
| SupplierCreatorIsPOCreator | abap_boolean → Boolean | LFA1-ERNAM ou BUT000-CRUSR = criador do pedido |
| SupplierIsBlocked | abap_boolean → Boolean | LFA1-SPERR/SPERM/SPERZ ou LFM1-SPERM |
| MasterDataChanges30d | int4 → Int32 | documentos de modificação de banco/endereço em [D-30, D] (KRED, BUPA_BUP, BUPA_BANK, BUPA_ADR), sem contar o dia da criação |
| DaysSinceLastMDChange | int4 → Int32 | dias desde a última alteração dentro da janela; **-1 = nenhuma** |
| SharedBankAccount | abap_boolean → Boolean | a conta é usada por outro BP (I_BusinessPartnerBank / BUT0BK) |
| SharedBankOtherCount | int4 → Int32 | nº de outros BPs com a mesma conta |
| SuplrHistPOCount | int4 → Int32 | pedidos anteriores ao fornecedor (24 meses, mesma moeda) |
| SuplrHistAvgAmount | dec(15,2) → Decimal | média do valor desses pedidos (truncada em 2 casas) |
| SuplrHistStdDevAmount | dec(15,2) → Decimal | desvio padrão amostral, **campo calculado** (`ZCL_POC_JEV_STATS`): não filtrável nem ordenável |
| SuplrHistSumAmount / SuplrHistSumSqAmount | dec(15,2) / fltp → Decimal / Double | técnicos (ocultos na UI): soma e soma dos quadrados, base do desvio e do z-score |
| **Pedido** | | |
| AmountToSuplrAvgRatio | dec(11,4) → Decimal | valor / média do fornecedor (0 = sem histórico) |
| AmountZScore | dec(11,4) → Decimal | (valor - média) / desvio (0 se desvio = 0), **campo calculado**: não filtrável nem ordenável |
| MaxPriceToInfoRecordRatio | dec(15,4) → Decimal | pior item: preço unitário / registro info (0 = não comparável) |
| MaxPriceToMaterialAvgRatio | dec(15,4) → Decimal | pior item: preço / média histórica do material (24m, mesma moeda e unidade de preço) |
| MaxQtyToHistRatio | dec(15,4) → Decimal | pior item: quantidade / média do fornecedor+material |
| MaterialNewForSupplier | abap_boolean → Boolean | algum material nunca comprado desse fornecedor |
| PaymentTermsDiverge | abap_boolean → Boolean | condição do pedido ≠ padrão do fornecedor |
| InvoiceBeforePO | abap_boolean → Boolean | existe fatura não estornada com data do documento anterior à criação do pedido |
| **Velocidade / comprador** | | |
| SuplrPOCount24h | int4 → Int32 | outros pedidos ao fornecedor em D-1..D (aproximação por data) |
| SuplrPOCount7d | int4 → Int32 | outros pedidos ao fornecedor em D-7..D |
| BuyerSupplierSharePct | dec(7,2) → Decimal | % do fornecedor nas compras do criador (12 meses, mesma moeda) |
| CreatorPostedGR | abap_boolean → Boolean | o criador do pedido lançou entrada de mercadoria (documento de material 101 não estornado) |
| **Regra / última avaliação** | | |
| RuleClassification | char15 → String | `BLOQUEIO_REGRA` (fornecedor bloqueado: **não chamar o Jev**) ou `AVALIAR_JEV` |
| LastAvalTimestamp | timestampl → Decimal(21,7) | timestamp da última avaliação (0 = nenhuma) |
| LastClassification | char15 → String | última classificação ABAP (vazio = nunca avaliado) |
| LastRiskMax | dec(5,4) → Decimal | último risco máximo |
| EvaluationCount | int4 → Int32 | nº de avaliações gravadas |
| **Semáforos** (1 vermelho, 2 amarelo, 3 verde, 0 neutro) | int → Int32 | `SupplierAgeCriticality` (<90 d = 1, <365 = 2), `MDChangeCriticality`, `SharedBankCriticality`, `PriceCriticality` (>1,20 = 1, >1,05 = 2), `RuleCriticality`, `ClassificationCriticality` |

## Item: campos
`PurchaseOrder`, `PurchaseOrderItem`, `Supplier`, `CreationDate`, `Material`, `Plant`, `PurchasingInfoRecord`, `DocumentCurrency`,
`OrderUnit`, `OrderPriceUnit`, `OrderQuantity` (dec 13,3), `NetAmount` (dec 15,2), `UnitPrice` (dec, NETPR/PEINH),
`InfoRecordUnitPrice`, `HistMaterialPOCount`, `HistMaterialAvgUnitPrice`, `HistSuplrMaterialItemCount`, `HistSuplrMaterialAvgQty`,
`PriceToInfoRecordRatio`, `PriceToMaterialAvgRatio`, `QtyToHistRatio`, `MaterialNewForSupplier` (Boolean), `PriceCriticality`.

## Avaliacao: campos
`EvaluationUUID` (Guid), `PurchaseOrder`, `EvaluatedAt` (timestampl), `EvaluatedBy`;
snapshot `SnapSupplierAgeDays`, `SnapMDChanges30d`, `SnapSharedBankOtherCount`, `SnapAmountToSuplrAvgRatio`, `SnapAmountZScore`,
`SnapPriceToInfoRecordRatio`, `SnapPriceToMaterialAvgRatio`, `SnapQtyToHistRatio`, `SnapMaterialNewForSupplier`, `SnapPaymentTermsDiverge`,
`SnapInvoiceBeforePO`, `SnapCreatorPostedGR`, `SnapSupplierCreatorIsPOCreator`, `SnapSuplrPOCount24h`, `SnapSuplrPOCount7d`, `SnapBuyerSupplierSharePct`;
Jev `JevDisponivel`, `ProbFornecedorFicticio`, `ProbDesvioPagamento`, `ProbSobrepreco`, `ProbFracionamento`, `ProbFraudeInterna`, `Atipicidade`,
`JevAcaoSugerida`, `JevProbLiberar`, `JevProbAprovacao`, `JevProbBloquear`, `JevModeloVersao`;
ABAP `RiscoMax`, `ChaveRiscoMax`, `Classificacao`, `ClassificacaoCriticality`, `LimiarAprovacaoUsado`, `LimiarBloqueioUsado`, `ModoSombra`;
decisão (fase 2, só leitura por enquanto) `DecisaoAprovador`, `Aprovador`, `DecisaoTimestamp`, `DecisaoObservacao`; `LocalLastChangedAt`.

## Ação `registrarAvaliacao` (bound em `Pedido`)

```
POST .../0001/Pedido('4500001403')/com.sap.gateway.srvd.zui_poc_jev.v0001.registrarAvaliacao
Content-Type: application/json
X-CSRF-Token: <token>     (obter antes com GET + header "X-CSRF-Token: Fetch")

{
  "JevDisponivel": true,
  "ProbFornecedorFicticio": 0.05,
  "ProbDesvioPagamento": 0.10,
  "ProbSobrepreco": 0.42,
  "ProbFracionamento": 0.08,
  "ProbFraudeInterna": 0.03,
  "Atipicidade": 3,
  "JevAcaoSugerida": "APROVACAO",
  "JevProbLiberar": 0.30,
  "JevProbAprovacao": 0.55,
  "JevProbBloquear": 0.15,
  "JevModeloVersao": "jev-2026.10"
}
```
No UI5/Fiori Elements V4: `oModel.bindContext("com.sap.gateway.srvd.zui_poc_jev.v0001.registrarAvaliacao(...)", oPedidoContext)`, `setParameter(...)` para cada campo e `execute()`.

| Parâmetro | Tipo ABAP → Edm | Regra |
|---|---|---|
| JevDisponivel | abap_boolean → Boolean | `false` → classificação `INDISPONIVEL` (probabilidades ignoradas) |
| ProbFornecedorFicticio, ProbDesvioPagamento, ProbSobrepreco, ProbFracionamento, ProbFraudeInterna | dec(5,4) → Decimal(5,4) | 0..1 (validado quando JevDisponivel = true) |
| Atipicidade | int1 → Byte | 1..5 (validado quando JevDisponivel = true) |
| JevAcaoSugerida | char12 → String(12) | `LIBERAR` / `APROVACAO` / `BLOQUEAR` (gravado em maiúsculas) |
| JevProbLiberar, JevProbAprovacao, JevProbBloquear | dec(5,4) → Decimal(5,4) | 0..1 |
| JevModeloVersao | char30 → String(30) | livre |

Decimal(5,4) aceita no máximo 4 casas: arredonde no front (ex.: `0.4237`).

**Comportamento:**
1. Se `RuleClassification = BLOQUEIO_REGRA`, grava `BLOQUEIO_REGRA` (risco 1, chave `FORNECEDOR_BLOQUEADO`), qualquer que seja o payload.
2. Se `JevDisponivel = false`, grava `INDISPONIVEL`.
3. Nos demais casos, `RiscoMax` = maior das 5 probabilidades e `ChaveRiscoMax` = `FORNECEDOR_FICTICIO` | `DESVIO_PAGAMENTO` | `SOBREPRECO` | `FRACIONAMENTO` | `FRAUDE_INTERNA`.
   A classificação sai pelos limiares: `< LIMIAR_APROVACAO` → `LIBERA`; `<= LIMIAR_BLOQUEIO` → `APROVACAO`; acima → `BLOQUEIA`.
   Os limiares vêm da tabela `ZPOC_JEV_CFG`; se não houver linha, valem as constantes 0,20 / 0,60.
4. Sempre grava `ModoSombra = true` com o snapshot dos indicadores. Nada é bloqueado no pedido real.
5. Retorno: o próprio `Pedido` (result `$self`), mais uma mensagem de sucesso em `sap-messages`. Erros de faixa voltam como HTTP 400 com mensagem.
6. Cada chamada cria uma linha nova (log com UUID). O histórico aparece em `Pedido(...)/_Avaliacao`.
   `LastClassification` e `LastRiskMax` na lista refletem a última linha gravada.

## Fluxo esperado no front
1. Listar `Pedido` (filtros: Supplier, CreatedByUser, CreationDate, CompanyCode, PurchasingOrganization, RuleClassification, LastClassification).
2. Para pedidos com `RuleClassification = 'AVALIAR_JEV'`, montar o payload do Jev com os indicadores do `Pedido` (e, se quiser, `_Item`).
3. Chamar o Jev. Em sucesso, mandar as probabilidades na ação. Em falha ou timeout, chamar a ação com `JevDisponivel: false`.
4. Para `BLOQUEIO_REGRA`, não chamar o Jev. Opcionalmente chame a ação (com `JevDisponivel: false`) só para registrar no log.
