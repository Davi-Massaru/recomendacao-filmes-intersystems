# Utilizando IRIS - VECTOR SEARCH

## Estudo de caso recomendando filmes

Artigo aborda o potencial do Vector Search do IRIS intersystems, em um estudo de caso para indicação de filmes.

Este tutorial demonstra o passo a passo para armazenar e consultar registros no banco de dados Intersystems IRIS, abordando a criação da tabela, armazenamento dos registros, contrução de aplicação de consulta e disponibilização por meio do mais novo recurso WSGI.

No final teremos uma aplicação flask que explora o recurso VECTOR SEARCH, contuida utilizando embedded python, rodando dentro de um servidor IRIS

## Por que o VECTOR SEARCH ? 

Com o Vector Search, é possível armazenar vetores diretamente no banco de dados do Intersystems IRIS. A partir da comparação entre vetores, o sistema pode identificar quais são os mais similares ao vetor fornecido, permitindo a construção de soluções avançadas de busca e recomendação.

## DATA SET

O Dataset  utilizado para este tutorial está contido em :
https://www.kaggle.com/datasets/utkarshx27/movies-dataset

## Criação da tabela.

Primeiramente para armazenamento dos dados é necesário realizar a criação da tabela onde os filmes serão armazenados. 

Como estamos utilizando o SentenceTransformer('all-MiniLM-L6-v2'), iremos criar a coluna responsável por armazenar os vetores "overviewVector" com a definição  %Vector(DATATYPE = "DOUBLE", LEN = 384).


Para isso, podemos rodar o sql:

```SQL
CREATE TABLE dc.filmes (
    title VARCHAR(255),
    originalTitle VARCHAR(255),
    genres VARCHAR(255),
    overview VARCHAR(200000),
    keywords VARCHAR(255),
    director VARCHAR(255),
    popularity VARCHAR(255),
    productionCompanies VARCHAR(255),
    releaseDate VARCHAR(255),
    overviewVector VECTOR(DOUBLE, 384)
)
```

Ou realizar a criação codificando a classe .cls criando a seguinte estrutura de arquivo:

``` ObjectScript
Class dc.filmes Extends %Persistent
{

Property title As %String(MAXLEN = "");

Property originalTitle As %String(MAXLEN = "");

Property director As %String(MAXLEN = "");

Property popularity As %String(MAXLEN = "");

Property releaseDate As %String(MAXLEN = "");

Property genres As %String(MAXLEN = "");

Property overview As %String(MAXLEN = "");

Property keywords As %String(MAXLEN = "");

Property productionCompanies As %String(MAXLEN = "");

Property overviewVector As %Vector(DATATYPE = "DOUBLE", LEN = 384);
}

``` 

## VETORIZANDO

Neste caso, para o armazenamento dos dados, será utilizado o SentenceTransformer('all-MiniLM-L6-v2'), este modelo transforma frases (ou palavras) em um vetor de 384 elementos que capturam características semânticas da entrada, permitindo que a similaridade entre diferentes textos seja comparada através de operações como a distância ou o produto escalar entre vetores.

```py

from sentence_transformers import SentenceTransformer
model = SentenceTransformer('all-MiniLM-L6-v2') 
overview = "Exemplo de frase para vetorizar"
encode_search_vector = model.encode(overview, normalize_embeddings=True).tolist()
```

## Armazenado Vector com INTERSYSTEM IRIS 

O código a baixo, apresenta como podemos utilizar o embedded  python para o cadastro dos registros contidos no Data Set:

```python 
Class dc.util [ Language = python ]
{

ClassMethod PopularFilmes()
{
    import pandas as pd

    # PASSO 1:  lendo o .CSV.
    corpus_url = '/opt/irisbuild/movie_dataset.csv'
    df_original = pd.read_csv(corpus_url)
    data_frame = df_original[
        [
        'title',
        'original_title',
        'genres',
        'overview',
        'keywords',
        'director',
        'popularity',
        'production_companies',
        'release_date'
        ]
    ]

    # PASSO 2: Excluindo registros em branco "NaN".
    data_frame['overview'].replace("", float("NaN"), inplace=True)
    data_frame = data_frame.dropna(subset=['overview'])

    # PASSO 3: Aplicando o pré-processamento.
    data_frame['overview_preprocessado'] = data_frame['overview'].apply(preprocess_text)
    #Exemplo do processo de pré processamento de dados.
    def preprocess_text(descricao) : 
        import re
        from string import punctuation
        from unidecode import unidecode
        
        descricao = descricao.lower()
        descricao = unidecode(descricao)
        descricao = re.sub(r'\d+','', descricao)
        descricao = descricao.translate(str.maketrans('', '', punctuation))
        
        return descricao

    # PASSO 4: realiznado encode, criação dos vetores.
    print("Criando o modelo/realiznado encode")
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    embeddings = model.encode(data_frame['overview_preprocessado'].tolist(), normalize_embeddings=True)
    data_frame['overview_vector'] = embeddings.tolist()

    # PASSO 5: Inserindo os registros no banco de dados
    import iris
    print("Cadastrando Filmes")
    query = """
        INSERT INTO dc.filmes 
        (title,
        originalTitle,
        genres,
        overview,
        keywords,
        director,
        popularity,
        productionCompanies,
        releaseDate,
        overviewVector)
        VALUES (?,?,?,?,?,?,?,?,?,TO_VECTOR(?))
        """
    stmt = iris.sql.prepare(query)
    for index, row in data_frame.iterrows():
        rs = stmt.execute(
            row['title'],
            row['original_title'],
            row['genres'],
            row['overview'],
            row['keywords'],
            row['director'],
            row['popularity'],
            row['production_companies'],
            row['release_date'],
            str(row['overview_vector'])
        )
}

}
```

### Observação:
```SQL
INSERT INTO dc.filmes (overviewVector) VALUES (TO_VECTOR(?))
```

Como visto no script, para realizar o armazenamento de regitros do tipo %Vector, utilize a função SQL TO_VECTOR(?), convertendo o valor de List() para String:

```python
str(row['overview_vector'])
```

Ao executar ```Do ##class(dc.util).PopularFilmes()``` em uma instancia IRIS, os registros serão armazenados no banco de dados.

## Consultando registros similares

Após o armazenamento dos registros, utilizaremos a função [VECTOR_DOT_PRODUCT](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_vectordotproduct).

Como descristo na documentação:,

    A função VECTOR_DOT_PRODUCT encontra o produto escalar de dois vetores de entrada. Esses vetores devem ser do tipo numérico, inteiro, duplo ou decimal. O resultado é o valor do produto escalar, representado como um duplo, e pode ser útil ao tentar determinar a semelhança entre dois vetores.

 O SQL a seguir busca os 5 filmes mais semelhantes a partir de um vetor fornecido, usando o produto escalar entre vetores para medir similaridade:

```SQL
    SELECT TOP 5 ID
    FROM dc.filmes 
    WHERE ID <> ?
    ORDER BY VECTOR_DOT_PRODUCT(overviewVector, TO_VECTOR(?)) DESC 
```

- SELECT TOP 5 ID: Retorna os 5 primeiros IDs na lista ordenada.
- FROM dc.filmes: Consulta a tabela filmes no banco de dados.
- WHERE ID <> ?: Exclui o ID fornecido da busca.
- ORDER BY VECTOR_DOT_PRODUCT: Ordena os resultados pela similaridade entre o vetor overviewVector e o vetor gerado por TO_VECTOR(?), em ordem decrescente.

Exemplo da consulta script python:

```py
import iris
from sentence_transformers import SentenceTransformer

# Abrindo o Registro desejado
filme = iris.cls("dc.filmes")._OpenId(id)

# Recriando vetor armazenado de overview
model = SentenceTransformer('all-MiniLM-L6-v2') 
overview_preprocess = preprocess_text(filme.overview)
encode_search_vector = model.encode(overview_preprocess, normalize_embeddings=True).tolist()

# Consulta SQL
query = """
    SELECT TOP 5 ID
    FROM dc.filmes 
    WHERE ID <> ?
    ORDER BY VECTOR_DOT_PRODUCT(overviewVector, TO_VECTOR(?)) DESC 
    """
stmt = iris.sql.prepare(query)
rs = stmt.execute(id, str(encode_search_vector))

# Visualização retorno da consulta
for idx, row in enumerate(rs):
    recomendacao = iris.cls("dc.filmes")._OpenId(row[0])
    print(recomendacao.title)
```


## Subindo aplicação com WSGI nativo 

## video demonstrativo:

