WITH VendaMaisRecente AS (
    -- 1. Identifica a última versão de cada pedido a partir de 2025.
    --    Isso garante que apenas os dados mais recentes sejam processados.
    SELECT
        V.id_Venda,
        V.nr_Pedido,
        V.vl_Total,
        V.vl_Desconto,
        V.vl_Imposto,
        P.ds_SKU,
        ROW_NUMBER() OVER (PARTITION BY V.nr_Pedido ORDER BY V.id_Venda DESC) AS VersaoPedido
    FROM
        tbdVenda AS V
    INNER JOIN
        tbdProduto AS P ON V.id_Produto = P.id_Produto
    WHERE
        V.dt_Inclusao >= '2025-01-01'
        AND V.nr_Pedido IS NOT NULL
        AND V.nr_Pedido <> ''
)
SELECT
    VR.id_Venda,
    Cliente.ds_Pessoa AS Cliente,
    Vendedor.ds_Pessoa AS Vendedor,
    Pagamento.cd_Parcela,
    Pagamento.ds_Parcela,
    -- Converte a data de vencimento para o formato DD/MM/AAAA.
    FORMAT(Pagamento.dt_Vencimento, 'dd/MM/yyyy') AS dt_Vencimento,
    -- Calcula o valor total das parcelas para cada venda.
    SUM(Pagamento.vl_Parcela) OVER (PARTITION BY VR.id_Venda) AS Total_Venda_Parcela,
    Pagamento.vl_Parcela,
    Pagamento.cd_Status,
    -- Combina e formata data e hora de emissão.
    FORMAT(Pagamento.dt_Emissao, 'dd/MM/yyyy') + ' ' + FORMAT(Pagamento.hr_Emissao, 'HH:mm:ss') AS dt_hr_Emissao,
    -- Combina e formata data e hora de estorno.
    FORMAT(Pagamento.dt_Estorno, 'dd/MM/yyyy') + ' ' + FORMAT(Pagamento.hr_Estorno, 'HH:mm:ss') AS dt_hr_Estorno,
    -- Combina e formata data e hora de baixa.
    FORMAT(Pagamento.dt_Baixa, 'dd/MM/yyyy') + ' ' + FORMAT(Pagamento.hr_Baixa, 'HH:mm:ss') AS dt_hr_Baixa,
    -- Combina e formata data e hora de liberação.
    FORMAT(Pagamento.dt_Liberacao, 'dd/MM/yyyy') + ' ' + FORMAT(Pagamento.hr_Liberacao, 'HH:mm:ss') AS dt_hr_Liberacao,
    Pagamento.ds_Observacao,
    Pagamento.vl_Juros,
    Pagamento.vl_Multa,
    Pagamento.vl_TaxaAdministrativa,
    FormaPagamento.ds_FormaPagamento
FROM
    tbd_22_PagamentoParcela AS Pagamento
INNER JOIN
    tbd_22_Pedido AS Pedido ON Pagamento.id_Pedido = Pedido.ID_Pedido
INNER JOIN
    VendaMaisRecente AS VR ON Pedido.nr_Pedido = VR.nr_Pedido
LEFT JOIN
    tbdPessoa AS Cliente ON Pedido.id_Cliente = Cliente.id_Pessoa
LEFT JOIN
    tbdPessoa AS Vendedor ON Pedido.id_Vendedor = Vendedor.id_Pessoa
LEFT JOIN
    tbd_22_FormaPagamento AS FormaPagamento ON Pedido.id_FormaPagamento = FormaPagamento.id_FormaPagamento
WHERE
    Pedido.dt_Pedido >= '2025-01-01'
    AND VR.VersaoPedido = 1
ORDER BY
    VR.id_Venda, Pagamento.cd_Parcela;