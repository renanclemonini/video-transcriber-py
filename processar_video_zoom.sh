#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ZOOM_DIR="$HOME/Vídeos/zoom"
ZOOM_PROCESSED_DIR="$HOME/Vídeos/zoom_processados"
INPUT_DIR="$SCRIPT_DIR/input"
OUTPUT_DIR="$SCRIPT_DIR/output"
TRANSCRIBED_DIR="$SCRIPT_DIR/transcribed_videos"
VENV_DIR="$SCRIPT_DIR/.venv"
PROMPT_FILE="$SCRIPT_DIR/prompt_relatorio.txt"
TESTE=1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

procurar_audio() {
    local pasta="$1"
    find "$pasta" -maxdepth 1 -name "audio*.m4a" -print -quit 2>/dev/null || true
}

procurar_video() {
    local pasta="$1"
    find "$pasta" -maxdepth 1 -name "*.mp4" -print -quit 2>/dev/null || true
}

gerar_nomes() {
    sufixo=""
    contador=1
    while true; do
        nome_src="${HOJE_DD_MM_YYYY}_aovivo${sufixo}.${ext_src}"
        nome_video="${HOJE_DD_MM_YYYY}_aovivo${sufixo}.mp4"
        nome_sem_ext="${HOJE_DD_MM_YYYY}_aovivo${sufixo}"
        pasta_destino="$TRANSCRIBED_DIR/${HOJE_DD_MM_YYYY}${sufixo}"

        if [ ! -d "$pasta_destino" ]; then
            break
        fi
        sufixo=$(printf "_%02d" "$contador")
        contador=$((contador + 1))
    done
}

processar_transcricao() {
    local fonte="$1"
    local video="$2"
    local zoom_folder="$3"
    local folder_name
    folder_name=$(basename "$zoom_folder")

    log "  → Fonte para transcrição: $(basename "$fonte")"

    if [[ "$fonte" == *.m4a ]]; then
        ext_src="m4a"
    else
        ext_src="mp4"
    fi

    gerar_nomes

    log "  → Pasta destino: $pasta_destino"

    mkdir -p "$pasta_destino"

    mv "$video" "$pasta_destino/$nome_video"
    log "  → Vídeo movido para $pasta_destino/"

    cp "$fonte" "$INPUT_DIR/$nome_src"
    log "  → Fonte copiada para input/"

    cd "$SCRIPT_DIR"
    source "$VENV_DIR/bin/activate"
    log "  → Iniciando transcrição com faster-whisper..."
    python faster_transcribe.py
    deactivate
    log "  → Transcrição concluída"

    if [ -f "$TRANSCRIBED_DIR/$nome_src" ]; then
        rm -f "$TRANSCRIBED_DIR/$nome_src"
        log "  → Arquivo temporário removido"
    fi

    if [ -d "$OUTPUT_DIR/$nome_sem_ext" ]; then
        if [ -f "$OUTPUT_DIR/$nome_sem_ext/$nome_sem_ext.srt" ]; then
            mv "$OUTPUT_DIR/$nome_sem_ext/$nome_sem_ext.srt" "$pasta_destino/${HOJE_DDMMYYYY}_transcricao.txt"
            log "  → Transcrição salva em $pasta_destino/"
        fi
        rm -rf "$OUTPUT_DIR/$nome_sem_ext"
        log "  → Arquivos temporários da transcrição descartados"
    else
        log "  ⚠ Pasta de transcrição não encontrada em output/$nome_sem_ext"
    fi

    if [ "$SKIP_REPORT" = false ]; then
        log "  → Gerando relatório via opencode..."
        local arquivo_transcricao="$pasta_destino/${HOJE_DDMMYYYY}_transcricao.txt"
        if [ -f "$arquivo_transcricao" ]; then
            local prompt_content
            prompt_content="$(cat "$PROMPT_FILE")"
            opencode run --model opencode/mimo-v2.5-free --auto \
            "Leia o arquivo $prompt_content para fazer o relatório da transcrição \
            $arquivo_transcricao" > "$pasta_destino/${HOJE_DD_MM_YYYY}_relatorio.docx"
            log "  → Relatório salvo em $pasta_destino/"
        else
            log "  ⚠ Arquivo de transcrição não encontrado, pulando relatório"
        fi
    fi

    if [ "$TESTE" = 1 ]; then
        mv "$zoom_folder" "$ZOOM_PROCESSED_DIR/"
        log "  → Pasta original movida para $ZOOM_PROCESSED_DIR/"
    else
        rm -rf "$zoom_folder"
        log "  → Pasta original removida"
    fi

    log "✓ Finalizado: $folder_name"
    xdg-open "$TRANSCRIBED_DIR"
    echo ""
}

# ─── Main ──────────────────────────────────────────────────

for dir in "$ZOOM_DIR" "$INPUT_DIR" "$VENV_DIR"; do
    if [ ! -d "$dir" ]; then
        log "ERRO: Pasta não encontrada: $dir"
        exit 1
    fi
done

SKIP_REPORT=false
if [ ! -f "$PROMPT_FILE" ]; then
    log "AVISO: Arquivo de prompt não encontrado em $PROMPT_FILE"
    log "       O relatório via opencode será pulado."
    SKIP_REPORT=true
fi

mkdir -p "$ZOOM_PROCESSED_DIR"

HOJE_YYYY_MM_DD=$(date +%Y-%m-%d)
HOJE_DD_MM_YYYY=$(date +%d.%m.%Y)
HOJE_DDMMYYYY=$(date +%d%m%Y)

log "Buscando gravações em $ZOOM_DIR"

shopt -s nullglob
zoom_folders=("$ZOOM_DIR"/*/)
shopt -u nullglob

if [ ${#zoom_folders[@]} -eq 0 ]; then
    log "Nenhuma gravação encontrada em $ZOOM_DIR"
    exit 0
fi

log "Encontradas ${#zoom_folders[@]} gravação(ões)"

for zoom_folder in "${zoom_folders[@]}"; do
    folder_name=$(basename "$zoom_folder")
    log "▶ Processando: $folder_name"

    audio=$(procurar_audio "$zoom_folder")
    video=$(procurar_video "$zoom_folder")

    if [ -z "$video" ]; then
        log "  ⚠ Nenhum arquivo .mp4 encontrado, pulando"
        continue
    fi

    if [ -n "$audio" ] && [ -n "$video" ]; then
        processar_transcricao "$audio" "$video" "$zoom_folder"
    elif [ -z "$audio" ] && [ -n "$video" ]; then
        processar_transcricao "$video" "$video" "$zoom_folder"
    else
        log "  ⚠ Nenhum arquivo de áudio ou vídeo encontrado, pulando"
        continue
    fi
done

log "🎉 Todas as gravações foram processadas!"
