# Utilizando IRIS - Vector Search

## Estudo de Caso: Recomendação de Filmes

[Assista ao vídeo explicativo com conteúdo deste tutorial.](https://youtu.be/joLN9a8MY5c)

Este artigo explora o potencial do Vector Search do InterSystems IRIS em um estudo de caso para recomendação de filmes.

Serão demonstrados os passos necessários para o armazenamento e a consulta de registros no banco de dados InterSystems IRIS. Abordando a criação da tabela, armazenamento dos registros e a construção de uma aplicação de consulta, onde terá a disponibilização por meio do mais novo recurso WSGI. 

Ao final, será desenvolvida uma aplicação Flask que utilizará o recurso Vector Search, implementada com embedded python e executada diretamente em um servidor IRIS.

## Por que o Vector Search ? 

Com o Vector Search no InterSystems IRIS permite armazenar e comparar os vetores, utilizando vetores para identificar itens semanticamente semelhantes, o que amplia as capacidades de recomendação e recuperação de informações em diversos contextos. 

No InterSystems IRIS, vetores são armazenados em tabelas como um tipo de dado específico, e funções como VECTOR_COSINE e VECTOR_DOT_PRODUCT são usadas para comparar a similaridade entre vetores. Esse recurso facilita a criação de sistemas de recomendação, permitindo que um vetor de entrada seja comparado com um conjunto de vetores armazenados para encontrar os mais semelhantes.

No caso de recomendação de filmes, por exemplo, descrições de filmes podem ser transformadas em vetores utilizando modelos de linguagem, como os da biblioteca SentenceTransformer.


## DATA SET

O Dataset  utilizado para este tutorial está contido em :
https://www.kaggle.com/datasets/utkarshx27/movies-dataset

## Criação da tabela.

Para iniciar o armazenamento dos dados, é necessário criar a tabela onde os filmes serão armazenados.

Como estamos utilizando o modelo SentenceTransformer('all-MiniLM-L6-v2'), será criada uma coluna específica, chamada overviewVector, para armazenar os vetores.

A coluna será definida com o tipo de dado %Vector(DATATYPE = "DOUBLE", LEN = 384), que permite armazenar vetores de 384 dimensões em formato de ponto flutuante.

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

O código abaixo apresenta como podemos utilizar o Embedded Python para cadastrar os registros contidos no conjunto de dados (Data Set):

```python 
Class dc.util [ Language = python ]
{

ClassMethod PopularFilmes()
{
    import pandas as pd

    # PASSO 1: Lendo o arquivo .CSV.
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
    def preprocess_text(descricao) : 
        import re
        from string import punctuation
        from unidecode import unidecode
        
        descricao = descricao.lower()
        descricao = unidecode(descricao)
        descricao = re.sub(r'\d+','', descricao)
        descricao = descricao.translate(str.maketrans('', '', punctuation))
        
        return descricao

    data_frame['overview_preprocessado'] = data_frame['overview'].apply(preprocess_text)

    # PASSO 4: Realizando o encode e criação dos vetores.
    print("Criando o modelo/realiznado encode")
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    embeddings = model.encode(data_frame['overview_preprocessado'].tolist(), normalize_embeddings=True)
    data_frame['overview_vector'] = embeddings.tolist()

    # PASSO 5: Inserindo os registros no banco de dados.
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

Para realizar o armazenamento de registros do tipo %Vector, utiliza-se a função SQL TO_VECTOR(?), conforme mostrado no script abaixo:

```SQL
INSERT INTO dc.filmes (overviewVector) VALUES (TO_VECTOR(?))
```

No código Python, é necessário converter o vetor de uma lista para uma string antes de inseri-lo no banco de dados. Isso é feito com a seguinte linha:

```python
str(row['overview_vector'])
```

Ao executar o comando ```Do ##class(dc.util).PopularFilmes()``` em uma instância do InterSystems IRIS, os registros serão armazenados corretamente no banco de dados, permitindo consultas e operações de busca avançadas com base nos vetores armazenados.

## Consultando Registros Similares

Após o armazenamento dos registros, utilizaremos a função [VECTOR_DOT_PRODUCT](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_vectordotproduct).

Como descristo na documentação, a função VECTOR_DOT_PRODUCT encontra o produto escalar de dois vetores de entrada. Esses vetores devem ser do tipo numérico, inteiro, duplo ou decimal. O resultado é o valor do produto escalar, representado como um duplo, e pode ser útil ao tentar determinar a semelhança entre dois vetores.

 O SQL a seguir busca os 5 filmes mais semelhantes a partir de um vetor fornecido, utilizando o produto escalar para medir a similaridade:

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

Essa abordagem permite que o sistema recomende filmes que são semanticamente próximos ao que foi fornecido como consulta, oferecendo sugestões mais relevantes para os usuários.

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

## Codificando com flask e embedded python

Por fim, a disponibilização do recurso para o usuário final de maneira rápida e prática é facilitada pelo uso do Embedded Python do InterSystems IRIS. Utilizando o Flask, podemos criar um serviço em um único arquivo Python:

````python
from flask import Flask, jsonify, request
from sentence_transformers import SentenceTransformer

import iris

app = Flask(__name__)

@app.route('/recomendar/<id>', methods=['GET'])
def consulta(id):
    try:

        filme = iris.cls("dc.filmes")._OpenId(id)
        model = SentenceTransformer('all-MiniLM-L6-v2') 
        overview_preprocess = iris.cls("dc.util").Preprocess(filme.overview)
        encode_search_vector = model.encode(overview_preprocess, normalize_embeddings=True).tolist()
        
        query = """
            SELECT TOP 5 ID
            FROM dc.filmes 
            WHERE ID <> ?
            ORDER BY VECTOR_DOT_PRODUCT(overviewVector, TO_VECTOR(?)) DESC 
            """
        similares = []
        stmt = iris.sql.prepare(query)
        rs = stmt.execute(id, str(encode_search_vector))
        for idx, row in enumerate(rs):
            recomendacao = iris.cls("dc.filmes")._OpenId(row[0])
            similares.append({
                "title" : recomendacao.title,
                "originalTitle" : recomendacao.originalTitle,
                "genres" : recomendacao.genres,
                "overview" : recomendacao.overview,
                "keywords" : str(recomendacao.keywords),
                "director" : recomendacao.director,
                "popularity" : recomendacao.popularity,
                "productionCompanies" : recomendacao.productionCompanies,
                "releaseDate" : recomendacao.releaseDate
            })

        return jsonify({ 
            "Filme":{
                "title" : filme.title,
                "originalTitle" : filme.originalTitle,
                "genres" : filme.genres,
                "overview" : filme.overview,
                "keywords" : str(filme.keywords),
                "director" : filme.director,
                "popularity" : filme.popularity,
                "productionCompanies" : filme.productionCompanies,
                "releaseDate" : filme.releaseDate
            },
            "Similares" : similares
        })
        
    except Exception as e:
        return print(e)

if __name__ == '__main__':
    app.run(debug=True, port=52773, host='localhost')
````


# Resultado Final:

Por fim, após disponibilizar o recurso, prepare uma pipoca e utilize a rota:

``` http://localhost:52773/flaskapp/recomendar/<ID FILME> ``` 

Ao realizar a consulta, você receberá uma resposta em JSON semelhante a esta:

```JSON
{
  "Filme": {
    "director": "Justin Lin",
    "genres": "Action Adventure Science Fiction",
    "keywords": "sequel stranded hatred space opera",
    "originalTitle": "Star Trek Beyond",
    "overview": "The USS Enterprise crew explores the furthest reaches of uncharted space, where they encounter a mysterious new enemy who puts them and everything the Federation stands for to the test.",
    "popularity": 65.352913,
    "productionCompanies": "[{\"name\": \"Paramount Pictures\", \"id\": 4}, {\"name\": \"Bad Robot\", \"id\": 11461}, {\"name\": \"Perfect Storm Entertainment\", \"id\": 34530}, {\"name\": \"Alibaba Pictures Group\", \"id\": 69484}, {\"name\": \"Skydance Media\", \"id\": 82819}, {\"name\": \"Sneaky Shark\", \"id\": 83644}, {\"name\": \"Huahua Media\", \"id\": 83645}]",
    "releaseDate": "2016-07-07",
    "title": "Star Trek Beyond"
  },
  "Similares": [
    {
      "director": "Robert Wise",
      "genres": "Science Fiction Adventure Mystery",
      "keywords": "artificial intelligence uss enterprise starfleet san francisco self sacrifice",
      "originalTitle": "Star Trek: The Motion Picture",
      "overview": "When a destructive space entity is spotted approaching Earth, Admiral Kirk resumes command of the Starship Enterprise in order to intercept, examine, and hopefully stop it.",
      "popularity": 24.616634,
      "productionCompanies": "[{\"name\": \"Paramount Pictures\", \"id\": 4}]",
      "releaseDate": "1979-12-06",
      "title": "Star Trek: The Motion Picture"
    },
    {
      "director": "Leonard Nimoy",
      "genres": "Science Fiction Adventure",
      "keywords": "saving the world san francisco uss enterprise-a time travel whale",
      "originalTitle": "Star Trek IV: The Voyage Home",
      "overview": "Fugitives of the Federation for their daring rescue of Spock from the doomed Genesis Planet, Admiral Kirk (William Shatner) and his crew begin their journey home to face justice for their actions. But as they near Earth, they find it at the mercy of a mysterious alien presence whose signals are slowly destroying the planet. In a desperate attempt to answer the call of the probe, Kirk and his crew race back to the late twentieth century. However they soon find the world they once knew to be more alien than anything they've encountered in the far reaches of the galaxy!",
      "popularity": 22.258428,
      "productionCompanies": "[{\"name\": \"Paramount Pictures\", \"id\": 4}]",
      "releaseDate": "1986-11-25",
      "title": "Star Trek IV: The Voyage Home"
    },
    {
      "director": "Gary Nelson",
      "genres": "Adventure Family Science Fiction Action",
      "keywords": "killer robot space marine ghost ship black hole",
      "originalTitle": "The Black Hole",
      "overview": "The explorer craft U.S.S. Palomino is returning to Earth after a fruitless 18-month search for extra-terrestrial life when the crew comes upon a supposedly lost ship, the magnificent U.S.S. Cygnus, hovering near a black hole. The ship is controlled by Dr. Hans Reinhardt and his monstrous robot companion, Maximillian. But the initial wonderment and awe the Palomino crew feel for the ship and its resistance to the power of the black hole turn to horror as they uncover Reinhardt's plans.",
      "popularity": 8.265317,
      "productionCompanies": "[{\"name\": \"Walt Disney Productions\", \"id\": 3166}]",
      "releaseDate": "1979-12-18",
      "title": "The Black Hole"
    },
    {
      "director": "J.J. Abrams",
      "genres": "Action Adventure Science Fiction",
      "keywords": "spacecraft friendship sequel futuristic space",
      "originalTitle": "Star Trek Into Darkness",
      "overview": "When the crew of the Enterprise is called back home, they find an unstoppable force of terror from within their own organization has detonated the fleet and everything it stands for, leaving our world in a state of crisis.  With a personal score to settle, Captain Kirk leads a manhunt to a war-zone world to capture a one man weapon of mass destruction. As our heroes are propelled into an epic chess game of life and death, love will be challenged, friendships will be torn apart, and sacrifices must be made for the only family Kirk has left: his crew.",
      "popularity": 78.291018,
      "productionCompanies": "[{\"name\": \"Paramount Pictures\", \"id\": 4}, {\"name\": \"Skydance Productions\", \"id\": 6277}, {\"name\": \"Bad Robot\", \"id\": 11461}, {\"name\": \"Kurtzman/Orci\", \"id\": 12536}]",
      "releaseDate": "2013-05-05",
      "title": "Star Trek Into Darkness"
    },
    {
      "director": "Paul W.S. Anderson",
      "genres": "Horror Science Fiction Mystery",
      "keywords": "space marine nudity nightmare hallucination cryogenics",
      "originalTitle": "Event Horizon",
      "overview": "In the year 2047 a group of astronauts are sent to investigate and salvage the long lost starship \"Event Horizon\". The ship disappeared mysteriously 7 years before on its maiden voyage and with its return comes even more mystery as the crew of the \"Lewis and Clark\" discover the real truth behind its disappearance and something even more terrifying.",
      "popularity": 29.787135,
      "productionCompanies": "[{\"name\": \"Paramount Pictures\", \"id\": 4}, {\"name\": \"Impact Pictures\", \"id\": 248}, {\"name\": \"Golar Productions\", \"id\": 2484}]",
      "releaseDate": "1997-08-15",
      "title": "Event Horizon"
    }
  ]
}
```

Essa rota permitirá que você receba recomendações personalizadas baseadas na descrição do filme que você forneceu, tornando sua experiência de escolha de filme mais fácil e divertida

Aproveite!

