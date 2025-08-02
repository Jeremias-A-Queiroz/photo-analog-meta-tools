#!/bin/bash
# prepare-analog-meta-data.sh
#
# Criador: Jeremias Alves Queiroz
# Data: 01/08/2025 (Refatorado por Gemini)
#
# Versao 0.2.0: Prepara dados do Afilm para EXIF.
#               - Corrige a extração da distância focal ('Focal') no AWK.
#               - Ajusta o formato da data para 'YYYY:MM:DD HH:MM:SS' (padrão EXIF).
#               - Corrige erros de sintaxe nos comentários do AWK.
#               - Renomeado de 'prepare-afilm-data.sh' para escopo mais amplo.

set -euo pipefail

ajuda="
Este script descompacta o arquivo do Afilm, extrai os dados JSON,
converte-os para um CSV com o delimitador ';', e prepara para edição local.

Uso: $(basename "$0") <ARQUIVO_ZIP_AFILM>

Exemplo: $(basename "$0") AfilmLabs_2025-06-24.zip

Instruções para edição no Emacs e uso de Keywords:
  1. Após a geração do CSV, abra-o no Emacs: M-x find-file RET <arquivo.csv> RET
  2. Ative o modo CSV: M-x csv-mode RET (para alinhar colunas: C-c C-e)
  3. Edite as colunas 'LensMake' e 'Keywords' conforme necessário.
     - 'LensMake': Digite o nome do fabricante da lente se desejar.
     - 'Keywords': Use vírgulas (ex: 'praia,sol,marcela') para separar palavras-chave.
                   O exiftool e plataformas como Flickr geralmente as interpretam.
"

if [ "$#" -ne 1 ]; then
    echo "Erro: Forneça o caminho para o arquivo .zip do Afilm." >&2
    echo "$ajuda" >&2
    exit 1
fi

AFILM_ZIP_FILE="$1"
OUTPUT_CSV_FILE="afilm_data_$(date +%Y%m%d_%H%M%S).csv" # Nome de arquivo único

if [ ! -f "$AFILM_ZIP_FILE" ]; then
    echo "Erro: Arquivo zip '$AFILM_ZIP_FILE' não encontrado." >&2
    exit 1
fi

echo "Descompactando '$AFILM_ZIP_FILE' e extraindo 'data.json'..."

unzip -p "$AFILM_ZIP_FILE" data.json | \
jq -r '
    . as $root |
    # Gera a linha de cabeçalho
    (["_key", "LensModel", "Aperture", "ShutterSpeed", "Date", "Exposure", "ImgDesc", "Latitude", "Longitude", "Focal", "LatRef", "LonRef", "Make", "Model", "LensMake", "ISO", "Author", "GlobalNote", "Keywords"] | join(";")),
    # Itera sobre cada frame para gerar as linhas de dados
    ($root.frames | to_entries[] | .key as $_key | .value as $frame |
    [ # <--- CORREÇÃO JQ ANTERIOR: COLCHETES PARA FORMAR UM ARRAY!
        # Extrai o lensName para processamento externo via AWK
        $frame.lensName,
        # Restante dos campos do JSON, para serem processados pelo jq
        $_key,
        ($frame.aperture | sub("f/";"") // ""),
        $frame.shutterSpeed,
        # MODIFICADO: Formato da data para YYYY:MM:DD HH:MM:SS (padrão EXIF)
        ($frame.date | sub("T";" ") | sub("\\..*";"") | gsub("-";":")),
        ($frame.exposureValue | tostring),
        $frame.note,
        ($frame.location.latitude | tostring),
        ($frame.location.longitude | tostring),
        "S",                                        # GPSLatitudeRef fixo
        "W",                                        # GPSLongitudeRef fixo
        ($root.cameraName | gsub(" $"; "")),
        ($root.cameraName | gsub(" $"; "")),
        "",                                         # LensMake (manual)
        ($root.iso | tostring),
        "Jeremias Alves Queiroz",
        ($root.note // ""),
        ""                                          # Keywords (manual)
    ] | @csv) # @csv agora recebe um ARRAY, como esperado.
' | awk '
BEGIN {
    FS=","  # Define o separador de campo de entrada como vírgula (padrão do @csv do jq)
    OFS=";" # Define o separador de campo de saída como ponto e vírgula
}
NR==1 { # Processa a linha de cabeçalho
    # Remove as aspas do cabeçalho gerado pelo @csv e imprime
    gsub(/"/, "", $0)
    print $0
    next # Pula para a próxima linha
}
{
    # $1 é o lensName (o primeiro campo gerado pelo jq)
    lensName_val = $1
    gsub(/"/, "", lensName_val)             # Remove aspas
    # NOVO: Remove qualquer ponto e vírgula ou espaço/tab no final
    sub(/;[ \t]*$/, "", lensName_val)
    # NOVO: Remove quaisquer espaços/tabs remanescentes no final (para segurança)
    sub(/[ \t]*$/, "", lensName_val)


    # Extrai a distância focal usando uma regex AWK robusta.
    # Procura pelo último número (inteiro ou decimal) que pode ser
    # seguido por mm, M, Macro e espaços até o fim da string.
    focal_extracted = "" # Renomeado para maior clareza
    # O match principal já faz o trabalho.
    if (match(lensName_val, /([0-9]+(\.[0-9]+)?)(mm|M|Macro)?\s*$/, arr)) {
        focal_extracted = arr[1] # arr[1] contém apenas o número (grupo de captura 1)
    }

    # Reorganiza e imprime os campos.
    # O AWK reorganiza e injeta o valor de focal_extracted na 10a coluna
    # conforme a ordem do cabeçalho.
    # Os campos de $2 a $NF são os outros campos do jq após o lensName ($1).
    printf "%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s\n", \
        $2,                 # _key
        lensName_val,       # LensModel
        $3,                 # Aperture
        $4,                 # ShutterSpeed
        $5,                 # Date
        $6,                 # Exposure
        $7,                 # ImgDesc
        $8,                 # Latitude
        $9,                 # Longitude
        focal_extracted,    # Focal - 10th position
        $10,                # LatRef
        $11,                # LonRef
        $12,                # Make
        $13,                # Model
        $14,                # LensMake
        $15,                # ISO
        $16,                # Author
        $17,                # GlobalNote
        $18                 # Keywords
}
' > "$OUTPUT_CSV_FILE"

echo "CSV gerado com sucesso: '$OUTPUT_CSV_FILE'"
echo ""
echo "$ajuda"
