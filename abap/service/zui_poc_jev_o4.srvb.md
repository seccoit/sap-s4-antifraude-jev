# ZUI_POC_JEV_O4 (Service Binding)

Não é fonte: o SRVB é metadado do ADT e precisa ser recriado/publicado no sistema de destino.

- Tipo de binding: OData V4 - UI (categoria 0)
- Service definition: `ZUI_POC_JEV`
- Versão do serviço: `0001`
- Status no sistema de origem: publicado
- Endpoint (caminho relativo ao host SAP):
  `/sap/opu/odata4/sap/zui_poc_jev_o4/srvd/sap/zui_poc_jev/0001/`
- Entity sets:
  - `Pedido` (ZC_POC_JEV_PEDIDO, raiz RAP; ação bound `registrarAvaliacao`)
  - `Avaliacao` (ZC_POC_JEV_AVAL, filha por composição)
  - `Item` (ZC_POC_JEV_ITEM)
  - `SupplierVH` (I_Supplier_VH), `CompanyCodeVH` (I_CompanyCodeVH),
    `PurchasingOrganizationVH` (I_PurchasingOrganization), `PurchasingGroupVH` (I_PurchasingGroup)

O contrato completo para o front está em `../../backend-contract.md`.
