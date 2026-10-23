"""
auditoria.py  -  AUDITORIA DOS CSVs BRUTOS (data/raw/)
======================================================
Conta quantos registros cada problema afeta ANTES da limpeza. Nao altera nenhum arquivo: so le e imprime.
Responde as perguntas da secao 7.4 do enunciado:
  1) linhas de cada arquivo e chaves repetidas      2) formatos de CNPJ/CPF       3) formatos de dinheiro
  4) formatos de data e datas impossiveis           5) nulos disfarcados por coluna
  6) acentos quebrados (Ã§, Ã£)                     7) data_resultado anterior a data_publicacao

COMO RODAR (da raiz do projeto):   python -m src.auditoria
Para guardar o resultado:          python -m src.auditoria | Out-File -Encoding utf8 docs\\auditoria.txt
"""

import re
import sys

import pandas as pd

from src import config, limpeza

# Caracteres invisiveis (largura zero e espaco "sem quebra") que vem de sistemas antigos
INVISIVEIS = "[\u200b\u200c\u200d\ufeff\xa0]"
# Texto UTF-8 lido como Latin-1: "Ã" ou "Â" seguidos de um simbolo (Ã§, Ã£, Ã©...). Um "Ã" normal, como em "NÃO", nao casa.
MOJIBAKE = "Ã[\u0080-\u00bf]|Â[\u0080-\u00bf]|\ufffd"

COLUNAS_DINHEIRO = {
    "compras": ["valor_total_estimado", "valor_total_homologado"],
    "itens": ["quantidade", "valor_unitario_estimado", "valor_total_estimado"],
    "resultados": ["quantidade_homologada", "valor_unitario_homologado", "valor_total_homologado"],
}
COLUNAS_DATA = {
    "compras": ["data_publicacao", "data_abertura_proposta", "data_encerramento_proposta"],
    "resultados": ["data_resultado", "data_cancelamento"],
}
# (expressao que reconhece o formato, nome do formato)
FORMATOS_DATA = [
    (r"^\d{4}-\d{2}-\d{2}T", "AAAA-MM-DDTHH:MM:SS"),
    (r"^\d{4}-\d{2}-\d{2}", "AAAA-MM-DD"),
    (r"^\d{2}/\d{2}/\d{4} \d", "DD/MM/AAAA com hora"),
    (r"^\d{2}/\d{2}/\d{4}$", "DD/MM/AAAA"),
    (r"^\d{2}-\d{2}-\d{4}", "DD-MM-AAAA"),
    (r"^\d{2}\.\d{2}\.\d{4}", "DD.MM.AAAA"),
    (r"^\d{4}/\d{2}/\d{2}", "AAAA/MM/DD"),
    (r"^\d{8}$", "AAAAMMDD"),
]


def ler(nome):
    """Le o CSV TUDO COMO TEXTO (dtype=str), sem converter nada sozinho."""
    return pd.read_csv(config.PASTA_RAW / f"{nome}.csv", dtype=str, keep_default_na=False)


def limpo(valor):
    """Valor sem invisiveis e sem espacos nas pontas (so para classificar; o dado original nao muda)."""
    return limpeza.remover_invisiveis(valor).strip()


def titulo(texto):
    print(f"\n{'=' * 80}\n{texto}\n{'=' * 80}")


def mostrar(serie, recuo="   "):
    """Imprime a contagem de cada categoria, com o percentual."""
    total = len(serie)
    for categoria, n in serie.value_counts().items():
        print(f"{recuo}{categoria}: {n}  ({100 * n / total:.1f}%)")


# ---------------------------------------------------------------------------------------------
# Classificadores: cada um olha UM valor bruto e devolve a categoria do problema
# ---------------------------------------------------------------------------------------------
def classificar_documento(valor, tipo):
    t = limpo(valor)
    if limpeza.eh_nulo(t):
        return "vazio ou nulo disfarcado"
    if tipo == "PE":
        return "estrangeiro (PE): nao se aplica"
    digitos = re.sub(r"\D", "", t)
    if digitos == "":
        return "sem digitos (lixo)"
    if tipo == "PJ":
        esperado = 14
    elif tipo == "PF":
        esperado = 11
    else:
        esperado = 14 if len(digitos) > 11 else 11
    if len(digitos) < esperado:
        return "zero perdido (menos digitos que o esperado)"
    if len(digitos) > esperado:
        return "digitos demais (impossivel)"
    return "so digitos do tamanho certo"


def classificar_dinheiro(valor):
    if limpeza.eh_nulo(limpo(valor), zero_eh_nulo=False):
        return "vazio ou nulo disfarcado"
    nucleo = re.sub(r"[\s()\-]", "", valor.replace("R$", ""))
    if re.fullmatch(r"\d+", nucleo):
        return "so digitos (inteiro)"
    if re.fullmatch(r"\d+\.\d+", nucleo):
        return "ponto sozinho (ex.: 1234.56)"
    if re.fullmatch(r"\d+,\d+", nucleo):
        return "virgula sozinha (ex.: 1234,56)"
    if re.fullmatch(r"\d{1,3}(\.\d{3})+,\d+", nucleo):
        return "ponto de milhar + virgula decimal (1.234,56)"
    if re.fullmatch(r"\d{1,3}(,\d{3})+\.\d+", nucleo):
        return "virgula de milhar + ponto decimal (1,234.56)"
    if re.fullmatch(r"\d{1,3}(\.\d{3}){2,}", nucleo):
        return "ponto repetido (milhar, ex.: 1.234.567)"
    if re.fullmatch(r"\d{1,3}(,\d{3}){2,}", nucleo):
        return "virgula repetida (milhar, ex.: 1,234,567)"
    return "outro formato"


def classificar_data(valor):
    t = limpo(valor)
    if limpeza.eh_nulo(t):
        return "vazio ou nulo disfarcado"
    for padrao, nome in FORMATOS_DATA:
        if re.search(padrao, t):
            if limpeza.converter_data(t) is None:
                return f"{nome}  -> INVALIDA (data impossivel ou ano fora de 2000-2030)"
            return nome
    return "formato desconhecido"


# ---------------------------------------------------------------------------------------------
# Secoes da auditoria
# ---------------------------------------------------------------------------------------------
def secao_linhas_e_chaves(compras, itens, resultados):
    titulo("1) LINHAS, CHAVES REPETIDAS, ITENS SEM RESULTADO E CANCELADOS")
    print(f"   compras: {len(compras)} | itens: {len(itens)} | resultados: {len(resultados)}   (prova real: 2042 / 7077 / 15896)")
    print(f"   numero_controle_pncp repetido em compras: {compras['numero_controle_pncp'].duplicated().sum()}")
    print(f"   (numero_controle_pncp + numero_item) repetido em itens: "
          f"{itens.duplicated(['numero_controle_pncp', 'numero_item']).sum()}")
    cancelados = resultados["data_cancelamento"].map(limpo) != ""
    print(f"   resultados cancelados (data_cancelamento preenchida): {cancelados.sum()}")
    por_item = resultados.groupby(["numero_controle_pncp", "numero_item"]).size()
    print(f"   itens com mais de 1 resultado (classificados em Registro de Precos): {(por_item > 1).sum()}")

    validos = resultados[~cancelados]
    chaves_validas = set(zip(validos["numero_controle_pncp"], validos["numero_item"]))
    sem_resultado = sum(k not in chaves_validas for k in zip(itens["numero_controle_pncp"], itens["numero_item"]))
    print(f"   itens sem nenhum resultado valido (sem resultado ou so cancelados): {sem_resultado}   (prova real: 852)")
    print("   coluna tem_resultado nos itens:")
    mostrar(itens["tem_resultado"], recuo="      ")


def secao_documentos(compras, resultados):
    titulo("2) CNPJ/CPF: FORMATOS")
    print("   cnpj_orgao (compras), tratado como PJ:")
    cat = compras["cnpj_orgao"].map(lambda v: classificar_documento(v, "PJ"))
    mostrar(cat, recuo="      ")
    com_mascara = compras["cnpj_orgao"].map(limpo).str.contains(r"\D", regex=True).sum()
    print(f"      com mascara (pontos, barra ou hifen): {com_mascara}")

    print("   tipo_pessoa (resultados):")
    mostrar(resultados["tipo_pessoa"], recuo="      ")
    print("   ni_fornecedor (resultados), conforme o tipo_pessoa de cada linha:")
    cat = pd.Series([classificar_documento(ni, tp) for ni, tp in zip(resultados["ni_fornecedor"], resultados["tipo_pessoa"])])
    mostrar(cat, recuo="      ")
    nao_pe = resultados["tipo_pessoa"] != "PE"
    com_mascara = resultados.loc[nao_pe, "ni_fornecedor"].map(limpo).str.contains(r"\D", regex=True).sum()
    print(f"      com mascara (pontos, barra ou hifen), exceto estrangeiros: {com_mascara}")


def secao_dinheiro(tabelas):
    titulo("3) DINHEIRO E NUMEROS EM TEXTO: FORMATOS")
    for arquivo, colunas in COLUNAS_DINHEIRO.items():
        for coluna in colunas:
            serie = tabelas[arquivo][coluna]
            print(f"   {arquivo}.{coluna}:")
            mostrar(serie.map(classificar_dinheiro), recuo="      ")
            com_rs = serie.str.contains("R$", regex=False).sum()
            negativos = serie.str.contains(r"\(|-", regex=True).sum()
            invisiveis = serie.str.contains(INVISIVEIS, regex=True).sum()
            print(f"      com 'R$': {com_rs} | negativo (parenteses ou sinal): {negativos} | "
                  f"com espaco invisivel: {invisiveis}")


def secao_datas(tabelas):
    titulo("4) DATAS: FORMATOS E DATAS IMPOSSIVEIS")
    for arquivo, colunas in COLUNAS_DATA.items():
        for coluna in colunas:
            print(f"   {arquivo}.{coluna}:")
            mostrar(tabelas[arquivo][coluna].map(classificar_data), recuo="      ")


def secao_nulos(tabelas):
    titulo("5) NULOS DISFARCADOS POR COLUNA (so aparecem colunas com ocorrencias)")
    print("   Obs.: em colunas de numero o '0' e valor de verdade; aqui ele so e contado para voce saber onde existe.")
    for arquivo, df in tabelas.items():
        print(f"   {arquivo}.csv:")
        for coluna in df.columns:
            valores = df[coluna].astype(str).map(lambda v: limpo(v).upper())   # astype(str): numero_item ja foi convertido para int
            contagens = {}
            for token in sorted(limpeza.NULOS | {""}):
                n = int((valores == token).sum())
                if n:
                    contagens["(vazio)" if token == "" else token] = n
            if contagens:
                print(f"      {coluna}: {contagens}")


def secao_acentos(tabelas):
    titulo("6) ACENTOS QUEBRADOS (Ã§, Ã£...) E INVISIVEIS POR COLUNA")
    for arquivo, df in tabelas.items():
        print(f"   {arquivo}.csv:")
        for coluna in df.columns:
            texto = df[coluna].astype(str)
            quebrados = int(texto.str.contains(MOJIBAKE, regex=True).sum())
            invisiveis = int(texto.str.contains(INVISIVEIS, regex=True).sum())
            if quebrados or invisiveis:
                print(f"      {coluna}: acento quebrado = {quebrados} | espaco invisivel = {invisiveis}")


def secao_cronologia(compras, resultados):
    titulo("7) CRONOLOGIA: data_resultado (homologacao) x data_publicacao")
    publicacao = (compras.drop_duplicates("numero_controle_pncp")
                  .set_index("numero_controle_pncp")["data_publicacao"].map(limpeza.converter_data))
    r = resultados.copy()
    r["pub"] = pd.to_datetime(r["numero_controle_pncp"].map(publicacao))
    r["res"] = pd.to_datetime(r["data_resultado"].map(limpeza.converter_data))
    cancelado = r["data_cancelamento"].map(limpo) != ""
    for nome, parte in [("todos os resultados", r), ("so resultados nao cancelados", r[~cancelado])]:
        sem_data = parte["res"].isna() | parte["pub"].isna()
        print(f"   {nome} ({len(parte)}):")
        print(f"      sem data valida (resultado ou publicacao): {sem_data.sum()}")
        print(f"      homologacao ANTERIOR a publicacao (impossivel): {(parte['res'] < parte['pub']).sum()}")
        print(f"      homologacao no mesmo dia da publicacao (valida, ciclo 0): {(parte['res'] == parte['pub']).sum()}")
        print(f"      homologacao posterior a publicacao: {(parte['res'] > parte['pub']).sum()}")


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")        # para os acentos aparecerem ao redirecionar para arquivo
    except (AttributeError, ValueError):
        pass
    compras, itens, resultados = ler("compras"), ler("itens"), ler("resultados")
    for df in (itens, resultados):
        df["numero_item"] = df["numero_item"].astype(int)
    tabelas = {"compras": compras, "itens": itens, "resultados": resultados}

    secao_linhas_e_chaves(compras, itens, resultados)
    secao_documentos(compras, resultados)
    secao_dinheiro(tabelas)
    secao_datas(tabelas)
    secao_nulos(tabelas)
    secao_acentos(tabelas)
    secao_cronologia(compras, resultados)


if __name__ == "__main__":
    main()