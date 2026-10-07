@EndUserText.label: 'POC Jev - antifraude pedidos de compra'
define service ZUI_POC_JEV {
  expose ZC_POC_JEV_PEDIDO        as Pedido;
  expose ZC_POC_JEV_AVAL          as Avaliacao;
  expose ZC_POC_JEV_ITEM          as Item;
  expose I_Supplier_VH            as SupplierVH;
  expose I_CompanyCodeVH          as CompanyCodeVH;
  expose I_PurchasingOrganization as PurchasingOrganizationVH;
  expose I_PurchasingGroup        as PurchasingGroupVH;
}
