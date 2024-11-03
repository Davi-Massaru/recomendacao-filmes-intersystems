
from flask import Flask, jsonify, request
from sentence_transformers import SentenceTransformer

import iris

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({"say":"PING"})

@app.route('/recomendar/<id>', methods=['GET'])
def consulta(id):
    try:
        filme = iris.cls("dc.filmes")._OpenId(id)
        model = SentenceTransformer('all-MiniLM-L6-v2') 
        overview_preprocess = preprocess_text(filme.overview)
        encode_search_vector = model.encode(overview_preprocess, normalize_embeddings=True).tolist()
        
        query = """
            SELECT TOP 5 ID
            FROM dc.filmes 
            WHERE ID <> ?
            ORDER BY VECTOR_DOT_PRODUCT(overviewVector, TO_VECTOR(?)) DESC 
            """
        similares = []
        stmt = iris.sql.prepare(query)
        rs = stmt.execute(id, filme.genres, str(encode_search_vector))
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

def preprocess_text(descricao) : 
    import re
    from string import punctuation
    from unidecode import unidecode
    # Converter para minúsculo
    descricao = descricao.lower()
    # Remover acentuação
    descricao = unidecode(descricao)
    # Remover números
    descricao = re.sub(r'\d+','', descricao)
    # Remover pontuação
    descricao = descricao.translate(str.maketrans('', '', punctuation))
    
    return descricao

if __name__ == '__main__':
    app.run(debug=True, port=52773, host='localhost')
