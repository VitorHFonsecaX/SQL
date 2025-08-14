WITH
ESCALA_KM AS (
    -- Classifica a quilometragem rodada da
entrega em faixas (escalas)
    SELECT
        id_entrega,
        nr_km_rodado,
        CASE
            WHEN nr_km_rodado BETWEEN 0 AND 50 THEN
'Curta Distância (0-50km)'
            WHEN nr_km_rodado BETWEEN 51 AND 200
THEN 'Média Distância (51-200km)'
            WHEN nr_km_rodado BETWEEN 201 AND 500
THEN 'Longa Distância (201-500km)'
            WHEN nr_km_rodado BETWEEN 501 AND 1000
THEN 'Muito Longa Distância (501-1000km)'
            ELSE 'Acima de 1000km'
        END AS EscalaEntrega
    FROM
        exemplo.view_entregas
),
TIPOS_SERVICOS_ESPECIAIS AS (
    -- Centraliza a lista de tipos de serviço que
têm tratamento especial
    SELECT * FROM (VALUES
        ('ENTREGA VIP'), ('COLETA URGENTE'),
('TRANSPORTE REFRIGERADO'),
        ('CARGA PERIGOSA'), ('MUDANÇA
INTERESTADUAL')
    ) AS T(tipo_servico)
),
DADOS_ENTREGAS_SERVICOS AS (
    -- Junta as tabelas base e filtra por data
    SELECT
        E.id_entrega,
        TRIM(S.ds_tiposervico) AS
ds_tiposervico,
        E.dt_realizacao,
        E.cd_motorista,
        TRIM(E.ds_veiculo) AS ds_veiculo,
        TRIM(E.ds_cidade_origem) AS
ds_cidade_origem,
        E.UF_origem,
        TRIM(E.ds_cidade_destino) AS
ds_cidade_destino,
        E.UF_destino,
        COALESCE(TRIM(E.ds_tabela_custo), 'SEM
TABELA') AS ds_tabela_custo,
        E.vl_frete,
        E.vl_adiantamento,
        E.nr_km_rodado
    FROM
        exemplo.entregas_servicos AS ES
    INNER JOIN
        exemplo.view_servicos AS S ON
ES.id_servico = S.id_servico
    INNER JOIN
        exemplo.view_entregas AS E ON ES.id_entrega
= E.id_entrega
    WHERE
        E.dt_realizacao >= CURRENT_DATE - INTERVAL
'30 days'
),
CONCAT_CUSTO AS (
    -- Concatena informações de entrega e
serviço para criar uma chave de serviço.
    SELECT
        DE.id_entrega,
        MAX(DE.ds_tiposervico) AS ds_tiposervico,
        CASE
            WHEN MAX(DE.ds_tabela_custo) IN ('TABELA
REGIAO SUL','TABELA NORDESTE') AND MAX(DE.ds_cidade_origem) = 'PORTO ALEGRE'
            THEN CONCAT_WS('|',
                MAX(DE.ds_tabela_custo),
                MAX(DE.ds_veiculo),
                MAX(EKM.EscalaEntrega))
            WHEN MAX(DE.ds_tabela_custo) = 'TABELA
INTERNACIONAL'
            THEN CONCAT_WS('|',
                MAX(DE.ds_tabela_custo),
                MAX(DE.ds_cidade_origem),
                MAX(DE.ds_cidade_destino),
                MAX(DE.ds_veiculo))
            ELSE CONCAT_WS('|',
MAX(DE.ds_tabela_custo), MAX(DE.ds_cidade_origem),
MAX(DE.ds_veiculo))
        END AS C_SERVICO
    FROM
        DADOS_ENTREGAS_SERVICOS DE
    LEFT JOIN ESCALA_KM EKM
        ON DE.id_entrega = EKM.id_entrega
    GROUP BY
        DE.id_entrega
),
TABELA_PRECO_FILTRADA AS (
    -- Seleciona o vl_tabela, priorizando valores
não nulos
    SELECT
        c_servico,
        vl_tabela
    FROM (
        SELECT
            c_servico,
            vl_tabela,
            ROW_NUMBER() OVER (PARTITION BY
c_servico ORDER BY vl_tabela DESC NULLS LAST) as rn
        FROM
            exemplo.tabela_preco_concatenada
    ) AS sub
    WHERE rn = 1
),
CALCULOS_PARCIAIS AS (
    -- Realiza todos os cálculos e prepara os
dados para a saída final
    SELECT
        DE.id_entrega,
        DE.ds_tiposervico,
        DE.dt_realizacao,
        DE.cd_motorista,
        DE.ds_veiculo,
        DE.ds_cidade_origem,
        DE.UF_origem,
        DE.ds_cidade_destino,
        DE.UF_destino,
        DE.ds_tabela_custo,
        DE.vl_frete,
        DE.vl_adiantamento,
        DE.nr_km_rodado,
        TPF.vl_tabela AS vl_tabela_original,
        CASE
            WHEN DE.ds_tabela_custo IN ('TABELA
REGIAO SUL', 'TABELA NORDESTE')
            THEN COALESCE(TPF.vl_tabela, 0) *
COALESCE(DE.nr_km_rodado, 0)
            ELSE COALESCE(TPF.vl_tabela, 0)
        END AS vl_calculado,
        ROW_NUMBER() OVER (PARTITION BY
DE.id_entrega ORDER BY DE.dt_realizacao DESC) as rn
    FROM
        DADOS_ENTREGAS_SERVICOS AS DE
    LEFT JOIN
        CONCAT_CUSTO AS CC ON CC.id_entrega =
DE.id_entrega
    LEFT JOIN
        TABELA_PRECO_FILTRADA AS TPF ON
TPF.c_servico = CC.C_SERVICO
)
SELECT
    C.id_entrega,
    C.ds_tiposervico,
    TO_CHAR(C.dt_realizacao, 'YYYY-MM-DD') AS
dt_realizacao,
    C.cd_motorista,
    C.ds_veiculo,
    C.ds_cidade_origem,
    C.UF_origem,
    C.ds_cidade_destino,
    C.UF_destino,
    C.ds_tabela_custo,
    C.vl_frete,
    C.nr_km_rodado,
    C.vl_tabela_original,
    C.vl_calculado,
    -- Calcula a coluna 'diferenca_valor'. Usa a
CTE TIPOS_SERVICOS_ESPECIAIS
    CASE
        WHEN C.ds_tabela_custo = 'SEM TABELA' THEN
NULL
        WHEN TSE.tipo_servico IS NOT NULL THEN NULL
        ELSE ROUND(COALESCE(C.vl_frete, 0) -
COALESCE(C.vl_calculado, 0), 2)
    END AS diferenca_valor,
    -- Classifica o 'status' com base na coluna
'diferenca_valor'.
    CASE
        WHEN C.ds_tabela_custo = 'SEM TABELA' THEN
'Sem Tabela de Custo'
        WHEN TSE.tipo_servico IS NOT NULL THEN 'Serviço
Especial'
        WHEN ABS(COALESCE(C.vl_frete, 0) -
COALESCE(C.vl_calculado, 0)) <= 1 THEN 'Conforme Tabela'
        WHEN (COALESCE(C.vl_frete, 0) -
COALESCE(C.vl_calculado, 0)) > 1 THEN 'Valor Acima da Tabela'
        WHEN (COALESCE(C.vl_frete, 0) -
COALESCE(C.vl_calculado, 0)) < -1 THEN 'Valor Abaixo da Tabela'
        ELSE 'Indefinido'
    END AS status
FROM
    CALCULOS_PARCIAIS AS C
LEFT JOIN
    TIPOS_SERVICOS_ESPECIAIS AS TSE ON
C.ds_tiposervico = TSE.tipo_servico
WHERE
    C.rn = 1;