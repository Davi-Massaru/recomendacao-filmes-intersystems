# Using IRIS - Vector Search

## Case Study: Movie Recommendation

This article explores the potential of Vector Search in InterSystems IRIS through a movie recommendation case study.

It demonstrates the steps needed for storing and querying records in the InterSystems IRIS database, covering table creation, record storage, and building a query application, which will be made available using the newest WSGI feature.

Finally, a Flask application will be developed that utilizes the Vector Search feature, implemented with embedded Python and run directly on an IRIS server.

## Why Vector Search?

Vector Search in InterSystems IRIS enables the storage and comparison of vectors, using them to identify semantically similar items, thus enhancing recommendation and information retrieval capabilities across various contexts.

In InterSystems IRIS, vectors are stored in tables as a specific data type, and functions like VECTOR_COSINE and VECTOR_DOT_PRODUCT are used to compare vector similarity. This feature simplifies the creation of recommendation systems by allowing an input vector to be compared with a set of stored vectors to find the most similar ones.

For example, in movie recommendations, movie descriptions can be transformed into vectors using language models such as those from the SentenceTransformer library.

## DATA SET

The dataset used for this tutorial can be found at:
https://www.kaggle.com/datasets/utkarshx27/movies-dataset

## Table Creation

To start storing data, it is necessary to create the table where the movies will be stored.

Since we are using the SentenceTransformer model ('all-MiniLM-L6-v2'), a specific column called `overviewVector` will be created to store the vectors.

The column will be defined with the data type `%Vector(DATATYPE = "DOUBLE", LEN = 384)`, which allows storing 384-dimensional vectors in a floating-point format.

To achieve this, we can run the following SQL:


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

Or create the table by coding the `.cls` class with the following file structure:

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

## VECTORIZATION

In this case, for data storage, the `SentenceTransformer('all-MiniLM-L6-v2')` model will be used. This model transforms sentences (or words) into a 384-element vector that captures the semantic features of the input, allowing the similarity between different texts to be compared through operations such as distance or dot product between vectors.


```py

from sentence_transformers import SentenceTransformer
model = SentenceTransformer('all-MiniLM-L6-v2') 
overview = "Exemplo de frase para vetorizar"
encode_search_vector = model.encode(overview, normalize_embeddings=True).tolist()
```
## Storing Vectors with INTERSYSTEMS IRIS

The code below demonstrates how to use Embedded Python to register the records contained in the dataset:


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

### Note:

To store records of type `%Vector`, the SQL function `TO_VECTOR(?)` is used, as shown in the script below:


```SQL
INSERT INTO dc.filmes (overviewVector) VALUES (TO_VECTOR(?))
```

In the Python code, it is necessary to convert the vector from a list to a string before inserting it into the database. This is done with the following line:

```python
str(row['overview_vector'])
```

By executing the command ```Do ##class(dc.util).PopularFilmes()``` in an InterSystems IRIS instance, the records will be correctly stored in the database, allowing queries and advanced search operations based on the stored vectors.

## Querying Similar Records

After storing the records, we will use the [VECTOR_DOT_PRODUCT](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_vectordotproduct) function.

As described in the documentation, the VECTOR_DOT_PRODUCT function finds the dot product of two input vectors. These vectors must be of numeric, integer, double, or decimal types. The result is the dot product value, represented as a double, which can be useful when trying to determine the similarity between two vectors.

The following SQL query retrieves the 5 most similar movies from a provided vector, using the dot product to measure similarity:


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

This approach allows the system to recommend movies that are semantically close to the query provided, offering more relevant suggestions to users.

Example of the query Python script:


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

## Coding with Flask and Embedded Python

Finally, making the feature available to the end user quickly and efficiently is facilitated by the use of Embedded Python in InterSystems IRIS. By using Flask, we can create a service in a single Python file:


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


# Final Result:

Finally, after making the feature available, prepare some popcorn and use the route:


``` http://localhost:52773/flaskapp/recomendar/<ID FILME> ``` 

When performing the query, you will receive a response in JSON similar to this:


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

This route will allow you to receive personalized recommendations based on the movie description you provided, making your movie selection experience easier and more enjoyable.

Enjoy!

