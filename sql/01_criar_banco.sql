CREATE DATABASE IF NOT EXISTS pncp_controladoria;

USE pncp_controladoria;

DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_orgao;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_localidade;

CREATE TABLE dim_orgao (
    sk_orgao     INT NOT NULL AUTO_INCREMENT,
    cnpj_orgao   VARCHAR(14) NOT NULL,
    nome_orgao   VARCHAR(300),
    poder        VARCHAR(20),
    PRIMARY KEY (sk_orgao),
    UNIQUE KEY uq_dim_orgao_cnpj (cnpj_orgao)
);

CREATE TABLE dim_fornecedor (
    sk_fornecedor   INT NOT NULL AUTO_INCREMENT,
    ni_fornecedor   VARCHAR(40) NOT NULL,
    nome_fornecedor VARCHAR(300),
    tipo_pessoa     VARCHAR(10),
    porte           VARCHAR(60),
    PRIMARY KEY (sk_fornecedor),
    UNIQUE KEY uq_dim_fornecedor_ni (ni_fornecedor)
);

CREATE TABLE dim_modalidade (
    sk_modalidade   INT NOT NULL AUTO_INCREMENT,
    modalidade_id   INT NOT NULL,
    nome_modalidade VARCHAR(60) NOT NULL,
    PRIMARY KEY (sk_modalidade),
    UNIQUE KEY uq_dim_modalidade_id (modalidade_id)
);

CREATE TABLE dim_localidade (
    sk_localidade INT NOT NULL AUTO_INCREMENT,
    uf_sigla      CHAR(2) NOT NULL,
    uf_nome       VARCHAR(40),
    regiao        VARCHAR(20),
    PRIMARY KEY (sk_localidade),
    UNIQUE KEY uq_dim_localidade_uf (uf_sigla)
);

CREATE TABLE fato_item_contratado (
    sk_fato                   INT NOT NULL AUTO_INCREMENT,
    numero_controle_pncp      VARCHAR(60) NOT NULL,
    numero_item               INT NOT NULL,
    sk_orgao                  INT NOT NULL,
    sk_fornecedor             INT NOT NULL,
    sk_modalidade             INT NOT NULL,
    sk_localidade             INT NOT NULL,
    data_publicacao           DATE NOT NULL,
    data_homologacao          DATE NULL,
    descricao_item            TEXT,
    perfil_gasto              VARCHAR(30) NOT NULL,
    quantidade                DECIMAL(18,4) NOT NULL,
    valor_unitario_estimado   DECIMAL(18,4) NOT NULL,
    valor_unitario_homologado DECIMAL(18,4) NOT NULL,
    valor_total_estimado      DECIMAL(18,2) NOT NULL,
    valor_total_homologado    DECIMAL(18,2) NOT NULL,
    comparavel                TINYINT NOT NULL,
    economia_valor            DECIMAL(18,2) NULL,
    dias_ciclo                INT NULL,
    PRIMARY KEY (sk_fato),
    UNIQUE KEY uq_fato_item (numero_controle_pncp, numero_item),
    CONSTRAINT fk_fato_orgao      FOREIGN KEY (sk_orgao)      REFERENCES dim_orgao (sk_orgao),
    CONSTRAINT fk_fato_fornecedor FOREIGN KEY (sk_fornecedor) REFERENCES dim_fornecedor (sk_fornecedor),
    CONSTRAINT fk_fato_modalidade FOREIGN KEY (sk_modalidade) REFERENCES dim_modalidade (sk_modalidade),
    CONSTRAINT fk_fato_localidade FOREIGN KEY (sk_localidade) REFERENCES dim_localidade (sk_localidade),
    CONSTRAINT ck_fato_quantidade CHECK (quantidade > 0),
    CONSTRAINT ck_fato_valores    CHECK (valor_unitario_estimado >= 0 AND valor_unitario_homologado >= 0
                                         AND valor_total_estimado >= 0 AND valor_total_homologado >= 0),
    CONSTRAINT ck_fato_comparavel CHECK (comparavel IN (0, 1))
);
