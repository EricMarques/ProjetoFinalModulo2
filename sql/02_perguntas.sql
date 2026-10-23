-- =====================================================================================
-- 02_perguntas.sql  -  CONSULTAS DAS 6 PERGUNTAS DE NEGOCIO DA CONTROLADORIA
-- =====================================================================================
-- Como usar: abra no Workbench e rode consulta por consulta (selecione o trecho e Ctrl+Enter).
-- Regras que valem para todas as consultas (secao 4.4 do enunciado):
--   * percentual = SOMA / SOMA, nunca media de percentuais
--   * economia so conta os itens COMPARAVEIS (comparavel = 1)
--   * NULLIF(denominador, 0) evita divisao por zero (Credenciamento nao tem item comparavel)
--   * volume = soma do valor_total_homologado de TODOS os itens da fato (comparaveis ou nao)
-- Cada pergunta traz, em comentario, o valor de conferencia da prova real (anexo 8), quando existe.
-- =====================================================================================
 
USE pncp_controladoria;
 
 
-- =====================================================================================
-- PERGUNTA 1 - ECONOMIA GLOBAL DO PODER PUBLICO
-- Qual e o percentual e o valor nominal economizado (estimado - homologado)?
-- =====================================================================================
 
-- 1a) Economia em R$ e em %
-- Conferencia: itens_comparaveis = 5457 | volume_homologado_total = 8044498805.74
--              estimado_comparavel = 6867663469.91 | economia_rs = 992861686.95 | economia_pct = 14.46
SELECT
    COUNT(*)                                                                    AS itens_na_fato,
    SUM(comparavel)                                                             AS itens_comparaveis,
    ROUND(100 * SUM(comparavel) / COUNT(*), 2)                                  AS pct_itens_comparaveis,
    SUM(valor_total_homologado)                                                 AS volume_homologado_total,
    SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado   ELSE 0 END)        AS estimado_comparavel,
    SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END)        AS homologado_comparavel,
    SUM(CASE WHEN comparavel = 1
             THEN valor_total_estimado - valor_total_homologado ELSE 0 END)     AS economia_rs,
    ROUND(100 * SUM(CASE WHEN comparavel = 1
                         THEN valor_total_estimado - valor_total_homologado ELSE 0 END)
          / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado;
 
-- 1b) Itens com sobrepreco (homologado maior que o estimado)
-- Conferencia: o anexo 8 informa 27 itens. A consulta mostra a contagem na fato inteira e so nos comparaveis,
-- para identificar qual das duas definicoes bate com o professor.
SELECT
    SUM(CASE WHEN valor_total_homologado > valor_total_estimado THEN 1 ELSE 0 END)                    AS sobrepreco_todos_os_itens,
    SUM(CASE WHEN comparavel = 1
              AND valor_total_homologado > valor_total_estimado THEN 1 ELSE 0 END)                    AS sobrepreco_so_comparaveis
FROM fato_item_contratado;
 
 
-- =====================================================================================
-- PERGUNTA 2 - CONCENTRACAO E RISCO DE FORNECEDORES
-- Quem sao os maiores fornecedores em volume e qual percentual do orcamento esta neles?
-- Fornecedor = CNPJ/CPF ja limpo (ni_fornecedor): o mesmo nome com CNPJ diferente (filial) conta como outro.
-- =====================================================================================
 
-- 2a) Os 10 maiores fornecedores por volume homologado e a participacao de cada um no total
SELECT
    fo.ni_fornecedor,
    fo.nome_fornecedor,
    fo.porte,
    COUNT(*)                                                                    AS itens,
    SUM(f.valor_total_homologado)                                               AS volume_homologado,
    ROUND(100 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)  AS pct_do_volume_total
FROM fato_item_contratado f
JOIN dim_fornecedor fo ON fo.sk_fornecedor = f.sk_fornecedor
GROUP BY fo.sk_fornecedor, fo.ni_fornecedor, fo.nome_fornecedor, fo.porte
ORDER BY volume_homologado DESC
LIMIT 10;
 
-- 2b) Concentracao dos 10 maiores juntos: quanto do orcamento total eles representam
SELECT
    SUM(t.volume)                                                               AS volume_top10,
    ROUND(100 * SUM(t.volume)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)  AS pct_top10_do_volume_total
FROM (
    SELECT sk_fornecedor, SUM(valor_total_homologado) AS volume
    FROM fato_item_contratado
    GROUP BY sk_fornecedor
    ORDER BY volume DESC
    LIMIT 10
) AS t;
 
 
-- =====================================================================================
-- PERGUNTA 3 - EFICACIA POR MODALIDADE
-- Quais modalidades trazem maior desagio (economia %) e quais concentram o maior volume?
-- =====================================================================================
 
-- A subconsulta (t) soma por modalidade; a consulta de fora calcula os percentuais.
-- Em Credenciamento (modalidade 12) nenhum item e comparavel: economia_pct fica NULL, o que e esperado.
SELECT
    t.modalidade_id,
    t.nome_modalidade,
    t.itens,
    t.volume_homologado,
    ROUND(100 * t.volume_homologado
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)  AS pct_do_volume,
    t.estimado_comparavel,
    t.economia_rs,
    ROUND(100 * t.economia_rs / NULLIF(t.estimado_comparavel, 0), 2)            AS economia_pct
FROM (
    SELECT
        m.modalidade_id,
        m.nome_modalidade,
        COUNT(*)                                                                AS itens,
        SUM(f.valor_total_homologado)                                           AS volume_homologado,
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END)  AS estimado_comparavel,
        SUM(CASE WHEN f.comparavel = 1
                 THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END) AS economia_rs
    FROM fato_item_contratado f
    JOIN dim_modalidade m ON m.sk_modalidade = f.sk_modalidade
    GROUP BY m.modalidade_id, m.nome_modalidade
) AS t
ORDER BY economia_pct DESC;
-- Para ver a modalidade que mais movimenta recursos, troque o ORDER BY por: ORDER BY t.volume_homologado DESC
 
 
-- =====================================================================================
-- PERGUNTA 4 - TEMPO DO CICLO DE COMPRAS
-- Qual a duracao media (dias) entre a publicacao do edital e a homologacao, por orgao?
-- =====================================================================================
 
-- 4a) Visao geral
-- Conferencia: itens_com_ciclo = 5896 | itens_sem_ciclo = 230 | ciclo_medio = 48.1 | ciclo_maximo = 611
SELECT
    COUNT(dias_ciclo)                                                           AS itens_com_ciclo,
    COUNT(*) - COUNT(dias_ciclo)                                                AS itens_sem_ciclo,
    ROUND(AVG(dias_ciclo), 1)                                                   AS ciclo_medio_dias,
    MAX(dias_ciclo)                                                             AS ciclo_maximo_dias
FROM fato_item_contratado;
 
-- 4b) Ciclo medio por orgao
-- Agrupa pelo NOME padronizado (o mesmo orgao tem varias unidades/CNPJ), conta so itens com ciclo
-- (COUNT(dias_ciclo) ignora NULL) e mostra apenas orgaos com 5 ou mais itens com ciclo (HAVING).
SELECT
    o.nome_orgao,
    COUNT(DISTINCT o.cnpj_orgao)                                                AS unidades_compradoras,
    COUNT(f.dias_ciclo)                                                         AS itens_com_ciclo,
    ROUND(AVG(f.dias_ciclo), 1)                                                 AS ciclo_medio_dias,
    MAX(f.dias_ciclo)                                                           AS ciclo_maximo_dias
FROM fato_item_contratado f
JOIN dim_orgao o ON o.sk_orgao = f.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(f.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;
-- Para uma lista mais curta (por exemplo, os 15 mais lentos), acrescente LIMIT 15 ao final.
 
 
-- =====================================================================================
-- PERGUNTA 5 - DISTRIBUICAO REGIONAL
-- Quais estados e regioes concentram as maiores despesas e quais tem os melhores descontos?
-- =====================================================================================
 
-- 5a) Por estado (UF)
SELECT
    t.uf_sigla,
    t.uf_nome,
    t.regiao,
    t.unidades_compradoras,
    t.itens,
    t.volume_homologado,
    ROUND(100 * t.volume_homologado
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)  AS pct_do_volume,
    ROUND(100 * t.economia_rs / NULLIF(t.estimado_comparavel, 0), 2)            AS economia_pct
FROM (
    SELECT
        l.uf_sigla,
        l.uf_nome,
        l.regiao,
        COUNT(DISTINCT f.sk_orgao)                                              AS unidades_compradoras,
        COUNT(*)                                                                AS itens,
        SUM(f.valor_total_homologado)                                           AS volume_homologado,
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END)  AS estimado_comparavel,
        SUM(CASE WHEN f.comparavel = 1
                 THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END) AS economia_rs
    FROM fato_item_contratado f
    JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
    GROUP BY l.uf_sigla, l.uf_nome, l.regiao
) AS t
ORDER BY t.volume_homologado DESC;
 
-- 5b) Por regiao
SELECT
    t.regiao,
    t.unidades_compradoras,
    t.itens,
    t.volume_homologado,
    ROUND(100 * t.volume_homologado
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)  AS pct_do_volume,
    ROUND(100 * t.economia_rs / NULLIF(t.estimado_comparavel, 0), 2)            AS economia_pct
FROM (
    SELECT
        l.regiao,
        COUNT(DISTINCT f.sk_orgao)                                              AS unidades_compradoras,
        COUNT(*)                                                                AS itens,
        SUM(f.valor_total_homologado)                                           AS volume_homologado,
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END)  AS estimado_comparavel,
        SUM(CASE WHEN f.comparavel = 1
                 THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END) AS economia_rs
    FROM fato_item_contratado f
    JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
    GROUP BY l.regiao
) AS t
ORDER BY t.volume_homologado DESC;
 
 
-- =====================================================================================
-- PERGUNTA 6 - PERFIL DOS GASTOS
-- Como os recursos se distribuem entre Bens, Servicos e Obras e engenharia?
-- perfil_gasto e coluna da propria fato: nao precisa de JOIN.
-- =====================================================================================
-- Conferencia (pct_do_volume): Obras e engenharia 60.8 | Servicos 36.6 | Bens 2.6
--              (itens): Obras e engenharia 967 | Servicos 1849 | Bens 3310
SELECT
    t.perfil_gasto,
    t.itens,
    t.volume_homologado,
    ROUND(100 * t.volume_homologado
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1)  AS pct_do_volume,
    ROUND(t.volume_homologado / t.itens, 2)                                     AS ticket_medio_por_item,
    ROUND(100 * t.economia_rs / NULLIF(t.estimado_comparavel, 0), 2)            AS economia_pct
FROM (
    SELECT
        perfil_gasto,
        COUNT(*)                                                                AS itens,
        SUM(valor_total_homologado)                                             AS volume_homologado,
        SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END)      AS estimado_comparavel,
        SUM(CASE WHEN comparavel = 1
                 THEN valor_total_estimado - valor_total_homologado ELSE 0 END) AS economia_rs
    FROM fato_item_contratado
    GROUP BY perfil_gasto
) AS t
ORDER BY t.volume_homologado DESC;