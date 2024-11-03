Class dc.util [ Language = python ]
{

ClassMethod PopularFilmes()
{
    import pandas as pd

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
    data_frame['overview'].replace("", float("NaN"), inplace=True)
    data_frame = data_frame.dropna(subset=['overview'])

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

    data_frame['overview_preprocessado'] = data_frame['overview'].apply(preprocess_text)

    print("Criando o modelo realiznado encode")
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    embeddings = model.encode(data_frame['overview_preprocessado'].tolist(), normalize_embeddings=True)
    data_frame['overview_vector'] = embeddings.tolist()

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