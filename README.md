# Projeto Final – Módulo 2: Esteira Analítica de Contratações Públicas (PNCP 2025)

## Turma: Análise de Dados com Python [T2]
## Aluno: Eric Felipe Barros Marques

## 1. Contexto do problema
 
A Controladoria identificou gargalos operacionais severos nas compras e contratações públicas federais:
 
- **Indícios de sobrepreço** em itens homologados, com valores pagos acima do estimado.
- **Concentração atípica de contratos** em determinados grupos econômicos.
- **Morosidade** entre a publicação dos editais e o fechamento dos certames.
- **Baixa adesão competitiva** em certas modalidades de licitação.
O cenário se agrava porque os sistemas legados de onde os dados são extraídos não possuem travas de validação na entrada. O repositório bruto reúne anomalias como identificadores (CNPJ/CPF) corrompidos, valores monetários preenchidos em texto livre, inconsistências de cronograma (homologação anterior à publicação do edital), formatos de data despadronizados, nulos disfarçados e textos com a codificação quebrada. Por isso, a liderança governamental não confia nos relatórios gerados diretamente dessa base e não consegue decidir ou auditar com segurança.
 
Este projeto responde a esse problema com uma esteira analítica ponta a ponta, que transforma os dados brutos em um ambiente confiável, auditável e voltado à decisão executiva:
 
```
CSVs brutos (PNCP) → Python (auditoria + limpeza) → MySQL (Star Schema) → Power BI (dashboard)
```
 
O trabalho foi desenvolvido no papel de analista de dados de uma consultoria de inteligência governamental que atende órgãos de controle e transparência pública.
 
### Base de dados
 
Os dados vêm do Portal Nacional de Contratações Públicas (PNCP) e abrangem contratações de órgãos federais publicadas em 2025, de 02/01/2025 a 31/12/2025 (12 meses consecutivos), usadas por inteiro. A extração já foi feita e os arquivos estão em `data/raw/`. Trata-se de uma amostra ao longo do ano, e não da totalidade das contratações do país. Três arquivos se relacionam por `numero_controle_pncp` e `numero_item`:
 
```
compras (2.042 contratações) ──< itens (7.077) ──< resultados (15.896)
```
 
O cabeçalho dos certames (órgão, data, modalidade) é cruzado com os itens licitados (quantidades, valores unitários estimados e homologados, descrições) e com os fornecedores classificados em cada item.
 
### Perguntas de negócio
 
| # | Tema | Pergunta |
|---|---|---|
| 1 | Economia global | Qual o percentual e o valor nominal economizado (diferença entre estimado e homologado)? |
| 2 | Concentração e risco de fornecedores | Quem são os maiores fornecedores em volume e qual percentual do orçamento se concentra neles? |
| 3 | Eficácia por modalidade | Quais modalidades trazem maior deságio e quais concentram o maior volume de recursos? |
| 4 | Tempo do ciclo de compras | Qual a duração média, em dias, entre o edital e a homologação, por órgão? |
| 5 | Distribuição regional | Quais estados e regiões concentram as maiores despesas e os melhores descontos? |
| 6 | Perfil dos gastos | Como os recursos se distribuem entre bens, serviços e obras e engenharia? |
 
## 2. Tecnologias
 
- Python 3 com pandas (limpeza e montagem das tabelas)
- MySQL, acessado com `mysql-connector-python`
- Power BI Desktop e DAX (modelo de dados, Calendário, medidas e dashboard)
- Git/GitHub (versionamento)
## 3. Estrutura do repositório
 
```
data/
  raw/                CSVs brutos (compras, itens, resultados)
  processed/          tabelas geradas pelo pipeline (não versionadas)
src/
  config.py           caminhos e configuração do banco (lê o .env)
  banco.py            conexão e utilitários do MySQL
  limpeza.py          funções de limpeza de texto, documentos, números e datas
  montar_tabelas.py   aplica as regras de negócio e gera a fato e as dimensões
  carregar.py         carga no MySQL
  auditoria.py        conta os problemas dos CSVs brutos, antes da limpeza
sql/
  01_criar_banco.sql  criação do banco e das tabelas do modelo estrela
  02_perguntas.sql    consultas das 6 perguntas de negócio
powerbi/              arquivo .pbix do dashboard
docs/
  img/                imagens da documentação (modelo estrela no Power BI e figura das Sprints)
```
 
## 4. Como reproduzir
 
Os comandos abaixo são para Windows (PowerShell). Rode tudo a partir da **raiz do projeto**.
 
**1. Clonar e criar o ambiente**
```
git clone https://github.com/EricMarques/ProjetoFinalModulo2.git
cd ProjetoFinalModulo2
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```
 
**2. Configurar o banco**
Copie `.env.example` para `.env` e preencha usuário, senha, host e porta do seu MySQL. O nome do banco é `pncp_controladoria`. O `.env` não é versionado.
 
**3. Rodar o pipeline, nesta ordem**
```
python -m src.auditoria         # (opcional) conta os problemas dos CSVs brutos
python -m src.limpeza            # autoteste das funções de limpeza
python -m src.montar_tabelas     # gera a fato e as dimensões em data/processed/
python -m src.carregar           # cria o banco e carrega as tabelas no MySQL
```
 
**4. Consultas das perguntas de negócio**
Abra `sql/02_perguntas.sql` no MySQL Workbench (ou outro cliente) e rode as consultas, uma por vez, no banco `pncp_controladoria`.
 
**5. Power BI**
Instale o MySQL Connector/NET 8.x (site oficial `dev.mysql.com`) e abra o `.pbix` de `powerbi/` no Power BI Desktop. Se o servidor ou as credenciais forem diferentes, ajuste em *Transformar dados → Configurações da fonte de dados* e use **Atualizar** para reler as tabelas. A senha do MySQL não é guardada no arquivo.
 
> Os scripts são executados com `python -m src.nome` (como módulo), e não com `python src\nome.py`. Na segunda forma o Python não encontra o pacote `src` e dá `ModuleNotFoundError`.
 
## 5. Auditoria dos dados brutos
 
A auditoria foi feita sobre os CSVs de `data/raw/` lidos como texto (`dtype=str`), antes de qualquer limpeza, com o script `src/auditoria.py` (`python -m src.auditoria`). As contagens abaixo respondem às perguntas da etapa de diagnóstico: quantas linhas há, se existem chaves repetidas, quais formatos de documento, dinheiro e data aparecem, onde há nulos disfarçados e acentos quebrados e se existem homologações anteriores à publicação.
 
### 5.1 Estrutura e chaves
 
| Verificação | Resultado |
|---|---|
| Linhas de `compras.csv` / `itens.csv` / `resultados.csv` | 2.042 / 7.077 / 15.896 |
| `numero_controle_pncp` repetido em `compras.csv` | 0 |
| Chave de item (`numero_controle_pncp` + `numero_item`) repetida em `itens.csv` | 0 |
| Itens com `tem_resultado` verdadeiro / falso | 6.225 / 852 |
| Itens sem nenhum resultado válido (sem resultado ou só cancelados) | 852 |
| Resultados cancelados (`data_cancelamento` preenchida) | 62 |
| Itens com mais de um resultado classificado (Registro de Preços) | 466 |
 
### 5.2 Documentos (CNPJ/CPF)
 
| Coluna | Problema | Registros afetados |
|---|---|---|
| `cnpj_orgao` (compras) | zero à esquerda perdido | 77 de 2.042 (3,8%) |
| `cnpj_orgao` (compras) | com máscara (pontos, barra, hífen) | 176 |
| `ni_fornecedor` (resultados) | zero à esquerda perdido | 353 de 15.896 (2,2%) |
| `ni_fornecedor` (resultados) | com máscara, exceto estrangeiros | 1.631 |
| `ni_fornecedor` (resultados) | estrangeiros (`tipo_pessoa` = PE), documento sem padrão | 21 |
 
`tipo_pessoa` tem 11.344 PJ, 4.531 PF e 21 PE. Nenhum documento tem dígitos demais.
 
### 5.3 Dinheiro e números em texto
 
Nas 8 colunas abaixo não há valores vazios nem negativos (parênteses ou sinal), mas os formatos se misturam e há `R$` e espaços invisíveis até em quantidades.
 
| Coluna | Ponto sozinho (1234.56) | Vírgula sozinha (1234,56) | 1.234,56 | 1,234.56 | Com `R$` | Com espaço invisível |
|---|---|---|---|---|---|---|
| `compras.valor_total_estimado` | 1.533 | 42 | 403 | 64 | 344 | 86 |
| `compras.valor_total_homologado` | 1.523 | 36 | 406 | 77 | 346 | 77 |
| `itens.quantidade` | 5.596 | 1.262 | 185 | 34 | 1.148 | 264 |
| `itens.valor_unitario_estimado` | 5.475 | 953 | 536 | 113 | 1.188 | 301 |
| `itens.valor_total_estimado` | 5.415 | 359 | 1.103 | 200 | 1.171 | 299 |
| `resultados.quantidade_homologada` | 12.472 | 2.245 | 974 | 205 | 2.561 | 622 |
| `resultados.valor_unitario_homologado` | 12.282 | 2.077 | 1.279 | 258 | 2.650 | 704 |
| `resultados.valor_total_homologado` | 12.064 | 690 | 2.625 | 517 | 2.647 | 698 |
 
Cerca de 75% a 79% dos valores aparecem com ponto sozinho, que é onde a regra de separadores do enunciado (ponto ou vírgula sozinho é sempre decimal) decide o resultado.
 
### 5.4 Datas
 
As datas de publicação e de homologação aparecem em 7 formatos diferentes cada, e todas são válidas (nenhuma data impossível ou fora do intervalo de 2000 a 2030).
 
| Formato | `data_publicacao` (2.042) | `data_resultado` (15.896) |
|---|---|---|
| AAAA-MM-DD | | 10.301 |
| AAAA-MM-DDTHH:MM:SS | 1.319 | |
| DD/MM/AAAA | 117 | 929 |
| DD/MM/AAAA com hora | 126 | 934 |
| DD-MM-AAAA | 138 | 912 |
| DD.MM.AAAA | 120 | 937 |
| AAAA/MM/DD | 116 | 960 |
| AAAAMMDD | 106 | 923 |
 
As colunas `data_abertura_proposta` e `data_encerramento_proposta` (não usadas na fato) têm 617 vazios cada, e a de encerramento tem ainda 65 datas impossíveis ou com ano fora de 2000 a 2030.
 
### 5.5 Nulos disfarçados e vazios
 
Textos que significam "sem valor" (`-`, `0`, `N/A`, `NULL`, `NÃO INFORMADO`, `SEM INFORMAÇÃO`, `NÃO SE APLICA`) encontrados por coluna:
 
| Coluna | Ocorrências | Detalhe |
|---|---|---|
| `compras.processo` | 77 | `-` 16, `0` 12, `N/A` 16, `NULL` 18, `NÃO INFORMADO` 5, `SEM INFORMAÇÃO` 10 |
| `compras.modo_disputa` | 967 | `NÃO SE APLICA` 904 e 63 de outros tokens |
| `itens.situacao_item` | 220 | `-` 29, `0` 25, `N/A` 67, `NULL` 44, `NÃO INFORMADO` 24, `SEM INFORMAÇÃO` 31 |
| `itens.categoria_item` | 7.077 | todos `NÃO SE APLICA` (a coluna não ajuda, como o enunciado avisa) |
| `itens.criterio_julgamento` | 1.883 | `NÃO SE APLICA` |
| `resultados.porte` | 4.893 | `NÃO INFORMADO` 4.468 e 425 de outros tokens |
 
O `"0"` só é nulo em campos de texto; em quantidades e valores é um número.
 
Campos vazios: `data_abertura_proposta` e `data_encerramento_proposta` (617 cada), `unidade_medida` (9), `catalogo_codigo_item` (7.068), `ordem_classificacao_srp` (11.976, vazio vale 1 na escolha do vencedor) e `data_cancelamento` (15.834, vazio significa resultado não cancelado).
 
### 5.6 Acentos quebrados e espaços invisíveis
 
Acentos quebrados (UTF-8 lido como Latin-1, como `Ã§` e `Ã£`):
 
| Coluna | Registros afetados |
|---|---|
| `itens.descricao` | 116 |
| `compras.objeto_compra` | 43 |
| `compras.municipio` | 28 |
| `compras.nome_unidade` | 14 |
| `resultados.nome_fornecedor` | 1 |
 
Espaços invisíveis (largura zero e espaço sem quebra) aparecem em 16 colunas de texto, documentos e números. Os maiores casos: `ni_fornecedor` (990), `valor_unitario_homologado` (704), `valor_total_homologado` (698), `quantidade_homologada` (622) e `nome_fornecedor` (424).
 
### 5.7 Cronologia
 
Comparando `data_resultado` com a `data_publicacao` da contratação, em todos os 15.896 resultados:
 
| Situação | Resultados |
|---|---|
| Homologação **anterior** à publicação (impossível) | 234 |
| Homologação no mesmo dia da publicação (válida, ciclo 0) | 1.239 |
| Homologação posterior à publicação | 14.423 |
| Sem data válida | 0 |
 
Como nenhuma data está ausente, os 230 itens sem ciclo na fato correspondem a homologações anteriores à publicação entre os vencedores que permaneceram na base. Eles continuam na fato, com `data_homologacao` e `dias_ciclo` vazios (regra 7).
 
## 6. Limpeza (`src/limpeza.py`)
 
Cada função resolve um problema e tem exemplos de teste que rodam com `python -m src.limpeza`.
 
| Função | O que faz | Por quê |
|---|---|---|
| `tirar_espacos` | remove espaços das pontas e repetidos (inclusive o espaço "sem quebra") | evitar que o mesmo nome apareça de formas diferentes |
| `eh_nulo` / `limpar_texto` | trata textos que significam "sem valor" e devolve `None`; conserta acento quebrado | o `"0"` só é nulo em campo de texto; em número, zero é valor |
| `padronizar_nome` | maiúsculas e hífen com espaço dos dois lados | agrupar órgãos, fornecedores e itens pelo mesmo nome |
| `limpar_documento` | deixa só dígitos e devolve os zeros à esquerda (14 para CNPJ, 11 para CPF); estrangeiros ficam como estão | impedir que o mesmo CNPJ com e sem máscara vire dois fornecedores |
| `converter_numero` | converte dinheiro e números em texto para `float` | ver regra de separadores abaixo |
| `converter_data` | aceita 6 formatos, descarta a hora e só aceita anos de 2000 a 2030 | datas impossíveis e `0001-01-01` viram vazio |
 
**Regra de separadores numéricos.** Nesta base, um ponto ou uma vírgula sozinho é sempre o separador decimal (`0,754` vale 0,754 e `746.815` vale 746,815). Só o símbolo repetido indica milhar (`1.234.567`) e, quando aparecem os dois, o último é o decimal. Valores entre parênteses ou com `-` viram negativos. Essa regra é do enunciado e contraria a convenção brasileira usual (em que `1.500` seria mil e quinhentos). Um erro na primeira versão da função, que removia a vírgula em vez de trocá-la por ponto, inflava o volume total para R$ 139 bi. O autoteste e a conferência com a prova real revelaram o problema.
 
## 7. Montagem das tabelas (`src/montar_tabelas.py`)
 
O script lê os três CSVs como texto, aplica a limpeza e as regras de negócio e grava a fato e as 4 dimensões em `data/processed/`.
 
**Regras aplicadas**
1. **Grão da fato:** uma linha por item de contratação (`numero_controle_pncp` + `numero_item`).
2. **Um vencedor por item:** primeiro são descartados os resultados cancelados (`data_cancelamento` preenchida) e só depois permanece o de menor ordem de classificação (vazio vale 1). O desempate é pelo menor `sequencial_resultado`, lido como número. A ordem importa: se o 1º colocado estiver cancelado, o 2º assume.
3. **Só itens com resultado:** itens sem resultado (852) ficam de fora e não contam como rejeitados.
4. **Itens rejeitados (99):** quantidade vazia ou ≤ 0; valor unitário estimado ou homologado ausente ou ≤ 0; orçamento sigiloso; valor total estimado < R$ 1; homologado mais de 1.000× o estimado; qualquer valor total acima de R$ 1 trilhão. A condição é escrita na forma `~(coluna > 0)` para que valores vazios (NaN) também sejam rejeitados.
5. **Valores:** `valor_total = valor_unitario × quantidade`, usando a quantidade homologada (ou a do item quando vier vazia ou zero) tanto no estimado quanto no homologado.
6. **Comparável e economia:** o item é comparável quando não é Credenciamento (modalidade 12) e a razão homologado ÷ estimado está entre 0,1 e 10. A economia só conta os comparáveis, e o percentual é soma da economia ÷ soma do estimado comparável.
7. **Cronologia:** homologação anterior à publicação fica sem data e sem ciclo, mas o item continua na fato. Mesmo dia vale 0 dia de ciclo.
8. **Perfil do gasto:** Bens, Serviços ou Obras e engenharia. Palavras de obra procuradas como palavra inteira (`\b`) na descrição do item e no objeto da compra: obra(s), construção, reforma, engenharia. Obras tem prioridade sobre as outras classes.
9. **Dimensões** (órgão, fornecedor, modalidade, localidade) montadas a partir da fato, com chave substituta (`sk_`) e a chave natural. Fornecedor sem documento recebe `NAO-INFORMADO`.
**Conferência com a prova real do professor**
 
| Indicador | Resultado | Esperado |
|---|---|---|
| Itens na fato | 6.126 | 6.126 |
| Itens rejeitados | 99 | 99 |
| Contratações distintas | 1.962 | 1.962 |
| Fornecedores | 2.652 | 2.652 |
| Órgãos (CNPJ) | 363 | 363 |
| Volume homologado | R$ 8.044.498.805,74 | R$ 8.044.498.805,74 |
| Itens comparáveis | 5.457 | 5.457 |
| Economia % (comparáveis) | 14,46% | 14,46% |
| Ciclo médio / máximo (dias) | 48,1 / 611 | 48,1 / 611 |
| Itens sem ciclo | 230 | 230 |
| Perfil (Obras / Serviços / Bens) | 60,8% / 36,6% / 2,6% | 60,8% / 36,6% / 2,6% |
 
**Observações**
- **Hífen em `padronizar_nome`:** troca todo `-` por ` - `, o que também afeta palavras como "guarda-chuva". Como vale igual para todos os registros, não prejudica o agrupamento.
- **Palavras de obra:** um item é classificado como Obras e engenharia quando a descrição do item ou o objeto da compra contém, como palavra inteira (limite `\b`), uma destas: `obra` (e `obras`), `construção` (com ou sem acento), `reforma` e `engenharia`. Plurais como `reformas` e `construções` não entram. A regra tem prioridade sobre Bens e Serviços, e o limite de palavra evita falsos positivos como "cobrança" e "dobradiça". Com essas palavras o perfil ficou em 60,8% de Obras e engenharia, 36,6% de Serviços e 2,6% de Bens do volume homologado.
- **`economia_valor`:** nos itens não comparáveis o valor é gravado como 0 (e não NULL). Como a economia só é somada onde `comparavel = 1`, a soma e o percentual de economia não mudam; apenas médias da coluna por item seriam afetadas, então o dashboard deve sempre filtrar por `comparavel`.
## 8. Modelagem dimensional (MySQL)
 
Star Schema com 1 fato (`fato_item_contratado`) e 4 dimensões (`dim_orgao`, `dim_fornecedor`, `dim_modalidade`, `dim_localidade`) no banco `pncp_controladoria`.
 
O script `sql/01_criar_banco.sql` cria o banco e as tabelas do zero. Ele começa removendo as tabelas existentes (a fato primeiro, por causa das FKs), então a carga pode ser repetida. É executado pelo `src/carregar.py`, sem passo manual no Workbench.
 
```mermaid
erDiagram
    dim_orgao ||--o{ fato_item_contratado : "sk_orgao"
    dim_fornecedor ||--o{ fato_item_contratado : "sk_fornecedor"
    dim_modalidade ||--o{ fato_item_contratado : "sk_modalidade"
    dim_localidade ||--o{ fato_item_contratado : "sk_localidade"
 
    dim_orgao {
        int sk_orgao PK
        varchar cnpj_orgao UK
        varchar nome_orgao
        varchar poder
    }
    dim_fornecedor {
        int sk_fornecedor PK
        varchar ni_fornecedor UK
        varchar nome_fornecedor
        varchar tipo_pessoa
        varchar porte
    }
    dim_modalidade {
        int sk_modalidade PK
        int modalidade_id UK
        varchar nome_modalidade
    }
    dim_localidade {
        int sk_localidade PK
        char uf_sigla UK
        varchar uf_nome
        varchar regiao
    }
    fato_item_contratado {
        int sk_fato PK
        varchar numero_controle_pncp UK
        int numero_item UK
        int sk_orgao FK
        int sk_fornecedor FK
        int sk_modalidade FK
        int sk_localidade FK
        date data_publicacao
        date data_homologacao
        text descricao_item
        varchar perfil_gasto
        decimal quantidade
        decimal valor_unitario_estimado
        decimal valor_unitario_homologado
        decimal valor_total_estimado
        decimal valor_total_homologado
        tinyint comparavel
        decimal economia_valor
        int dias_ciclo
    }
```
 
**Decisões de modelagem**
 
| Decisão | Motivo |
|---|---|
| Chave substituta `sk_` (INT, AUTO_INCREMENT) em todas as tabelas; chave natural (CNPJ, sigla, id) em UNIQUE | a chave substituta não depende do dado de origem; o UNIQUE impede duplicar a mesma unidade, fornecedor, modalidade ou UF |
| `UNIQUE (numero_controle_pncp, numero_item)` na fato | o banco garante o grão da fato (regra 1) |
| FKs da fato para as 4 dimensões | nenhuma linha da fato aponta para uma dimensão inexistente; por isso as dimensões são carregadas antes da fato |
| DECIMAL em vez de FLOAT: `(18,2)` para totais e `(18,4)` para unitários e quantidade | evita erro de arredondamento em valores monetários |
| CHECK: `quantidade > 0`, valores não negativos e `comparavel` em 0 ou 1 | segunda barreira depois das regras de rejeição do Python (regra 4); só é aplicado a partir do MySQL 8.0.16 |
| Sem CHECK em `economia_valor` | ela pode ser negativa nos itens com sobrepreço |
| `data_homologacao`, `dias_ciclo` e `economia_valor` aceitam NULL | homologação anterior à publicação fica sem data e sem ciclo (regra 7) |
 
**Carga (`src/carregar.py`):** executa o `.sql`, carrega as 4 dimensões e depois a fato, em lote (`executemany`), tudo na mesma transação. Antes de confirmar, o script confere as contagens de cada tabela com a prova real e procura FK solta (linhas da fato sem correspondente em cada dimensão). Se qualquer etapa falhar ou divergir, o `rollback` desfaz o que estava pendente, a conexão é fechada no `finally` e o script termina com código de erro. Só depois das validações o `commit` grava os dados de vez. O `inserir_em_lote` do `banco.py` recebe o parâmetro `commitar` (padrão `True`) para permitir esse adiamento.
 
### Validação da carga
 
Depois de `python -m src.carregar`, o banco foi conferido com a prova real e com consultas de integridade.
 
| Tabela | Linhas no banco | Esperado |
|---|---|---|
| fato_item_contratado | 6.126 | 6.126 |
| dim_orgao | 363 | 363 |
| dim_fornecedor | 2.652 | 2.652 |
| dim_modalidade | 7 | 7 |
| dim_localidade | 27 | 27 |
 
**Integridade referencial:** uma consulta com `LEFT JOIN` da fato para cada uma das 4 dimensões, filtrando `WHERE dimensão IS NULL`, retornou 0 linhas nas quatro. Não há FK solta. Essa verificação também faz parte da própria carga (`verificar_fk`), que a executou com 0 solta(s) em cada dimensão e terminou com "Carga concluida e validada".
 
**Totais no banco:**
 
| Indicador | No banco | Prova real |
|---|---|---|
| Itens na fato | 6.126 | 6.126 |
| Volume homologado | R$ 8.044.498.805,74 | R$ 8.044.498.805,74 |
| Itens comparáveis | 5.457 | 5.457 |
| Estimado comparável | R$ 6.867.663.469,91 | R$ 6.867.663.469,91 |
| Economia nominal | R$ 992.861.686,95 | R$ 992.861.686,95 |
| Itens com ciclo | 5.896 | 5.896 |
| Ciclo médio / máximo (dias) | 48,1 / 611 | 48,1 / 611 |
 
**Restrição CHECK:** dentro de uma transação (revertida com `ROLLBACK`), a tentativa de inserir uma linha na fato com `quantidade = 0` foi recusada pelo banco por violar a restrição `ck_fato_quantidade`. Isso confirma a segunda barreira das regras de rejeição do Python (regra 4).
 
**Teste de falha e rollback:** para verificar o controle de falhas da carga, o nome de uma coluna da fato foi alterado de propósito (`numero_controle_pnc`, sem o "e" final) em `src/carregar.py`. A carga inseriu as 4 dimensões, falhou ao montar a fato e terminou com a mensagem "Falha na carga, alteracoes desfeitas". Em seguida, a contagem de `dim_orgao`, `dim_fornecedor`, `dim_modalidade`, `dim_localidade` e `fato_item_contratado` retornou 0 em todas, o que confirma que o `rollback` desfez as inserções que estavam pendentes e o banco não fica com dados pela metade. Depois do teste, o nome da coluna foi corrigido e a carga rodada de novo.
 
**Fornecedor sem documento:** nenhuma linha `NAO-INFORMADO` foi criada em `dim_fornecedor` (contagem 0), então não foi necessária a linha "Não informado" (sk = -1) e nenhum fornecedor sem documento distorce o ranking de concentração.
 
### Modelo no Power BI
 
As 5 tabelas do banco foram importadas no modo Importar e relacionadas em estrela: cada dimensão se liga à fato por uma relação 1:N, pela chave substituta (`sk_`), com filtro em uma direção (da dimensão para a fato). As colunas técnicas ficam ocultas na visão de relatório.
 
![Modelo estrela no Power BI](docs/img/layout_estrela.png)
 
O tempo é uma tabela Calendário criada em DAX, com limites tirados do mínimo e do máximo das datas da fato (e não digitados), e não de uma hierarquia automática de data, que foi desligada nas opções do arquivo. Ela tem colunas de ano, mês e ano-mês, com o nome do mês ordenado pelo número do mês e o ano-mês ordenado por um número AAAAMM. O Calendário se relaciona com as duas datas da fato: `data_publicacao` (relação ativa) e `data_homologacao` (inativa, usada nas medidas com `USERELATIONSHIP`). O intervalo vai até 2026, porque o ciclo máximo (611 dias) leva algumas homologações para o ano seguinte.
 
### Medidas DAX
 
As 15 medidas ficam em uma tabela própria (`Medidas`), organizadas em pastas de exibição, uma por pergunta de negócio. Todas são medidas explícitas, sem soma implícita de colunas, escritas com variáveis (`VAR`/`RETURN`) e com `CALCULATE`, `DIVIDE`, `TOPN`, `RANKX` e iteradoras (`AVERAGEX`). Os percentuais são sempre soma ÷ soma.
 
| Pasta | Medida | O que calcula |
|---|---|---|
| P1 Economia | Valor Estimado Comparável | soma do valor estimado só dos itens comparáveis |
| P1 Economia | Volume Homologado | soma do valor total homologado de todos os itens |
| P1 Economia | Economia (R$) | estimado comparável menos homologado dos itens comparáveis |
| P1 Economia | Economia % | economia ÷ estimado comparável |
| P1 Economia | % de Itens Comparáveis | itens comparáveis ÷ total de itens |
| P2 Fornecedores | Participação do Fornecedor % | volume do fornecedor ÷ volume total (o total ignora o filtro de fornecedor) |
| P2 Fornecedores | Ranking do Fornecedor | posição por volume (`RANKX`), válida quando a linha é um único fornecedor |
| P2 Fornecedores | Concentração Top 10 % | volume dos 10 maiores fornecedores (`TOPN` + `KEEPFILTERS`) ÷ volume total |
| P3 Modalidades | Participação no Volume % | volume da linha atual ÷ volume total |
| P3 Modalidades | Deságio vs Média Geral (p.p.) | economia % da linha menos a economia % geral, em pontos percentuais |
| P4 Ciclo | Ciclo Médio (dias) | média dos dias entre publicação e homologação, ignorando itens sem ciclo |
| P4 Ciclo | Ciclo Máximo (dias) | maior ciclo observado |
| P4 Ciclo | Itens sem Ciclo | total de itens menos itens com ciclo |
| P5 Regional | Qtd Unidades Compradoras | contagem distinta de órgãos (CNPJ) na fato |
| P6 Perfil | Ticket Médio por Item (R$) | volume homologado ÷ quantidade de itens |
 
**Decisões**
- A economia só considera os itens comparáveis (`comparavel = 1`), como no SQL.
- `Qtd Unidades Compradoras` conta `sk_orgao` na fato (e não na dimensão), porque o filtro de UF ou de região chega à fato e não à `dim_orgao`. Como alguns CNPJs aparecem em mais de uma UF, os valores por UF e por região não devem ser somados entre linhas.
- `Deságio vs Média Geral` é formatada como número com uma casa decimal (pontos percentuais), e não como percentual.
- `Ranking do Fornecedor` só mostra valor quando o contexto da linha é um único fornecedor (`ni_fornecedor`); no total, fica em branco.
- Além das 15 medidas obrigatórias, a medida auxiliar `Itens com Ciclo` (pasta P4 Ciclo) conta os itens com ciclo e permite filtrar a tabela de órgãos para mostrar só os que têm 5 ou mais itens com ciclo, como na consulta do SQL.
**Conferência com o SQL.** Os valores das medidas foram comparados com os resultados das consultas de `sql/02_perguntas.sql`, e todos coincidiram:
 
| Medida (contexto) | Valor |
|---|---|
| Valor Estimado Comparável | R$ 6.867.663.469,91 |
| Volume Homologado | R$ 8.044.498.805,74 |
| Economia (R$) / Economia % | R$ 992.861.686,95 / 14,46% |
| % de Itens Comparáveis | 89,08% |
| Concentração Top 10 % | 41,43% |
| Ranking do Fornecedor | NOW SEGUROS SA em 1º, com 13,18% do volume |
| Ciclo Médio / Máximo / Itens sem Ciclo | 48,1 / 611 / 230 |
| Qtd Unidades Compradoras | 363 no total; 78 no DF; 107 no Centro-Oeste |
| Participação no Volume % (Concorrência - Eletrônica) | 58,43% |
| Deságio vs Média Geral (Pregão - Eletrônico) | 24,02% menos 14,46% da média geral, cerca de 9,6 p.p. |
| Ticket Médio por Item (Obras e engenharia) | R$ 5.059.320,30 |
 
## 9. Respostas às perguntas de negócio (SQL)
 
As consultas estão em `sql/02_perguntas.sql`, e os resultados abaixo vêm da execução no banco `pncp_controladoria`. Todos os percentuais são soma ÷ soma, e a economia só considera os itens comparáveis.
 
### Pergunta 1 – Economia global do Poder Público
 
| Indicador | Valor |
|---|---|
| Itens na fato | 6.126 |
| Itens comparáveis | 5.457 (89,08%) |
| Volume homologado total | R$ 8.044.498.805,74 |
| Estimado (itens comparáveis) | R$ 6.867.663.469,91 |
| Homologado (itens comparáveis) | R$ 5.874.801.782,96 |
| **Economia nominal** | **R$ 992.861.686,95** |
| **Economia %** | **14,46%** |
 
**Itens com sobrepreço** (homologado maior que o estimado): 60 na fato inteira e **27** entre os itens comparáveis. O valor de 27 informado no enunciado corresponde, portanto, à contagem só entre os comparáveis.
 
**Leitura:** nos itens comparáveis, o governo pagou 14,46% abaixo do estimado, o que representa R$ 992,86 milhões de economia sobre R$ 6,87 bilhões estimados. Os 669 itens não comparáveis (Credenciamento e razão fora de 0,1 a 10) ficam fora do cálculo, mas entram no volume.
 
### Pergunta 2 – Concentração e risco de fornecedores
 
Os 10 maiores fornecedores por volume homologado (fornecedor = CNPJ/CPF já limpo):
 
| # | Fornecedor | CNPJ | Itens | Volume (R$) | % do volume total |
|---|---|---|---|---|---|
| 1 | NOW SEGUROS SA | 46973571000103 | 1 | 1.060.000.000,00 | 13,18% |
| 2 | CONSTRUTORA CIDADE LIMITADA | 92943398000118 | 1 | 524.935.394,97 | 6,53% |
| 3 | BANCO BRADESCO S.A. | 60746948000112 | 1 | 379.194.320,07 | 4,71% |
| 4 | CONSTRUTORA NORTE BRASIL LTDA. | 31596625000191 | 1 | 335.401.470,80 | 4,17% |
| 5 | LCM CONSTRUCAO E COMERCIO S.A | 19758842000135 | 1 | 228.885.493,53 | 2,85% |
| 6 | CONSTRUTORA OTIMA LTDA | 45776055000126 | 1 | 192.344.816,46 | 2,39% |
| 7 | CONPATE ENGENHARIA LTDA | 41320417000119 | 1 | 166.644.303,41 | 2,07% |
| 8 | INDIGO HIVE CONSULTORIA EM TECNOLOGIA DA INFORMACAO S.A. | 38217648000197 | 1 | 160.000.000,00 | 1,99% |
| 9 | CONSTRUTORA HIDROS LTDA | 12066346000171 | 1 | 159.193.730,62 | 1,98% |
| 10 | ARTELESTE CONSTRUCOES LIMITADA | 75911438000120 | 1 | 125.884.500,00 | 1,56% |
 
Juntos, os 10 maiores somam **R$ 3.332.484.029,86, ou 41,43%** do volume homologado total.
 
**Leitura:** cada um dos 10 maiores aparece com apenas 1 item. A concentração vem de poucos itens de valor muito alto, e não de fornecedores com muitos contratos: só o primeiro (NOW SEGUROS SA) responde por 13,18% de todo o volume.
 
### Pergunta 3 – Eficácia por modalidade
 
| Modalidade | Itens | Volume (R$) | % do volume | Economia % |
|---|---|---|---|---|
| Pregão - Eletrônico | 3.046 | 502.223.491,28 | 6,24% | 24,02% |
| Concorrência - Eletrônica | 521 | 4.700.493.122,98 | 58,43% | 14,27% |
| Inexigibilidade | 503 | 213.365.238,19 | 2,65% | 8,77% |
| Concorrência - Presencial | 63 | 444.752.757,18 | 5,53% | 6,79% |
| Dispensa | 1.387 | 39.887.350,44 | 0,50% | 4,49% |
| Pregão - Presencial | 5 | 2.475.288,51 | 0,03% | 0,02% |
| Credenciamento | 601 | 2.141.301.557,16 | 26,62% | — |
 
**Leitura:** o Pregão Eletrônico tem o maior deságio (24,02%), mas movimenta só 6,24% do volume. A Concorrência Eletrônica concentra 58,43% dos recursos, com 14,27% de economia. O Credenciamento responde por 26,62% do volume e não tem economia calculada, porque nenhum de seus itens é comparável (o estimado é um teto global).
 
### Pergunta 4 – Tempo do ciclo de compras
 
**Visão geral:** 5.896 itens com ciclo, 230 sem ciclo (homologação anterior à publicação), ciclo médio de 48,1 dias e máximo de 611 dias.
 
Órgãos com maior ciclo médio, considerando só órgãos com 5 ou mais itens com ciclo (agrupados pelo nome padronizado):
 
| Órgão | Unidades | Itens com ciclo | Ciclo médio (dias) | Máximo (dias) |
|---|---|---|---|---|
| UNIVERSIDADE FEDERAL DE CAMPINA GRANDE | 1 | 16 | 266,3 | 309 |
| CONSELHO FEDERAL DE ENGENHARIA E AGRONOMIA | 1 | 20 | 223,0 | 223 |
| DNIT - DEPARTAMENTO NACIONAL DE INFRAEST DE TRANSPORTES | 12 | 62 | 156,2 | 437 |
| UNIVERSIDADE FEDERAL DO ESTADO DO RIO DE JANEIRO | 1 | 26 | 135,4 | 176 |
| INSTITUTO FEDERAL DE EDUCACAO,CIENCIA E TECNOLOGIA DE RONDONIA | 1 | 9 | 125,0 | 226 |
| UNIVERSIDADE FEDERAL DE ALAGOAS | 1 | 34 | 108,0 | 370 |
| INSTITUTO FEDERAL DE EDUCACAO, CIENCIA E TECNOLOGIA DO PARANA | 1 | 30 | 107,8 | 155 |
| UNIVERSIDADE FEDERAL DO RIO GRANDE DO NORTE | 1 | 123 | 101,7 | 378 |
| CONSELHO REGIONAL DE MEDICINA DO ESTADO DE MINAS GERAIS | 1 | 6 | 100,3 | 111 |
| DEFENSORIA PUBLICA DA UNIAO | 1 | 11 | 100,0 | 154 |
 
**Leitura:** os maiores ciclos médios estão na Universidade Federal de Campina Grande (266,3 dias) e no Conselho Federal de Engenharia e Agronomia (223,0 dias), bem acima da média geral de 48,1 dias. O DNIT é o único da lista com várias unidades compradoras (12) e tem ciclo médio de 156,2 dias.
 
### Pergunta 5 – Distribuição regional
 
Por região:
 
| Região | Unidades compradoras | Itens | Volume (R$) | % do volume | Economia % |
|---|---|---|---|---|---|
| Centro-Oeste | 107 | 940 | 3.559.879.991,73 | 44,25% | 17,02% |
| Nordeste | 106 | 1.155 | 1.850.420.285,02 | 23,00% | 14,18% |
| Sudeste | 120 | 2.072 | 1.083.309.811,49 | 13,47% | 11,62% |
| Sul | 65 | 1.325 | 1.021.624.955,41 | 12,70% | 7,96% |
| Norte | 59 | 634 | 529.263.762,09 | 6,58% | 21,43% |
 
Dez estados com maior volume:
 
| UF | Estado | Região | Unidades compradoras | Itens | Volume (R$) | % do volume | Economia % |
|---|---|---|---|---|---|---|---|
| DF | Distrito Federal | Centro-Oeste | 78 | 585 | 3.135.638.456,35 | 38,98% | 15,90% |
| RS | Rio Grande do Sul | Sul | 31 | 845 | 820.584.056,64 | 10,20% | 7,18% |
| RJ | Rio de Janeiro | Sudeste | 46 | 933 | 461.925.602,27 | 5,74% | 11,57% |
| PI | Piauí | Nordeste | 11 | 70 | 408.389.525,89 | 5,08% | 5,98% |
| SP | São Paulo | Sudeste | 41 | 517 | 393.783.392,48 | 4,90% | 9,22% |
| PE | Pernambuco | Nordeste | 31 | 170 | 277.610.822,64 | 3,45% | 18,75% |
| CE | Ceará | Nordeste | 21 | 160 | 273.063.635,47 | 3,39% | 7,88% |
| BA | Bahia | Nordeste | 29 | 222 | 243.705.954,94 | 3,03% | 25,01% |
| MT | Mato Grosso | Centro-Oeste | 15 | 77 | 240.920.586,26 | 2,99% | 25,84% |
| AC | Acre | Norte | 9 | 40 | 207.336.488,34 | 2,58% | 26,71% |
 
**Leitura:** o Distrito Federal concentra 38,98% do volume (e o Centro-Oeste, 44,25%). Em desconto, o Norte lidera entre as regiões (21,43%) e o Sul tem o menor (7,96%). Entre os estados, os maiores deságios estão no Acre (26,71%), em Mato Grosso (25,84%) e na Bahia (25,01%), todos com volume bem menor que o do DF.
 
**Observação:** as unidades compradoras por UF somam 609 e por região somam 457, acima dos 363 CNPJs de órgãos. Isso indica que a localidade vem da contratação (`uf_sigla` de `compras.csv`) e que alguns CNPJs aparecem em mais de uma UF. Por isso os valores de unidades não devem ser somados entre linhas.
 
### Pergunta 6 – Perfil dos gastos
 
| Perfil | Itens | Volume (R$) | % do volume | Ticket médio (R$) | Economia % |
|---|---|---|---|---|---|
| Obras e engenharia | 967 | 4.892.362.732,70 | 60,8% | 5.059.320,30 | 14,17% |
| Serviços | 1.849 | 2.940.950.885,18 | 36,6% | 1.590.562,94 | 16,11% |
| Bens | 3.310 | 211.185.187,86 | 2,6% | 63.802,17 | 14,19% |
 
**Leitura:** Obras e engenharia respondem por 60,8% do volume com apenas 967 itens, e seu ticket médio (R$ 5,06 milhões) é muito maior que o de Bens (R$ 63,8 mil). Bens são 54% dos itens (3.310 de 6.126), mas só 2,6% dos recursos. Serviços têm a maior economia entre os perfis (16,11%).
 
## 10. Dashboard no Power BI
 
O dashboard tem 6 páginas, uma para cada pergunta de negócio. Todas seguem a mesma estrutura: a **pergunta** como título, os **números** (cartões e visuais) e a **conclusão** em uma caixa de texto no rodapé. Os valores são os mesmos das consultas de `sql/02_perguntas.sql`.
 
| Página | Pergunta | Medidas | Visuais |
|---|---|---|---|
| 1 Economia | Quanto o governo economizou? | Volume Homologado, Valor Estimado Comparável, Economia (R$), Economia %, % de Itens Comparáveis | 5 cartões e gráfico de colunas da economia por mês de publicação |
| 2 Fornecedores | Quem concentra o orçamento? É um risco? | Volume Homologado, Concentração Top 10 %, Participação do Fornecedor %, Ranking do Fornecedor | 2 cartões e tabela dos 10 maiores fornecedores |
| 3 Modalidades | Qual modalidade economiza mais e qual movimenta mais? | Volume Homologado, Economia %, % de Itens Comparáveis, Participação no Volume %, Deságio vs Média Geral (p.p.) | 3 cartões e 2 gráficos de barras (participação no volume e deságio) |
| 4 Ciclo | Onde as compras demoram mais? | Ciclo Médio, Ciclo Máximo, Itens sem Ciclo, Itens com Ciclo, Qtd Unidades Compradoras | 3 cartões e tabela por órgão (5 ou mais itens com ciclo) |
| 5 Regional | Onde se gasta mais e onde há mais desconto? | Volume Homologado, Economia %, Qtd Unidades Compradoras, Participação no Volume % | 3 cartões, mapa de árvore por região e estado e gráfico de dispersão gasto × desconto por UF |
| 6 Perfil | Em que o dinheiro público é gasto? | Volume Homologado, Economia %, Ticket Médio por Item, Participação no Volume % | 3 cartões, rosca do volume por perfil e gráfico de colunas (ticket médio) com linha (economia %) |
 
**Navegação e interatividade**
- **Menu retrátil:** em cada página, o botão ☰ abre um painel de navegação, e o ✕ o fecha. A abertura e o fechamento usam indicadores (bookmarks) por página, e o navegador de páginas destaca em laranja a página atual.
- **Dica de ferramenta personalizada:** a página oculta *Tooltip Modalidade* aparece ao passar o mouse sobre as barras do gráfico de participação no volume (página 3), com volume homologado, economia %, % de itens comparáveis e ciclo médio da modalidade.
- **Dicas de ferramenta padrão** nos gráficos de dispersão (página 5) e de ticket médio (página 6).
**Princípios de design (CRAP)**
- **Contraste:** o laranja é usado só para o que responde à pergunta (por exemplo, a economia e a maior fatia), em contraste com o azul-escuro e o azul-acinzentado.
- **Repetição:** mesmo cabeçalho, mesma grade de 1280 × 720, mesmas fontes (Segoe UI) e mesmos tamanhos em todas as páginas.
- **Alinhamento:** posições e tamanhos definidos numericamente, com margem de 24 px e espaço de 16 px entre os blocos.
- **Proximidade:** cada pergunta reúne seus números e visuais no mesmo bloco, com a conclusão logo abaixo.
- Visuais escolhidos conforme a pergunta (colunas, tabelas, barras, mapa de árvore, dispersão, rosca e colunas com linha), e eixos sempre iniciando em zero.
## 11. Planejamento em Sprints
 
O trabalho foi organizado em Sprints no GitHub Projects, com histórias, tarefas e sub-tarefas vinculadas às issues do repositório. A figura abaixo mostra, para cada Sprint, o nome, o período, as tarefas e o status de cada uma.
 
![Sprints do projeto](docs/img/sprints.png)