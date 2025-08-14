WITH DadosManifesto AS (
    -- Seleciona e formata os dados principais do manifesto, incluindo datas
    SELECT
        M.id_Manifesto,
        M.id_CIOT,
        M.nr_CIOT,
        M.id_cliente,
        M.dt_Inclusao,
        FORMAT(M.dt_Inclusao, 'yyyy-MM-dd HH:mm:ss') AS dt_inclusao_formatada,
        FORMAT(
            COALESCE(CAST(M.dt_Saida AS DATETIME) + CAST(M.hr_saida AS DATETIME), NULL),
            'yyyy-MM-dd HH:mm:ss'
        ) AS dt_saida,
        FORMAT(
            COALESCE(CAST(M.dt_Chegada AS DATETIME) + CAST(M.hr_Chegada AS DATETIME), NULL),
            'yyyy-MM-dd HH:mm:ss'
        ) AS dt_chegada,
        FORMAT(
            COALESCE(CAST(M.dt_Finalizado AS DATETIME) + CAST(M.hr_Finalizado AS DATETIME), NULL),
            'yyyy-MM-dd HH:mm:ss'
        ) AS dt_finalizacao,
        M.id_Motorista,
        M.id_Veiculo,
        M.id_Carreta,
        M.id_Carreta2,
        M.id_Agregado,
        M.id_tabelaAgregadoCalculado,
        M.id_CidadeOrigem,
        M.id_CidadeFinalEntrega,
        M.id_CidadeCalculo,
        M.vl_Adiantamento,
        M.vl_Combustivel,
        M.vl_Pedagio,
        M.vl_Entrega,
        M.vl_Adicional,
        M.vl_Servico,
        M.vl_SaldoLiquido AS vl_Saldo
    FROM
        tbdManifesto M
    WHERE
        M.dt_Inclusao >= '2024-01-01'
),
--
--  Junta as informações relacionadas a pessoas e veículos
--
DadosPessoaisVeiculos AS (
    SELECT
        DM.*,
        P.ds_Pessoa AS ds_motorista,
        V_Cavalo.cd_Placa AS cd_cavalo,
        V_Carreta1.cd_Placa AS cd_carreta_1,
        V_Carreta2.cd_Placa AS cd_carreta_2,
        TV.ds_TipoVeiculo AS ds_veiculo_manifesto,
        CL.ds_Pessoa AS ds_agregado,
        CL.cd_CGCCPF AS cd_cnpj_cpf_agregado
    FROM
        DadosManifesto DM
    LEFT JOIN
        tbdPessoa P ON DM.id_Motorista = P.id_Pessoa
    LEFT JOIN
        tbdVeiculo V_Cavalo ON DM.id_Veiculo = V_Cavalo.id_Veiculo
    LEFT JOIN
        tbdTipoVeiculo TV ON V_Cavalo.id_TipoVeiculo = TV.id_TipoVeiculo
    LEFT JOIN
        tbdVeiculo V_Carreta1 ON DM.id_Carreta = V_Carreta1.id_Veiculo
    LEFT JOIN
        tbdVeiculo V_Carreta2 ON DM.id_Carreta2 = V_Carreta2.id_Veiculo
    LEFT JOIN
        tbdPessoa CL ON DM.id_Agregado = CL.id_Pessoa
),
--
--  Junta as informações de localidade e tabela de custo
--
DadosComplementares AS (
    SELECT
        DPV.*,
        CS.ds_Cliente,
        TA.ds_TipoServico AS ds_TabelaCusto,
        CO.ds_Cidade AS CidadeOrigem,
        EO.cd_Estado AS UFOrigem,
        CD.ds_Cidade AS CidadeDestino,
        ED.cd_Estado AS UFDestino,
        CC.ds_Cidade AS CidadeCalculo,
        EC.cd_Estado AS UFCalculo
    FROM
        DadosPessoaisVeiculos DPV
    LEFT JOIN
        tbdClienteSistema CS ON DPV.id_cliente = CS.id_cliente
    LEFT JOIN
        tbdTransportadoraServico TA ON DPV.id_tabelaAgregadoCalculado = TA.id_TransportadoraServico
    LEFT JOIN
        tbdCidade CC ON DPV.id_CidadeCalculo = CC.id_Cidade
    LEFT JOIN
        tbdEstado EC ON CC.id_Estado = EC.id_Estado
    LEFT JOIN
        tbdCidade CO ON DPV.id_CidadeOrigem = CO.id_Cidade
    LEFT JOIN
        tbdEstado EO ON CO.id_Estado = EO.id_Estado
    LEFT JOIN
        tbdCidade CD ON DPV.id_CidadeFinalEntrega = CD.id_Cidade
    LEFT JOIN
        tbdEstado ED ON CD.id_Estado = ED.id_Estado
)
--
--  Seleção final com todas as colunas
--
SELECT
    id_Manifesto,
    id_CIOT,
    nr_CIOT,
    ds_Cliente,
    dt_inclusao_formatada AS dt_inclusao,
    dt_saida,
    dt_chegada,
    dt_finalizacao,
    ds_motorista,
    cd_cavalo,
    cd_carreta_1,
    cd_carreta_2,
    ds_veiculo_manifesto,
    ds_agregado,
    cd_cnpj_cpf_agregado,
    ds_TabelaCusto,
    CidadeOrigem,
    UFOrigem,
    CidadeDestino,
    UFDestino,
    CidadeCalculo,
    UFCalculo,
    vl_Adiantamento,
    vl_Combustivel,
    vl_Pedagio,
    vl_Entrega,
    vl_Adicional,
    vl_Servico,
    vl_Saldo
FROM
    DadosComplementares
ORDER BY
    dt_inclusao_formatada DESC;