unmanaged implementation in class zbp_r_poc_jev_pedido unique;
strict ( 2 );

define behavior for ZR_POC_JEV_PEDIDO alias Pedido
lock master
authorization master ( global )
{
  field ( readonly ) PurchaseOrder;

  association _Avaliacao;

  action registrarAvaliacao parameter ZA_POC_JEV_AVAL_IN result [1] $self;
}

define behavior for ZR_POC_JEV_AVAL alias Avaliacao
lock dependent by _Pedido
authorization dependent by _Pedido
{
  field ( readonly ) EvaluationUUID, PurchaseOrder;

  association _Pedido;
}
