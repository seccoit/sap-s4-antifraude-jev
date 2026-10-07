# Análise clean core — backend ZPOC_JEV

Data: 2026-10-07. Levantamento **somente leitura** (nada foi gravado no SAP).
Base: ATC variante `ABAP_CLOUD_READINESS` de 07/10/2026 → 37 achados prioridade 1 ("Usage of Released APIs") em 7 objetos, todos por leitura direta de tabelas.

## 1. API_STATE conferido (SAPRead API_STATE)

| Objeto | C1 (Cloud) | Uso pretendido |
|---|---|---|
| I_PurchaseOrderAPI01 | RELEASED (conferido pelo coordenador) | cabeçalho do pedido (substitui EKKO) |
| I_PurchaseOrderItemAPI01 | RELEASED (idem) | item (substitui EKPO) |
| I_Supplier | **RELEASED** | substitui LFA1 |
| I_SupplierPurchasingOrg | **RELEASED** | substitui LFM1 |
| I_SupplierCompany | **RELEASED** | substitui LFB1 |
| I_SupplierToBusinessPartner | **RELEASED** | substitui CVI_VEND_LINK |
| I_BusinessPartner | **RELEASED** | substitui BUT000 |
| I_BusinessPartnerBank | **RELEASED** | substitui BUT0BK (e torna LFBK desnecessário) |
| I_PurgInfoRecdOrgPlntDataApi01 | RELEASED (coord.) | substitui EINE |
| I_PurchasingInfoRecordApi01 | **RELEASED** | (opcional, cabeçalho do registro info) |
| I_MaterialDocumentItem_2 | **RELEASED** | substitui EKBE (entrada de mercadoria) |
| I_MaterialDocumentHeader_2 | **RELEASED** | usuário que lançou a EM (`CreatedByUser`) |
| I_SuplrInvcItemPurOrdRefAPI01 | **RELEASED** | substitui RSEG |
| I_SupplierInvoiceAPI01 | **RELEASED** | substitui RBKP |
| I_PurchaseOrderHistoryAPI01 | RELEASED | **não serve**: não tem usuário |
| IF_SADL_EXIT_CALC_ELEMENT_READ | **RELEASED** | elemento virtual (desvio padrão / z-score) |
| I_ChangeDocument / I_ChangeDocumentItem / I_ChangeDocUID | **NOT_RELEASED** | — |
| I_SupplierBankDetails | **NOT_RELEASED** | — (não será necessário) |

Documentos de modificação: busquei `I_*CHANGEDOC*`. Os únicos liberáveis são específicos de outros objetos (pedido, fatura, produto, projeto…). **Não há API liberada para documentos de modificação de fornecedor/BP**, então esse é o único caso que exige wrapper.

## 2. Nomes de campo confirmados (para o rebuild)

- **I_PurchaseOrderAPI01** (sobre `R_PurchaseOrder`, que já filtra `PurchasingDocumentCategory = 'F'`):
  `PurchaseOrder`, `PurchaseOrderType` (BSART), `CreatedByUser` (ERNAM), `CreationDate` (= **EKKO-AEDAT**, confirmado em `R_PurchasingDocument`), `CompanyCode`, `PurchasingOrganization`, `PurchasingGroup`, `Supplier`, `SupplyingPlant` (RESWK), `PaymentTerms`, `DocumentCurrency`, `PurchasingDocumentDeletionCode` (LOEKZ).
  O `R_PurchaseOrder` também exclui `PurchasingDocumentIsAged <> ''` (pedidos arquivados/"aged") e os bloqueados por fim de finalidade. Hoje isso não afeta nenhum pedido do escopo.
- **I_PurchaseOrderItemAPI01**: `PurchaseOrder`, `PurchaseOrderItem`, `Material`, `Plant`, `PurchasingInfoRecord`, `PurchaseOrderQuantityUnit` (MEINS), `OrderPriceUnit` (BPRME), `OrderQuantity` (MENGE), `NetPriceAmount` (NETPR), `NetPriceQuantity` (PEINH, tipo QUAN), `NetAmount` (NETWR), `DocumentCurrency`, `PurchasingDocumentDeletionCode`, `IsReturnsItem` (RETPO).
- **I_Supplier**: `Supplier`, `CreationDate` (ERDAT), `CreatedByUser` (ERNAM), `PostingIsBlocked` (SPERR), `PurchasingIsBlocked` (SPERM), `PaymentIsBlockedForSupplier` (SPERZ), `SupplierName`.
- **I_SupplierPurchasingOrg**: `Supplier`, `PurchasingOrganization`, `PaymentTerms` (ZTERM), `PurchasingIsBlockedForSupplier` (SPERM).
- **I_SupplierCompany**: `Supplier`, `CompanyCode`, `PaymentTerms` (ZTERM).
- **I_SupplierToBusinessPartner**: `Supplier`, `BusinessPartnerUUID`. **I_BusinessPartner**: `BusinessPartner`, `BusinessPartnerUUID`, `CreatedByUser` (CRUSR), `CreationDate`.
- **I_BusinessPartnerBank**: `BusinessPartner`, `BankIdentification`, `BankCountryKey`, `BankNumber`, `BankAccount`, `ValidityStartDate`, `ValidityEndDate`.
- **I_PurgInfoRecdOrgPlntDataApi01**: `PurchasingInfoRecord`, `PurchasingOrganization`, `PurchasingInfoRecordCategory` (ESOKZ), `Plant`, `NetPriceAmount`, `MaterialPriceUnitQty` (PEINH), `PurchaseOrderPriceUnit` (BPRME), `Currency`, `IsMarkedForDeletion`.
- **I_MaterialDocumentItem_2**: `MaterialDocumentYear`, `MaterialDocument`, `MaterialDocumentItem`, `PurchaseOrder`, `PurchaseOrderItem`, `GoodsMovementType`, `GoodsMovementIsCancelled`, `ReversedMaterialDocument`. **I_MaterialDocumentHeader_2**: `CreatedByUser`, `CreationDate`.
- **I_SuplrInvcItemPurOrdRefAPI01**: `SupplierInvoice`, `FiscalYear`, `PurchaseOrder`, `PurchaseOrderItem`. **I_SupplierInvoiceAPI01**: `SupplierInvoice`, `FiscalYear`, `DocumentDate` (BLDAT), `ReverseDocument` (STBLG).

## 3. Mapeamento por objeto (fonte atual → substituto)

| Objeto (achados) | Fonte atual | Substituto |
|---|---|---|
| **ZI_POC_JEV_PEDIDOITEM** (9) | EKKO, EKPO, LFA1, CVI_VEND_LINK, BUT000 | I_PurchaseOrderAPI01, I_PurchaseOrderItemAPI01, I_Supplier, I_SupplierToBusinessPartner, I_BusinessPartner |
| **ZI_POC_JEV_ITEMIND** (1) | EINE | I_PurgInfoRecdOrgPlntDataApi01 |
| **ZI_POC_JEV_FORNIND** (14) | EKKO, LFA1, LFM1, LFB1, CVI_VEND_LINK, BUT000, LFBK, BUT0BK | I_PurchaseOrderAPI01, I_Supplier, I_SupplierPurchasingOrg, I_SupplierCompany, I_SupplierToBusinessPartner, I_BusinessPartner, **I_BusinessPartnerBank** (LFBK sai) |
| **ZI_POC_JEV_FLUXODOC** (7) | EKKO, EKBE, RSEG, RBKP | I_PurchaseOrderAPI01; I_MaterialDocumentItem_2 + I_MaterialDocumentHeader_2 (EM 101 não estornada, usuário do cabeçalho); I_SuplrInvcItemPurOrdRefAPI01 + I_SupplierInvoiceAPI01 |
| **ZI_POC_JEV_ALTCAD** (2) | CDHDR, CDPOS | **wrapper** `ZI_POC_JEV_W_CHGDOC` (subpacote ZPOC_JEV_WRAP) |
| **ZR_POC_JEV_PEDIDO** (2) | EKKO + table function | I_PurchaseOrderAPI01 + novas views CDS (abaixo) |
| **ZCL_POC_JEV_HIST_AMDP** (2) | EKKO, EKPO (SQLScript) | **removida**, ver §4 |

## 4. A AMDP (ZTF_POC_JEV_HIST + ZCL_POC_JEV_HIST_AMDP)

- **Ler views liberadas dentro da AMDP:** não recomendo. Todas as APIs de pedido usam `@ClientHandling.algorithm: #SESSION_VARIABLE`. Já vimos neste projeto que uma AMDP de table function que lê view com essa característica não ativa (erro "restringe acesso a um único client"; as opções `CDS SESSION CLIENT CURRENT/DEPENDENT/p_clnt` foram recusadas para table function).
- **Transformar a AMDP no wrapper:** possível, mas manteria leitura de tabela num objeto grande e cheio de lógica de negócio. É exatamente o que o clean core quer evitar.
- **Recomendado: trocar por CDS + 1 elemento virtual.**
  - Contagem, média, velocidade 24h/7d e participação do comprador: CDS com auto-join não-equi, o mesmo padrão já usado e validado em `ZI_POC_JEV_ITEMIND`.
  - Desvio padrão e z-score: CDS não tem `sqrt`. A CDS entrega `n`, `soma` e `soma dos quadrados` (FLTP), e uma classe ABAP calcula `sqrt((Σx² − (Σx)²/n)/(n−1))` (desvio amostral, igual ao `STDDEV` do HANA).
  - Na UI, a classe implementa `IF_SADL_EXIT_CALC_ELEMENT_READ` (liberada C1). No snapshot da ação, o behavior pool usa o mesmo método estático.
  - Última avaliação: CDS sobre a tabela própria `ZPOC_JEV_AVAL`; tabela Z é permitida.

## 5. Objetos a alterar / criar / remover

### Alterar (pacote ZPOC_JEV)
| Objeto | Tipo | Mudança |
|---|---|---|
| ZI_POC_JEV_PEDIDOITEM | DDLS | fontes → APIs liberadas |
| ZI_POC_JEV_ITEMIND | DDLS | EINE → I_PurgInfoRecdOrgPlntDataApi01 |
| ZI_POC_JEV_FORNIND | DDLS | fontes → APIs liberadas; banco só via I_BusinessPartnerBank |
| ZI_POC_JEV_FLUXODOC | DDLS | EKBE/RSEG/RBKP → documento de material / fatura API |
| ZI_POC_JEV_ALTCAD | DDLS | CDHDR/CDPOS → wrapper |
| ZR_POC_JEV_PEDIDO | DDLS | EKKO → I_PurchaseOrderAPI01; TF → novas views; expõe Σ e Σ² |
| ZC_POC_JEV_PEDIDO | DDLS | `SuplrHistStdDevAmount` e `AmountZScore` viram elementos virtuais (`@ObjectModel.virtualElementCalculatedBy`) |
| ZBP_R_POC_JEV_PEDIDO | CLAS | snapshot do desvio/z-score via método da classe de estatística |
| ZUI_POC_JEV / ZUI_POC_JEV_O4 | SRVD/SRVB | só reativar/republicar (contrato do serviço inalterado) |

### Criar
| Objeto | Tipo | Pacote | Propósito |
|---|---|---|---|
| ZI_POC_JEV_PEDIDOVALOR | DDLS | ZPOC_JEV | 1 linha por pedido: fornecedor, criador, data, moeda, valor total, datas-limite |
| ZI_POC_JEV_HISTFORN | DDLS | ZPOC_JEV | por pedido: n, Σ, Σ² do valor (24m, anteriores, mesma moeda); pedidos em D-1..D e D-7..D |
| ZI_POC_JEV_COMPRADOR | DDLS | ZPOC_JEV | valor do comprador (ERNAM) total e com o fornecedor (12m, mesma moeda) |
| ZI_POC_JEV_ULTAVAL | DDLS | ZPOC_JEV | última avaliação (timestamp máx. e contagem) sobre ZPOC_JEV_AVAL |
| ZCL_POC_JEV_STATS | CLAS | ZPOC_JEV | desvio padrão / z-score: elemento virtual + método estático |
| ZPOC_JEV_WRAP | DEVC | sub de ZPOC_JEV | camada de wrappers |
| ZI_POC_JEV_W_CHGDOC | DDLS | ZPOC_JEV_WRAP | wrapper sobre documentos de modificação, já filtrado (KRED, BUPA_BUP, BUPA_BANK, BUPA_ADR; tabelas LFBK, BUT0BK, BUT020, BUT021_FS, ADRC e campos de endereço da LFA1). Expõe só objeto, nº do documento, data e tabela. API_STATE → RELEASED C1 via `SAPManage set_api_state` |

### Remover
| Objeto | Tipo | Motivo |
|---|---|---|
| ZTF_POC_JEV_HIST | DDLS (table function) | substituída por CDS |
| ZCL_POC_JEV_HIST_AMDP | CLAS | idem |

Saldo: 9 alterados, 7 criados (incluindo o subpacote), 2 removidos.

## 6. Impacto nos indicadores

| Indicador | Muda? | Detalhe |
|---|---|---|
| Todos de pedido/item/fatura/EM/registro info | Não esperado | mesmas fontes físicas, via APIs |
| Conta bancária compartilhada | **Pequena mudança** | passa a contar só **BPs** (BUT0BK). Hoje `SharedBankOtherCount = max(LFBK, BUT0BK)`. Em S/4 a LFBK é sincronizada da BUT0BK pela CVI, então o valor deve ser igual (no caso 4500001649: 3 = 3). Um BP que é só cliente (não fornecedor) passaria a contar — antes também contava via BUT0BK. |
| Criador registrou EM | **Pequena mudança** | antes: EKBE VGABE=1 com ERNAM, incluindo estornos. Depois: documento de material de EM (101) não estornado, usuário do cabeçalho. É mais correto (estorno não conta mais). |
| Pedido criado após fatura | Não | BLDAT/STBLG → DocumentDate/ReverseDocument |
| Pedidos no escopo | Quase nada | `R_PurchaseOrder` exclui pedidos "aged" e bloqueados por fim de finalidade |
| Desvio padrão / z-score | Não (valor) | mesmo desvio amostral. Diferença de arredondamento ≤ 0,01. **Na UI deixam de ser filtráveis/ordenáveis** (elemento virtual). |
| Alterações cadastrais 30d | Não | mesma lógica, atrás do wrapper |
| Nenhum indicador some | — | — |

## 7. Regressão: como validar

**Linha de base "antes"** (capturada agora, view `ZR_POC_JEV_PEDIDO`):

| Pedido | Forn. | Valor | Idade forn. | Criador forn.=ped. | Conta compart. (n) | Hist. n / média / desvio | Valor/média | Z | Preço/RI | Preço/média mat. | Mat. novo | Pós-fatura | 24h / 7d | % comprador | Criador EM | Últ. classif. / risco / nº |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 4500001403 | 0014300001 | 49.500,00 BRL | 1266 | — | — (0) | 1 / 500,00 / 0,00 | 99,0000 | 0 | 0,9000 | 0 | X | — | 1 / 2 | 100,00 | — | APROVACAO / 0,28 / 3 |
| 4500001649 | 0017300030 | 1.000,00 USD | 1314 | — | X (3) | 0 / 0 / 0 | 0 | 0 | 0 | 0,3673 | X | — | 1 / 1 | 32,59 | X | — / 0 / 0 |
| 4500001366 | 0000000321 | 1.000,00 BRL | 0 | X | — (0) | 0 / 0 / 0 | 0 | 0 | 0 | 0 | X | — | 0 / 0 | 100,00 | — | BLOQUEIA / 0,87 / 2 |
| 4500001545 | 0000000335 | 10,00 BRL | 0 | X | — (0) | 0 / 0 / 0 | 0 | 0 | 0 | 0 | — | X | 0 / 0 | 100,00 | — | BLOQUEIA / 0,87 / 1 |

Itens (base `ZI_POC_JEV_ITEMIND`): 4500001403/10 e /20 com preço 450 e RI 500; 4500001649/10 com 79 pedidos históricos do material e preço médio 27,2222; os demais sem histórico.

**Procedimento:**
1. Salvar esta linha de base (feito).
2. Depois do rebuild, rodar a mesma consulta em `ZR_POC_JEV_PEDIDO` e `ZI_POC_JEV_ITEMIND` e comparar campo a campo.
3. Comparar contagens globais: nº de pedidos no root, nº de pedidos com conta compartilhada, nº com "criador registrou EM" e nº com "pós-fatura". Diferença só é aceita se explicada pelo §6.
4. Pelo serviço: `Pedido('4500001649')` com `$expand=_Item,_Avaliacao` e conferência de `SuplrHistStdDevAmount`/`AmountZScore` (agora virtuais).
5. Testar `registrarAvaliacao` e conferir o snapshot na `ZPOC_JEV_AVAL`.
6. Rodar o ATC `ABAP_CLOUD_READINESS` de novo em ZPOC_JEV e ZPOC_JEV_WRAP.

## 8. ATC esperado depois

- **ZPOC_JEV (núcleo): 0 achados** de "Usage of Released APIs". Todas as fontes passam a ser APIs C1, tabelas Z próprias ou objetos Z.
- **ZPOC_JEV_WRAP: restam os achados do wrapper** (leitura de I_ChangeDocument/I_ChangeDocumentItem ou CDHDR/CDPOS, 2 a 4 achados). São **justificados**: é o padrão oficial "Tier 2 wrapper", isolado num subpacote, com contrato C1 próprio e consumido só pelo núcleo. Se o ATC for usado como gate, pedir exceção (exemption) para esses objetos, ou excluir o subpacote da variante.
- **Próximo passo opcional** (fora deste escopo): mudar a versão de linguagem dos objetos do núcleo para "ABAP for Cloud Development". O wrapper continua em "Standard ABAP".

## 9. Riscos
- `I_*API01` e `I_Supplier` têm DCL `#CHECK`. Usadas como fonte dentro de views Z, a DCL delas **não** é aplicada (vale a da view do topo, que continua `#NOT_REQUIRED`). Comportamento de autorização inalterado.
- Performance: as views liberadas trazem joins extras (R_PurchasingDocument, endereço do fornecedor etc.). O volume da POC é pequeno, então não deve pesar; medir com `odata_perf` antes/depois.
- Elemento virtual: o front não pode filtrar/ordenar por desvio padrão ou z-score.
- `set_api_state` C1 num objeto Z que lê APIs não liberadas é o uso pretendido do padrão wrapper. Se o sistema recusar a liberação, o wrapper fica sem contrato e o núcleo ainda gera achado — validar logo no primeiro passo.

## 10. Perguntas para aprovação
1. **Transporte:** usar a mesma ordem **S4HK913463** ou uma nova?
2. **Subpacote:** posso criar `ZPOC_JEV_WRAP` como subpacote de ZPOC_JEV (mesma camada de transporte)?
3. Aceita trocar a AMDP por CDS + elemento virtual (desvio/z-score deixam de ser filtráveis na UI)?
4. Aceita as duas pequenas mudanças de semântica (conta compartilhada só via BP; EM sem estornos)?
5. Wrapper sobre `I_ChangeDocument`/`I_ChangeDocumentItem` (recomendado, menos acoplado) ou direto sobre CDHDR/CDPOS?

---

## 11. Resultado da execução (2026-10-07)

Aprovado pelo usuário: transporte **S4HK913463**, subpacote `ZPOC_JEV_WRAP`, AMDP trocada por CDS + campo calculado, as duas mudanças de semântica, e o wrapper lendo `I_ChangeDocument`/`I_ChangeDocumentItem`.

### O que foi feito
| Passo | Resultado |
|---|---|
| Subpacote `ZPOC_JEV_WRAP` (sub de ZPOC_JEV, componente HOME, camada ZS4H) | criado |
| `ZI_POC_JEV_W_CHGDOC` (wrapper sobre I_ChangeDocument/I_ChangeDocumentItem) | criado, ativo, **API_STATE C1 = RELEASED** (o SAP aceitou) |
| Novas views `ZI_POC_JEV_PEDIDOVALOR`, `ZI_POC_JEV_HISTFORN`, `ZI_POC_JEV_COMPRADOR`, `ZI_POC_JEV_ULTAVAL` | criadas e ativas |
| `ZCL_POC_JEV_STATS` (elemento virtual + método estático) | criada e ativa |
| `ZI_POC_JEV_PEDIDOITEM`, `ITEMIND`, `FORNIND`, `ALTCAD`, `FLUXODOC`, `ZR_POC_JEV_PEDIDO`, `ZC_POC_JEV_PEDIDO` (+DDLX), `ZBP_R_POC_JEV_PEDIDO` | alterados e ativos, só com APIs liberadas, objetos Z ou o wrapper |
| SRVD `ZUI_POC_JEV` / SRVB `ZUI_POC_JEV_O4` | reativados, publicados |
| `ZTF_POC_JEV_HIST` e `ZCL_POC_JEV_HIST_AMDP` | **removidos**, depois de o where-used mostrar só referência mútua |

**Desvio de implementação:** a `division()` do CDS arredonda, enquanto o `CAST(... AS DECIMAL)` da antiga AMDP truncava. A primeira versão divergiu no último dígito de `SuplrHistAvgAmount` (10555.07 × 10555.06), `AmountToSuplrAvgRatio` (5.6845 × 5.6844) e `BuyerSupplierSharePct` (32.60 × 32.59). Para preservar os valores, esses três campos, o desvio padrão e o z-score passaram a ser **truncados** como antes.

### Regressão (antes × depois)
- **4 pedidos (4500001403, 4500001649, 4500001366, 4500001545): todos os campos idênticos** à linha de base da §7, incluindo a última avaliação gravada.
- **Desvio padrão / z-score** (não existiam valores ≠ 0 nos 4 pedidos, então validei com 4500001410 e 4500001426 contra a TF antiga ainda ativa): 37366.07 / 1.3232 e 35563.79 / 0.1934, **idênticos**.
- **Itens** (`ZI_POC_JEV_ITEMIND`) dos 4 pedidos: idênticos (preço 450 × RI 500; 79 pedidos históricos do material com média 27,2222 em 4500001649).
- **Global:** a raiz tem **288 pedidos antes e depois**, na mesma sequência e com os mesmos valores de histórico e de pedidos em 7 dias. Conta compartilhada: os mesmos 4 pedidos (1550: 2, 1610: 2, 1649: 3, 1650: 3). Pós-fatura: os mesmos 5 (1306, 1545, 1622, 1631, 1650). Criador lançou EM: os mesmos 49.
- **Mudanças de semântica aprovadas** (conta compartilhada só via BP; EM sem estornos): **nenhum valor mudou** nos dados atuais.

### ATC `ABAP_CLOUD_READINESS` (todos os objetos dos dois pacotes)
| Objeto | Achados |
|---|---|
| 15 DDLS do núcleo (ZA_/ZC_/ZI_/ZR_) | 0 |
| ZBP_R_POC_JEV_PEDIDO, ZCL_POC_JEV_SETUP, ZCL_POC_JEV_STATS | 0 |
| ZPOC_JEV_AVAL, ZPOC_JEV_CFG | 0 |
| BDEF ZR/ZC_POC_JEV_PEDIDO, 3 DDLX, SRVD ZUI_POC_JEV, SRVB ZUI_POC_JEV_O4 | 0 |
| **ZI_POC_JEV_W_CHGDOC** (ZPOC_JEV_WRAP) | **2** (prio 1, "Usage of not released ABAP Platform APIs": I_ChangeDocument e I_ChangeDocumentItem) |

**Antes: 37 achados em 7 objetos. Depois: 0 no núcleo; 2 justificados no wrapper.** É o padrão Tier 2: wrapper isolado em subpacote, com contrato C1 próprio e consumido só por `ZI_POC_JEV_ALTCAD`. Se o ATC for gate, registrar exemption para esses 2 achados.

### Serviço
`$metadata`, lista de `Pedido` (inclusive com os campos virtuais no `$select`) e `Pedido('4500001410')` com `$expand=_Item,_Avaliacao` respondem HTTP 200. Hoje não há dumps (ST22) nem erros de gateway do serviço.
A ação `registrarAvaliacao` não foi chamada (as ferramentas só fazem GET). O behavior pool foi ativado e passou no ATC; o snapshot do z-score agora usa `ZCL_POC_JEV_STATS=>zscore`.

### Pendências
- Testar `registrarAvaliacao` com POST (Postman ou preview do FE) e conferir `SnapAmountZScore` na `ZPOC_JEV_AVAL`.
- Exemption do ATC para os 2 achados do wrapper, se o ATC for usado como gate.
- (Opcional) Mudar a versão de linguagem do núcleo para "ABAP for Cloud Development".
