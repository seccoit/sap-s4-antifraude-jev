projection;
strict ( 2 );

define behavior for ZC_POC_JEV_PEDIDO alias Pedido
{
  use action registrarAvaliacao;

  use association _Avaliacao;
}

define behavior for ZC_POC_JEV_AVAL alias Avaliacao
{
  use association _Pedido;
}
