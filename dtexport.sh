#!/bin/bash
# dtexport.sh
#
#
# Script para exportar fotografias do Darktable em resolucoes pre definidas
#
# Versao 0.1: Define o escopo inicial do script
#
# Jeremias A Queiroz, Fevereiro de 2026


# --- inicio codigo Novo

#!/bin/bash
# dtexport.sh

# --- Variáveis iniciais --- 
CURRENT_DIR_NAME=$(basename "$PWD")
PICTURES_PATH=$(xdg-user-dir PICTURES)

# Resoluções padrão (conforme discutido no gemini.txt)
RES_LD="1050"
RES_SD="2560"
RES_HD="4606" # Original

# Definição dos caminhos baseada na sua lógica original
DEST_SD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"
DEST_LD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"-LD
DEST_HD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"-HD

# --- Funções ---

# Função de Validação (O "Checkpoint" que você pediu)
validar_parametros() {
    while true; do
        clear
        echo "=========================================================="
        echo "           PLANO DE EXPORTAÇÃO - DARKTABLE"
        echo "=========================================================="
        echo "DIRETÓRIOS DE DESTINO:"
        echo "  LD (Low): $DEST_LD_PATH"
        echo "  SD (Std): $DEST_SD_PATH"
        echo "  HD (High): $DEST_HD_PATH"
        echo "----------------------------------------------------------"
        echo "RESOLUÇÕES (Longo Eixo):"
        echo "  LD: ${RES_LD}px | SD: ${RES_SD}px | HD: ${RES_HD}px (0=orig)"
        echo "=========================================================="
        echo ""
        read -p "Os parâmetros acima estão corretos? (y/n/q): " opt

        case $opt in
            [Yy]* ) 
                return 0 # Segue para a criação de pastas e execução
                ;;
            [Nn]* )
                echo -e "\nO que você deseja alterar?"
                echo "1) Caminhos de Destino (alterar o nome base do projeto)"
                echo "2) Resoluções"
                read -p "Escolha (1-2): " edit_opt
                
                if [ "$edit_opt" = "1" ]; then
                    read -p "Novo nome base para o projeto [$CURRENT_DIR_NAME]: " novo_nome
                    if [[ -n "$novo_nome" ]]; then
                        CURRENT_DIR_NAME="$novo_nome"
                        # Recalcula os caminhos conforme sua lógica original
                        DEST_SD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"
                        DEST_LD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"-LD
                        DEST_HD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"-HD
                    fi
                elif [ "$edit_opt" = "2" ]; then
                    read -p "Res LD [$RES_LD]: " tmp; RES_LD=${tmp:-$RES_LD}
                    read -p "Res SD [$RES_SD]: " tmp; RES_SD=${tmp:-$RES_SD}
                    read -p "Res HD [$RES_HD]: " tmp; RES_HD=${tmp:-$RES_HD}
                fi
                ;;
            [Qq]* )
                echo "Abortado."
                exit 0
                ;;
            * ) echo "Responda y, n ou q.";;
        esac
    done
}

# --- Fluxo Principal ---

# 1. Primeiro validamos tudo (Separação entre Validação e Execução)
validar_parametros

# 2. Agora executamos a criação (Aprovado pelo usuário)
echo -e "\n>>> Criando estruturas de diretório..."
for dir in "$DEST_LD_PATH" "$DEST_SD_PATH" "$DEST_HD_PATH"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" && echo "✅ Criado: $dir"
    else
        echo "ℹ️ Já existe: $dir"
    fi
done

# 3. Aqui entrariam as chamadas do darktable-cli usando as variáveis validadas
echo -e "\n>>> Iniciando exportação via darktable-cli..."
# Exemplo: darktable-cli . "$DEST_LD_PATH" --width "$RES_LD" ...

echo "Concluído!"

# --- fim codigo novo




# --- Variaveis iniciais --- 
# Usa a variavel de ambiente $PWD, que automaticamente contém o caminho
# completo do diretório atual. O comandobasename extrai a última
# componente do caminho.
CURRENT_DIR_NAME=$(basename "$PWD")

# Utiliza o comando xdg-user-dir para encontrar a path para a raiz do
# diretorio de imagens independentemente do idioma
PICTURES_PATH=$(xdg-user-dir PICTURES)

# Concatena as duas variaveis anteriores para gerar asvariaveis de destino
DEST_SD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"
DEST_LD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"-LD
DEST_HD_PATH="$PICTURES_PATH"/"$CURRENT_DIR_NAME"-HD



# --- Funcoes ---

# Funcao para confirmar a criacao do diretorio
ask_confirmation() {
    local prompt_message="$1"
    local response

    while true; do
        read -p "$prompt_message (y/N)? " -n 1 -r response
        echo # Adiciona nova linha após a resposta
        local response_lc=$(echo "$response" | tr '[:upper:]' '[:lower:]')

        if [[ -z "$response_lc" || "$response_lc" == "n" ]]; then # N é o padrão
            return 1 # Não
        elif [[ "$response_lc" == "y" ]]; then
            return 0 # Sim
        else
            echo "Resposta inválida. Por favor, digite 'y' para sim ou 'n' para não."
        fi
    done
}

# Funcao para criacao do diretorio que recebera as imagens
function make_dir () {
    if [[ -d "$1" ]]; then
	return 0
    else
	if ask_confirmation "Deseja criar o diretório '$1'?"; then
            echo "Prosseguindo com a criação do diretório padrão..."
            mkdir -p "$1"
            if [[ $? -eq 0 ]]; then
		echo "✅ Diretório '$1' criado com sucesso."
		return 0 # Termina a funcao com sucesso
            else
		echo "❌ Falha ao criar o diretório padrão '$1'."
		exit 1 # Termina a função e o script com erro
            fi
	else
	    read -p "Deseja entrar com um nome alternativo para o subdiretório? (Pressione Enter sem digitar nada para sair): " -r ALTERNATIVE_SUBDIR_NAME
	    echo

	    if [[ -z "$ALTERNATIVE_SUBDIR_NAME" ]]; then
		echo "Nenhum nome alternativo fornecido. Script finalizado."
		exit 0
	    else
		# Recria a variavel com a PATH de destino
		ALTERNATIVE_FULL_PATH="$PICTURES_PATH"/"$ALTERNATIVE_SUBDIR_NAME"

		echo "Tentando criar o diretório alternativo: '$ALTERNATIVE_FULL_PATH'"
		mkdir -p "$ALTERNATIVE_FULL_PATH"
		if [[ $? -eq 0 ]]; then
                    echo "✅ Diretório '$ALTERNATIVE_FULL_PATH' criado com sucesso."
                    echo "Script finalizado com sucesso."
                    return 0 # Termina a função com sucesso
		else
                    echo "❌ Falha ao criar o diretório alternativo '$ALTERNATIVE_FULL_PATH'."
                    exit 1 # Termina a funcao e o script com erro
		fi
    
	    fi
	fi
    fi
}

