#!/bin/bash
# photoexif.sh
#
# Criador: Jeremias Alves Queiroz
# Data: 29/05/2024
#
# Versao 0.4: Unificada para JPG e TIFF.
#             Adiciona seleção de tipo de imagem por parâmetro (-t).
#             Melhora a leitura do CSV e a correspondência com fotos.
#             Implementa FilmType via -f ou prompt.
#             Novos mapeamentos para ImageDescription, UserComment, Comment, Keywords.

set -euo pipefail

# Define padroes iniciais das variaveis:
ajuda="
Execute esse script a partir do diretório onde se encontram o arquivo
de propriedades em formato .csv e os arquivos que devem receber as
entradas EXIF.

Antes de executar o script, tenha certeza que a quantidade de fotos e
de linhas de DADOS do arquivo .csv sejam iguais, e que os números na
nomenclatura das imagens e os índices (coluna _key) que constam no
arquivo .csv sejam compatíveis (ex: '1' no CSV para 'foto_1.jpg').
IMPORTANTE: o caractere divisor do arquivo .csv deve ser o ';'.

Uso: $(basename "$0") [OPCOES]

OPCOES:
-h, Exibe esta tela de ajuda
-v, Exibe a versao do script
-t <tipo>, Define o tipo de imagem a ser processado (jpg ou tif). OBRIGATÓRIO.
-c <arquivo_csv>, Caminho para o arquivo CSV. Opcional, por padrão busca '*.csv'.
-f <nome_filme>, Nome do filme (ex: 'Kodak Portra 400'). Se omitido, perguntará.

Como usar Keywords:
  No arquivo CSV gerado pelo 'prepare-afilm-data.sh', edite a coluna 'Keywords'.
  Use vírgulas para separar as palavras-chave (ex: 'praia,sol,marcela').
"

# Variáveis para armazenar os valores de entrada
IMAGE_TYPE=""
CSV_FILE=""
FILM_NAME="" # Nova variável para o nome do filme

while test -n "$1"
do
    case "$1" in
        -h)
            echo "$ajuda"
            exit 0
            ;;

        -v)
            echo -n $(basename "$0")
            # Extrai a versao diretamente dos cabecalhos do programa
            grep '^# Versao ' "$0" | tail -1 | cut -d : -f 1 | tr -d \#
            exit 0
            ;;
        -t)
            shift
            IMAGE_TYPE="$1"
            ;;
        -c)
            shift
            CSV_FILE="$1"
            ;;
        -f) # Novo parâmetro para o nome do filme
            shift
            FILM_NAME="$1"
            ;;
        *)
            echo "Erro: Opção inválida '$1'." >&2
            echo "$ajuda" >&2
            exit 1
            ;;
    esac
    shift
done

# --- Validação de Entradas ---

# Verifica se o tipo de imagem foi fornecido
if [ -z "$IMAGE_TYPE" ]; then
    echo "Erro: O tipo de imagem (-t jpg ou -t tif) é obrigatório." >&2
    echo "$ajuda" >&2
    exit 1
fi

# Verifica se o tipo de imagem é válido
if [[ "$IMAGE_TYPE" != "jpg" && "$IMAGE_TYPE" != "tif" ]]; then
    echo "Erro: Tipo de imagem inválido. Use 'jpg' ou 'tif'." >&2
    echo "$ajuda" >&2
    exit 1
fi

# Define o arquivo CSV a ser usado
if [ -z "$CSV_FILE" ]; then
    num_csv_files=$(find . -maxdepth 1 -name "*.csv" | wc -l)
    if [ "$num_csv_files" -eq 1 ]; then
        CSV_FILE=$(find . -maxdepth 1 -name "*.csv")
    elif [ "$num_csv_files" -gt 1 ]; then
        echo "Erro: Mais de um arquivo .csv encontrado no diretório atual. Use -c para especificar." >&2
        echo "$ajuda" >&2
        exit 1
    else
        echo "Erro: Nenhum arquivo .csv encontrado no diretório atual. Crie ou especifique com -c." >&2
        echo "$ajuda" >&2
        exit 1
    fi
fi

# Verifica se o arquivo CSV existe e é legível
if [ ! -f "$CSV_FILE" ] || [ ! -r "$CSV_FILE" ]; then
    echo "Erro: O arquivo CSV '$CSV_FILE' não existe ou não pode ser lido." >&2
    echo "$ajuda" >&2
    exit 1
fi

# Solicita o nome do filme se não foi fornecido via -f
if [ -z "$FILM_NAME" ]; then
    read -p "Qual o nome do filme que você usou para essas fotos (Deixe vazio para não preencher a tag)? " USER_FILM_INPUT
    FILM_NAME="$USER_FILM_INPUT"
fi


# Conta o número de imagens do tipo especificado
num_images=$(find . -maxdepth 1 -name "*.$IMAGE_TYPE" | wc -l)

if [ "$num_images" -eq 0 ]
then
    echo "Não há fotos .$IMAGE_TYPE no diretório atual." >&2
    echo "$ajuda" >&2
    exit 1
fi

# --- Leitura do CSV ---

# Declara arrays para armazenar os dados do CSV (agora 19 campos)
declare -a ar1 ar2 ar3 ar4 ar5 ar6 ar7 ar8 ar9 ar10 ar11 ar12 ar13 ar14 ar15 ar16 ar17 ar18 ar19

# Lê o CSV, pulando o cabeçalho (primeira linha)
# Garante que os dados comecem no índice 0 dos arrays.
while IFS=';' read -ra array; do
    if [[ -n "${array[0]##*( )}" ]]; then
        ar1+=("${array[0]}") # _key
        ar2+=("${array[1]}") # LensModel
        ar3+=("${array[2]}") # ApertureValue (sem f/)
        ar4+=("${array[3]}") # ExposureTime
        ar5+=("${array[4]}") # Date
        ar6+=("${array[5]}") # Exposure
        ar7+=("${array[6]}") # ImageDescription (do frame.note)
        ar8+=("${array[7]}") # GPSLatitude
        ar9+=("${array[8]}") # GPSLongitude
        ar10+=("${array[9]}") # FocalLength (extraído)
        ar11+=("${array[10]}") # GPSLatitudeRef ("S")
        ar12+=("${array[11]}") # GPSLongitudeRef ("W")
        ar13+=("${array[12]}") # Make (cameraName)
        ar14+=("${array[13]}") # Model (cameraName)
        ar15+=("${array[14]}") # LensMake (para preencher manualmente no CSV)
        ar16+=("${array[15]}") # ISO
        ar17+=("${array[16]}") # Author
        ar18+=("${array[17]}") # UserComment_Comment (global note)
        ar19+=("${array[18]}") # Keywords (para preencher manualmente no CSV)
    fi
done < <(tail -n +2 "$CSV_FILE")

# Verifica se o número de linhas de dados no CSV é consistente com o número de fotos
csv_data_lines="${#ar1[@]}"

if [ "$csv_data_lines" -eq 0 ]; then
    echo "Erro: Nenhuma linha de dados encontrada no arquivo CSV após pular o cabeçalho." >&2
    exit 1
fi

if [ "$csv_data_lines" -ne "$num_images" ]; then
    echo "Aviso: O número de linhas de dados no CSV ($csv_data_lines) não corresponde" >&2
    echo "ao número de fotos .$IMAGE_TYPE encontradas ($num_images)." >&2
    echo "Isso pode causar resultados inesperados. Verifique seus arquivos." >&2
fi

echo "Processando $num_images fotos .$IMAGE_TYPE com base em $csv_data_lines entradas CSV."
[ -n "$FILM_NAME" ] && echo "  -> Nome do filme para 'FilmType': '$FILM_NAME'" || echo "  -> Tag 'FilmType' será deixada vazia."

# --- Loop de Processamento ---

for (( i=0; i<csv_data_lines; i++ ))
do
    photo_file_pattern="*${ar1[$i]}.$IMAGE_TYPE"
    matched_files=$(find . -maxdepth 1 -name "$photo_file_pattern")

    if [ -z "$matched_files" ]; then
        echo "Aviso: Nenhuma foto correspondente encontrada para a chave '${ar1[$i]}' (padrão: $photo_file_pattern). Pulando." >&2
        continue
    fi

    echo "  -> Processando foto(s) com chave '${ar1[$i]}'..."

    # Constrói o comando exiftool dinamicamente
    EXIF_COMMAND="exiftool -overwrite_original"

    # Adiciona tags se os valores não estiverem vazios
    [ -n "${ar13[$i]}" ] && EXIF_COMMAND+=" -Make=\"${ar13[$i]}\""
    [ -n "${ar14[$i]}" ] && EXIF_COMMAND+=" -Model=\"${ar14[$i]}\""
    [ -n "${ar15[$i]}" ] && EXIF_COMMAND+=" -LensMake=\"${ar15[$i]}\""
    [ -n "${ar10[$i]}" ] && EXIF_COMMAND+=" -FocalDistance=\"${ar10[$i]}\" -FocalLength=\"${ar10[$i]}\""
    [ -n "${ar2[$i]}" ] && EXIF_COMMAND+=" -LensModel=\"${ar2[$i]}\""
    [ -n "${ar16[$i]}" ] && EXIF_COMMAND+=" -ISO=\"${ar16[$i]}\""
    [ -n "${ar5[$i]}" ] && EXIF_COMMAND+=" -Date=\"${ar5[$i]}\" -DateTimeOriginal=\"${ar5[$i]}\" -CreateDate=\"${ar5[$i]}\""
    [ -n "${ar3[$i]}" ] && EXIF_COMMAND+=" -ApertureValue=\"${ar3[$i]}\" -Fnumber=\"${ar3[$i]}\""
    [ -n "${ar4[$i]}" ] && EXIF_COMMAND+=" -ExposureTime=\"${ar4[$i]}\" -ShutterSpeedValue=\"${ar4[$i]}\""
    [ -n "${ar6[$i]}" ] && EXIF_COMMAND+=" -Exposure=\"${ar6[$i]}\""
    [ -n "${ar11[$i]}" ] && EXIF_COMMAND+=" -GPSLatitudeRef=\"${ar11[$i]}\""
    [ -n "${ar12[$i]}" ] && EXIF_COMMAND+=" -GPSLongitudeRef=\"${ar12[$i]}\""
    [ -n "${ar8[$i]}" ] && EXIF_COMMAND+=" -GPSLatitude=\"${ar8[$i]}\""
    [ -n "${ar9[$i]}" ] && EXIF_COMMAND+=" -GPSLongitude=\"${ar9[$i]}\""
    [ -n "${ar7[$i]}" ] && EXIF_COMMAND+=" -ImageDescription=\"${ar7[$i]}\"" # Nova atribuição para ImageDescription
    [ -n "${ar18[$i]}" ] && EXIF_COMMAND+=" -Comment=\"${ar18[$i]}\" -UserComment=\"${ar18[$i]}\"" # Nova atribuição para Comment/UserComment
    [ -n "${ar17[$i]}" ] && EXIF_COMMAND+=" -Author=\"${ar17[$i]}\""
    [ -n "$FILM_NAME" ] && EXIF_COMMAND+=" -FilmType=\"$FILM_NAME\"" # Adiciona FilmType
    [ -n "${ar19[$i]}" ] && EXIF_COMMAND+=" -Keywords=\"${ar19[$i]}\"" # Adiciona Keywords

    # Executa o comando exiftool
    eval "$EXIF_COMMAND" "$matched_files"
done

echo "Processamento de metadados EXIF concluído para os arquivos .$IMAGE_TYPE."
echo "Lembre-se de verificar os arquivos para confirmar as alterações."
