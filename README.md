# Recomendando filmes com intersystems IRIS - VECTOR SEARCH

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

## TRATAMENTO DE DADOS 

## VECTORIZANDO

Neste caso, para o armazenamento dos dados, será utilizado o SentenceTransformer('all-MiniLM-L6-v2'), este modelo 


## Armazenado Vector com INTERSYSTEM IRIS 

## Subindo aplicação com WSGI nativo 

## video demonstrativo:

