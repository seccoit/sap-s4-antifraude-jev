# Gap analysis — POC antifraude em pedidos de compra (ZPOC_JEV)

Levantado em 2026-10-06 via ARC-1, **somente leitura**. Nenhum objeto foi criado.
Sistema: S/4HANA on-prem, ABAP 758, HANA, RAP e OData V4 disponíveis. Pacote `ZPOC_JEV` existe e está vazio
(nenhum objeto `ZPOC_JEV*` encontrado).

---

## 1. "Planta" (serviço C_* de referência)

- O app standard "Gerenciar pedidos" é OData **V2** (`C_PURCHASEORDER_FS_SRV`), que não existe como SRVD neste sistema.
  Não há serviço V4 `C_*` de pedido de compra para servir de planta. As SRVD encontradas com `*PURCHASEORDER*` são
  `API_PURCHASEORDER_2` (A2X, integração, **não usar na UI**), `UI_CFINRPLDPURCHASEORDER` (Central Finance, fora de escopo)
  e serviços Z de outros projetos (`ZC_PURCHASEORDER_SD_EBG`, `ZUI_PURCHASEORDER_O4_CPB`), que **não** vamos reaproveitar.
- Conclusão: a "lista de compras" vem das **CDS públicas de interface (VDM)** abaixo; o serviço próprio é obrigatório.

## 2. Dados no sistema (checados com TABLE_QUERY)

| Fonte | Achado |
|---|---|
| EKKO (BSTYP=F) | Há pedidos reais (`4500001306`…`4500001411`, 2026), fornecedores `0001000182`, `EWM17-SU01`, `0014300001`, `FOR1983-1`; vários criadores (ERNAM). Numeração ~1.400 pedidos → volume pequeno, ok para self-joins. |
| EKPO | Itens com material, NETPR/PEINH, INFNR preenchido (ex.: `4500001403` preço 450 vs registro info 500). EBELN `46*`/`60*` são contratos/outros tipos → filtrar `BSTYP = 'F'`. |
| EINE | Registros info com NETPR/PEINH/BPRME/WAERS por EKORG/WERKS (há casos com WERKS vazio e preço 0). |
| LFA1 | ERDAT/ERNAM/SPERR/SPERM preenchidos. Nenhum bloqueio nos fornecedores testados. |
| LFM1 | ZTERM por org. de compras (ex.: `0001000182`: 0001 em 1410, 0004 em 1710). |
| BUT0BK | **Conta bancária compartilhada existe nos dados demo**: uma mesma conta (BR/****/****) em 7 BPs (`0014300003`, `…011`, `…012`, `…030`–`…033`). Ótimo caso de teste. |
| CDHDR/CDPOS | Objetos presentes: `KRED` (LFA1, LFBK), `BUPA_BUP` (BUT100/BUT0BK), `BUPA_ADR` (BUT020), `ADRESSE` (ADRC). TCDOB confirma: BUT0BK em `BUPA_BUP`/`BUPA_BANK`, LFBK em `KRED`/`KRED_N`, BUT020 em `BUPA_ADR`. |
| EKBE | Tem **ERNAM e CPUDT** por documento de histórico; VGABE 1=EM (BWART 101), 2=fatura. Simplifica "criador também registra recebimento". |
| RSEG | Faturas referenciando pedidos `45*`. |
| EKKO tempo | **Não existe hora de criação** em EKKO (só `LASTCHANGEDATETIME`). Velocidade "24h" fica por data (ver §6). |
| Anomalia | EKBE referencia `4500001302/1303`, mas a consulta em EKKO por esses números voltou vazia (cabeçalho apagado/arquivado?). A view raiz parte de EKKO, então esses ficam fora. |

## 3. O que reaproveitar (standard, nomes de campo confirmados)

| Necessidade | CDS standard | Campos confirmados | Uso |
|---|---|---|---|
| Cabeçalho do pedido | `I_PurchaseOrderAPI01` (define view, sobre R_PurchaseOrder) | `PurchaseOrder`, `PurchaseOrderType`, `CreatedByUser`, `CreationDate`, `PurchaseOrderDate`, `CompanyCode`, `PurchasingOrganization`, `PurchasingGroup`, `Supplier`, `PaymentTerms`, `DocumentCurrency`, `PurchasingDocumentDeletionCode`, `LastChangeDateTime` | base da raiz |
| Item do pedido | `I_PurchaseOrderItemAPI01` | `PurchaseOrder`, `PurchaseOrderItem`, `Material`, `Plant`, `OrderQuantity`, `PurchaseOrderQuantityUnit`, `NetPriceAmount`, `NetPriceQuantity`, `OrderPriceUnit`, `NetAmount`, `DocumentCurrency`, `PurchasingInfoRecord`, `PurchasingDocumentDeletionCode`, `IsReturnsItem` | itens, preço, histórico |
| Fornecedor | `I_Supplier` (sobre LFA1) | `Supplier`, `CreationDate`, `CreatedByUser`, `PostingIsBlocked` (SPERR), `PurchasingIsBlocked` (SPERM), `PaymentIsBlockedForSupplier`, `DeletionIndicator`, `SupplierAccountGroup` | idade, criador, regra dura |
| Fornecedor x org. compras | `I_SupplierPurchasingOrg` (LFM1) | `Supplier`, `PurchasingOrganization`, `PaymentTerms`, `PurchasingIsBlockedForSupplier` | condição de pagamento padrão, bloqueio por org. |
| Fornecedor → BP | `I_SupplierToBusinessPartner` (CVI_VEND_LINK) | `Supplier`, `BusinessPartnerUUID`, `_BusinessPartner` | casar KRED x BUPA nos documentos de modificação |
| Banco do fornecedor | `I_SupplierBankDetails` (LFBK) | `Supplier`, `BankCountry`, `Bank`, `BankAccount`, `IBAN` | conta compartilhada (só chave técnica, nada exibido) |
| Banco do BP | `I_BusinessPartnerBank` (BUT0BK) | existe (nomes a confirmar no build) | idem, lado BP |
| Registro info | `I_PurchasingInfoRecordApi01` + `I_PurgInfoRecdOrgPlntDataApi01` | `PurchasingInfoRecord`, `Supplier`, `Material`, `IsDeleted`; org/planta: `PurchasingOrganization`, `Plant`, `NetPriceAmount`, `MaterialPriceUnitQty`, `PurchaseOrderPriceUnit`, `Currency`, `IsMarkedForDeletion` | preço vs registro info |
| Documentos de modificação | `I_ChangeDocument` (CDHDR) / `I_ChangeDocumentItem` (CDPOS) | `ChangeDocObjectClass`, `ChangeDocObject`, `ChangeDocument`, `CreatedByUser`, `CreationDate`, `CreationTime`; item: `DatabaseTable`, `ChangeDocDatabaseTableField`, `ChangeDocItemChangeType` | alterações banco/endereço |
| Fatura | `I_SupplierInvoiceAPI01` + `I_SuplrInvcItemPurOrdRefAPI01` | `SupplierInvoice`, `FiscalYear`, `DocumentDate`, `PostingDate`, `CreationDate`, `ReverseDocument`; item: `PurchaseOrder`, `PurchaseOrderItem` | pedido criado depois da fatura |
| Histórico do pedido | `I_PurchaseOrderHistoryAPI01` | `PurchasingHistoryCategory`, `GoodsMovementType`, `PostingDate`, `DocumentDate`, `AccountingDocumentCreationDate` — **sem usuário** | (não serve para o usuário) |
| Documento de material | `I_MaterialDocumentItem_2` + `I_MaterialDocumentHeader_2` | item: `PurchaseOrder`, `PurchaseOrderItem`, `GoodsMovementType`, `PostingDate`; cabeçalho: `CreatedByUser`, `CreationDate` | alternativa para "comprador registra EM" |
| Value helps | `I_Supplier_VH`, `I_PurchasingOrganization`, `I_PurchasingGroup`, `I_CompanyCodeVH`, `I_ProductVH`, `I_PaymentTermsText` | existem | filtros do List Report |

Observação: `I_PurchaseOrderAPI01`/`ItemAPI01`/`I_Supplier` têm DCL (`#CHECK`). Nas views Z usaremos
`@AccessControl.authorizationCheck: #NOT_REQUIRED` na POC (ver riscos).

## 4. Indicadores: viáveis vs simplificados vs fora

| # | Indicador | Fonte | Status POC | Como |
|---|---|---|---|---|
| F1 | Idade do cadastro (dias) | LFA1.ERDAT (`I_Supplier.CreationDate`) | **Viável** | `dats_days_between(Supplier.CreationDate, PO.CreationDate)` (idade *na data do pedido*; também pode-se expor vs hoje) |
| F2 | Criador do fornecedor = criador do pedido | LFA1.ERNAM, BUT000.CRUSR, EKKO.ERNAM | **Viável** | flag; usar LFA1.ERNAM e, se vazio/usuário técnico, BUT000 via `I_SupplierToBusinessPartner._BusinessPartner` |
| F3 | Alterações banco/endereço em 30 dias + dias desde a última | CDHDR/CDPOS objetos KRED, BUPA_BUP, BUPA_BANK, BUPA_ADR; tabelas LFBK, BUT0BK, BUT020, LFA1 (campos de endereço) | **Viável (simplificado)** | contagem distinta de `ChangeDocument` na janela [PO-30, PO]; excluir alterações do dia da criação; `ADRESSE`/ADRC (objectid ≠ nº do BP) fica para fase 2 |
| F4 | Nº pedidos históricos, valor médio, desvio padrão | EKKO/EKPO | **Viável via table function** | CDS não tem `stddev`/`sqrt` → AMDP (HANA `STDDEV`) considerando só pedidos **anteriores** ao pedido avaliado |
| F5 | Conta bancária compartilhada | LFBK / BUT0BK | **Viável** | flag + nº de outros fornecedores com mesmo país/banco/conta (dado demo já tem o caso) |
| P1 | Valor total + razão vs média do fornecedor | EKPO.NETWR | **Viável** | soma `NetAmount` / média F4 (+ z-score com desvio de F4) |
| P2 | Preço unitário vs média histórica do material | EKPO | **Simplificado** | `NetPriceAmount/NetPriceQuantity`; média só em pedidos da **mesma moeda e mesma unidade de preço**; header = pior item (max) |
| P3 | Preço unitário vs registro info | EINE (`I_PurgInfoRecdOrgPlntDataApi01`) | **Simplificado** | razão só quando `OrderPriceUnit = PurchaseOrderPriceUnit` e moeda igual e preço RI > 0; senão nulo (ex. real: item em UN x RI em PC) |
| P4 | Quantidade vs histórico | EKPO.MENGE | **Simplificado** | razão vs média do mesmo material+fornecedor, mesma unidade |
| P5 | Material nunca comprado desse fornecedor | EKPO | **Viável** | flag (0 pedidos anteriores fornecedor+material) |
| P6 | Condição de pagamento = padrão | EKKO.ZTERM vs LFM1.ZTERM (fallback LFB1.ZTERM) | **Viável** | flag "diverge do padrão" (mais útil ao modelo que "igual") |
| P7 | Pedido criado depois da fatura | RBKP.BLDAT vs EKKO.AEDAT, via RSEG | **Viável** | flag se existe fatura não estornada com data do documento < data de criação do pedido |
| V1 | Pedidos ao mesmo fornecedor em 24h | EKKO.AEDAT | **Simplificado** | EKKO não tem hora de criação → "mesmo dia ou dia anterior" (D-1..D). Alternativa exata: CDHDR objeto `EINKBELEG` (insert com UTIME) — custo maior |
| V2 | Pedidos ao mesmo fornecedor em 7 dias | EKKO.AEDAT | **Viável** | janela [D-7, D] |
| C1 | Participação do fornecedor nas compras do comprador (%) | EKKO/EKPO | **Viável (definição a confirmar)** | comprador = EKKO.ERNAM (criador); valor ao fornecedor / valor total do comprador, janela 12 meses, mesma moeda |
| C2 | Criador do pedido registra recebimento | EKBE (VGABE=1, ERNAM) | **Viável** | flag; EKBE já traz o usuário (mais simples que MATDOC) |
| R1 | Fornecedor bloqueado (LFA1-SPERR/SPERM) | `I_Supplier` (+ LFM1-SPERM) | **Viável** | campo `ClassificacaoRegra = 'BLOQUEIO_REGRA'`; front não chama o Jev; ação grava a classificação |
| X1 | Idade/situação do CNPJ, CNAE, listas restritivas | fonte externa (Receita, listas) | **FORA da POC** | apenas sinalizado; nenhum campo criado |

Nenhum indicador expõe nome, CNPJ, endereço ou dados bancários em texto: só dias, contagens, razões, flags e categorias.

## 5. Desenho das camadas CDS

```
Tabelas/VDM standard
  │
  ├─ ZI_POC_JEV_PEDIDOITEM      (base: EKKO+EKPO, BSTYP=F, sem deletados; preço unitário normalizado)
  │
  ├─ Agregações por pedido (1 linha por PurchaseOrder)
  │   ├─ ZI_POC_JEV_ITEMIND      (por item: P2, P3, P4, P5)  → agregado ao pedido (max/flag)
  │   ├─ ZI_POC_JEV_FORNIND      (por pedido: F1, F2, F5, R1, P6)
  │   ├─ ZI_POC_JEV_ALTCAD       (por pedido: F3 — CDHDR/CDPOS na janela de 30 dias)
  │   ├─ ZI_POC_JEV_FLUXODOC     (por pedido: P7, C2 — RSEG/RBKP e EKBE)
  │   └─ ZI_POC_JEV_HIST         (CDS sobre table function ZTF_POC_JEV_HIST: F4, P1, V1, V2, C1)
  │
  ├─ ZR_POC_JEV_PEDIDO  (ROOT view entity, select from EKKO-base + LEFT JOIN das agregações;
  │                      semáforos inteiros; ClassificacaoRegra; última avaliação;
  │                      composition [0..*] of ZR_POC_JEV_AVAL; association [1..*] ZI_POC_JEV_ITEMIND)
  ├─ ZR_POC_JEV_AVAL    (filha, select from ZPOC_JEV_AVAL; association to parent)
  │
  ├─ ZC_POC_JEV_PEDIDO  (projection + @UI via DDLX; value helps; facets; criticality)
  ├─ ZC_POC_JEV_AVAL    (projection; tabela "Avaliações" na Object Page)
  ├─ ZC_POC_JEV_ITEM    (select read-only; tabela "Itens e indicadores" na OP)
  │
  └─ ZUI_POC_JEV (SRVD) → ZUI_POC_JEV_O4 (SRVB OData V4-UI)
```

Regras de modelagem:
- "Histórico" = só pedidos do mesmo fornecedor/material **criados antes** do pedido avaliado (evita vazamento do futuro).
- Moeda: comparações só na mesma moeda na POC (sem `currency_conversion`) — ver perguntas.
- Semáforos (`1` vermelho, `2` amarelo, `3` verde, `0` cinza) para: idade do fornecedor, alterações 30d, conta compartilhada, razão de preço, classificação ABAP da última avaliação.
- Raiz e filhas como **view entity** (`define root view entity ... as select from`); consumo da raiz e da avaliação como `as projection on` (exigido porque há BDEF); itens via `as select from` (só leitura, associação).

## 6. Desenho RAP: ação e persistência

### Por que **unmanaged** na raiz
- A raiz é leitura sobre EKKO (não podemos nem queremos persistir em EKKO). Em **managed**, cada entidade exige `persistent table`
  (ou `with unmanaged save`), e a raiz não tem tabela própria — ficaria um managed "de mentira".
- **Unmanaged** (`strict ( 2 )`) com raiz sem create/update/delete, só a ação, e a filha `Avaliacao` somente leitura
  (escrita apenas pela ação da raiz) é o desenho mais limpo. O SADL atende as queries OData pela CDS; o handler só implementa
  `read`, `lock` (no-op — a avaliação é log *insert-only* com chave UUID, sem conflito de concorrência), a ação e o `save` (INSERT na Z).
- Alternativa descartada: BO managed separado só para a tabela Z com ação estática — a ação não ficaria vinculada ao
  pedido na Object Page.

### BDEF (esboço — não criado)
```
unmanaged implementation in class zbp_r_poc_jev_pedido unique;
strict ( 2 );

define behavior for ZR_POC_JEV_PEDIDO alias Pedido
lock master
authorization master ( instance )
{
  association _Avaliacao;            // sem create by association (só a ação escreve)
  action registrarAvaliacao parameter ZA_POC_JEV_AVAL_IN result [1] $self;
  // fase 2: action registrarDecisao (na filha) para o aprovador
}

define behavior for ZR_POC_JEV_AVAL alias Avaliacao
lock dependent by _Pedido
authorization dependent by _Pedido
{
  association _Pedido;
  field ( readonly ) *;
}
```
Projeção `ZC_POC_JEV_PEDIDO` com `use action registrarAvaliacao; use association _Avaliacao;`.

### Parâmetro (abstract entity `ZA_POC_JEV_AVAL_IN`)
`JevDisponivel` (bool), `ProbFornecedorFicticio`, `ProbDesvioPagamento`, `ProbSobrepreco`, `ProbFracionamento`, `ProbFraudeInterna`
(dec 5,4 — 0..1), `Atipicidade` (int1 1–5), `JevAcaoSugerida` (char 12: LIBERAR/APROVACAO/BLOQUEAR),
`JevProbLiberar`, `JevProbAprovacao`, `JevProbBloquear`, `JevModeloVersao` (char 30).

### Lógica da ação (classe `ZBP_R_POC_JEV_PEDIDO`)
1. Lê o pedido (EML/SELECT na raiz) e o snapshot dos indicadores-chave.
2. Se `ClassificacaoRegra = 'BLOQUEIO_REGRA'` → grava classificação BLOQUEIO_REGRA (ignora probabilidades).
3. Se `JevDisponivel = false` → INDISPONIVEL.
4. Senão: `RiscoMax = max(5 probabilidades)`, `ChaveRiscoMax` = nome da maior; classificação por limiares:
   `< 0,20` LIBERA · `0,20–0,60` APROVACAO · `> 0,60` BLOQUEIA (limiares lidos da `ZPOC_JEV_CFG`, fallback em constantes).
5. Valida faixas (0..1, 1..5) e devolve mensagens RAP.
6. `ModoSombra = 'X'` sempre (nada bloqueia o pedido real); INSERT em `ZPOC_JEV_AVAL` no `save`.

### Tabela `ZPOC_JEV_AVAL` (transparente, classe de entrega A, tipos built-in)
| Campo | Tipo | Obs. |
|---|---|---|
| client | clnt | key |
| aval_uuid | sysuuid_x16 | key |
| purchase_order | ebeln | |
| aval_ts / aval_user | timestampl / syuname | |
| snap_idade_forn_dias, snap_alter_cad_30d, snap_conta_compart, snap_razao_valor_media, snap_razao_preco_ri, snap_razao_preco_hist, snap_mat_novo_forn, snap_zterm_diverge, snap_pedido_pos_fatura, snap_ped_forn_7d, snap_part_forn_comprador, snap_criador_registra_em | int4 / dec / char1 | snapshot dos indicadores-chave no momento da avaliação |
| prob_forn_ficticio, prob_desvio_pagto, prob_sobrepreco, prob_fracionamento, prob_fraude_interna | dec 5,4 | |
| atipicidade | int1 | 1–5 |
| jev_acao_sugerida | char 12 | |
| jev_prob_liberar, jev_prob_aprovacao, jev_prob_bloquear | dec 5,4 | |
| jev_modelo_versao | char 30 | |
| risco_max | dec 5,4 | |
| chave_risco_max | char 30 | |
| classificacao | char 15 | LIBERA/APROVACAO/BLOQUEIA/BLOQUEIO_REGRA/INDISPONIVEL |
| limiar_aprov_usado, limiar_bloq_usado | dec 5,4 | auditoria dos limiares |
| modo_sombra | abap_boolean | |
| decisao_aprovador | char 12 | fase 2 |
| aprovador / decisao_ts / decisao_obs | syuname / timestampl / char 255 | fase 2 |
| local_last_changed_at | timestampl | ETag |

### Tabela `ZPOC_JEV_CFG` (classe de entrega C)
`client` + `param` (char 30, key) + `valor_dec` (dec 7,4) + `valor_txt` (char 30).
Linhas iniciais: `LIMIAR_APROVACAO = 0,20`, `LIMIAR_BLOQUEIO = 0,60`, `MODO_SOMBRA = X`, `JANELA_ALTCAD_DIAS = 30`, `JANELA_VELOC_DIAS = 7`.
Carga inicial via classe runner (`if_oo_adt_classrun`) — ver perguntas.

## 7. Lista proposta de objetos (todos no pacote ZPOC_JEV)

| # | Nome | Tipo | Camada | Propósito |
|---|---|---|---|---|
| 1 | `ZPOC_JEV_AVAL` | TABL | Persistência | log de avaliações (Jev + classificação ABAP + decisão) |
| 2 | `ZPOC_JEV_CFG` | TABL | Persistência | limiares e parâmetros |
| 3 | `ZI_POC_JEV_PEDIDOITEM` | DDLS (view entity) | Interface/base | EKKO+EKPO filtrado, preço unitário normalizado |
| 4 | `ZTF_POC_JEV_HIST` | DDLS (table function) | Interface/agregação | estatísticas históricas, velocidade, participação do comprador |
| 5 | `ZCL_POC_JEV_HIST_AMDP` | CLAS (AMDP) | Interface/agregação | implementação HANA de #4 (STDDEV, janelas) |
| 6 | `ZI_POC_JEV_ITEMIND` | DDLS | Agregação/detalhe | indicadores por item (P2–P5) |
| 7 | `ZI_POC_JEV_FORNIND` | DDLS | Agregação | F1, F2, F5, R1, P6 por pedido |
| 8 | `ZI_POC_JEV_ALTCAD` | DDLS | Agregação | F3 alterações cadastrais 30d |
| 9 | `ZI_POC_JEV_FLUXODOC` | DDLS | Agregação | P7 fatura antes do pedido, C2 criador registra EM |
| 10 | `ZR_POC_JEV_PEDIDO` | DDLS (root view entity) | Raiz + semáforos | 1 linha por pedido com todos os indicadores |
| 11 | `ZR_POC_JEV_AVAL` | DDLS (view entity, filha) | Raiz (composição) | avaliações do pedido |
| 12 | `ZA_POC_JEV_AVAL_IN` | DDLS (abstract entity) | RAP | parâmetro da ação |
| 13 | `ZR_POC_JEV_PEDIDO` | BDEF (unmanaged) | RAP | ação `registrarAvaliacao` |
| 14 | `ZBP_R_POC_JEV_PEDIDO` | CLAS (behavior pool) | RAP | read/lock/ação/save + limiares |
| 15 | `ZC_POC_JEV_PEDIDO` | DDLS (projection) | Consumo | List Report / Object Page |
| 16 | `ZC_POC_JEV_AVAL` | DDLS (projection) | Consumo | tabela de avaliações na OP |
| 17 | `ZC_POC_JEV_ITEM` | DDLS (view entity) | Detalhe | tabela de itens + indicadores na OP |
| 18 | `ZC_POC_JEV_PEDIDO` | BDEF (projection) | Consumo | expõe a ação |
| 19 | `ZC_POC_JEV_PEDIDO` | DDLX | Consumo | @UI lineItem/selectionField/facets/criticality/ação |
| 20 | `ZC_POC_JEV_AVAL` | DDLX | Consumo | @UI da tabela de avaliações |
| 21 | `ZC_POC_JEV_ITEM` | DDLX | Consumo | @UI da tabela de itens |
| 22 | `ZUI_POC_JEV` | SRVD | Serviço | expõe Pedido, Avaliacao, Item (+ VHs) |
| 23 | `ZUI_POC_JEV_O4` | SRVB (OData V4 - UI) | Serviço | publicação |
| 24 | `ZCL_POC_JEV_SETUP` | CLAS (classrun) | Utilitário (opcional) | carga inicial da ZPOC_JEV_CFG |

Total: 2 tabelas, 11 DDLS, 2 BDEF, 3 DDLX, 3 classes (1 opcional), 1 SRVD, 1 SRVB. Sem domínios/elementos de dados próprios (tipos built-in).
Endpoint previsto: `/sap/opu/odata4/sap/zui_poc_jev_o4/srvd/sap/zui_poc_jev/0001/`.

## 8. Riscos

1. **Autorização**: views Z sobre tabelas não herdam DCL de `I_PurchaseOrderAPI01`/`I_Supplier`; com `#NOT_REQUIRED` qualquer usuário do app vê todos os pedidos. Aceitável em POC, não em produção.
2. **Performance**: self-joins de histórico (O(n²) por fornecedor) e CDPOS. Ok para ~1.400 pedidos; em produção exigiria janelas temporais e/ou materialização.
3. **Unidades/moedas** heterogêneas (UN x PC; BRL/USD/EUR) tornam razões de preço nulas ou enganosas — simplificado para mesma unidade/moeda.
4. **Velocidade 24h** aproximada por data (sem hora de criação em EKKO).
5. **Documentos de modificação**: ADRC (objeto `ADRESSE`) não casa direto com o nº do fornecedor; alterações feitas via BP podem aparecer só em BUPA_*; fornecedores sem link CVI ficam sem F3.
6. **Usuários técnicos** (ex.: LFA1.ERNAM = BASIS, EKBE.ERNAM = LIVECACHE, CDHDR por DDIC/MOOVIBOT) geram falsos positivos/negativos em F2, C2, F3.
7. **Dados de pedido inconsistentes** (EKBE de pedidos sem EKKO) — só pedidos com cabeçalho entram.
8. **Unmanaged + strict(2)** exige implementar `read`/`lock` mesmo sendo log; ETag e mensagens precisam ser tratados para o Fiori Elements não reclamar.
9. **Ação chamada pelo front com probabilidades vindas de fora**: o ABAP confia no payload. Validamos faixas, mas não há assinatura do resultado do Jev (POC).

## 9. Perguntas em aberto (para decidir antes do build)

1. **Comprador** = criador do pedido (EKKO.ERNAM) ou grupo de compradores (EKGRP)? Proposta: ERNAM.
2. Janela do histórico do fornecedor: todo o histórico anterior ou últimos 12/24 meses? Proposta: 24 meses.
3. Moeda: aceitar só mesma moeda (proposta POC) ou converter com `currency_conversion` para a moeda da empresa?
4. Velocidade 24h: aceitar aproximação por data ou investir em CDHDR `EINKBELEG` (hora exata)?
5. Limiares: tabela `ZPOC_JEV_CFG` + classe de setup (proposta) ou só constantes na classe?
6. A decisão do aprovador entra já agora (ação `registrarDecisao` na filha) ou só os campos e fica para fase 2?
7. Escopo de pedidos: todos os tipos com BSTYP=F ou só NB? Excluir pedidos de devolução / intercompany (EWM17-*)?
8. Transporte: qual ordem usar para o pacote ZPOC_JEV (ou criar uma nova)?
9. Regra dura: incluir também bloqueio por org. de compras (LFM1-SPERM) e pagamento (LFA1-SPERZ) no BLOQUEIO_REGRA?
