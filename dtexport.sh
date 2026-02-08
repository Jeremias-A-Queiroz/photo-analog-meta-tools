#!/bin/bash
# dtexport.sh
#
#
# Script para exportar fotografias do Darktable em resolucoes pre definidas
#
# Versao 0.1: Define o escopo inicial do script
#
# Jeremias A Queiroz, Fevereiro de 2026

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
		[Yy]*)
			return 0 # Segue para a criação de pastas e execução
			;;
		[Nn]*)
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
				read -p "Res LD [$RES_LD]: " tmp
				RES_LD=${tmp:-$RES_LD}
				read -p "Res SD [$RES_SD]: " tmp
				RES_SD=${tmp:-$RES_SD}
				read -p "Res HD [$RES_HD]: " tmp
				RES_HD=${tmp:-$RES_HD}
			fi
			;;
		[Qq]*)
			echo "Abortado."
			exit 0
			;;
		*) echo "Responda y, n ou q." ;;
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
for i in *.tif; do
	darktable-cli "$i" "$DEST_LD_PATH"/"${i%.tif}.webp" --verbose \
		--width 1050 --height 1050 --hq 1 --core \
		--conf plugins/imageio/format/webp/quality=95 \
		--conf plugins/imageio/format/webp/comp_level=6 \
		--conf plugins/imageio/format/webp/lossless=0 \
		--conf plugins/imageio/format/webp/icc_link=1 \
		--conf plugins/imageio/format/webp/profile=srgb
done && for i in *.tif; do
	darktable-cli "$i" $DEST_SD_PATH --verbose --width 2560 --height 2560 \
		--hq 1 --core --conf plugins/imageio/format/jpeg/quality=95 \
		--conf plugins/imageio/format/jpeg/profile=srgb \
		--conf plugins/imageio/format/jpeg/icc_link=1
done && for i in *.tif; do
	darktable-cli "$i" $DEST_HD_PATH --verbose --width 4606 --height 4606 --hq 1 \
		--core --conf plugins/imageio/format/jpeg/quality=95 \
		--conf plugins/imageio/format/jpeg/profile=srgb \
		--conf plugins/imageio/format/jpeg/icc_link=1
done &&
	echo "Concluído!"
