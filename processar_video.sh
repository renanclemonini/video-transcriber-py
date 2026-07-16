#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════
#  CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════
OBS_DIR="/home/renanclemonini/Vídeos/obs"
INPUT_DIR="$(dirname "$0")/input"
OUTPUT_DIR="$(dirname "$0")/output"
TRANSCRIBED_DIR="$(dirname "$0")/transcribed_videos"
VENV_DIR="$(dirname "$0")/.venv"
PROMPT_FILE="$(dirname "$0")/prompt_relatorio.txt"
# ═══════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ─── Verificações iniciais ─────────────────────────────────
log "$OBS_DIR: Pasta de vídeos do OBS"
for dir in "$OBS_DIR" "$INPUT_DIR" "$VENV_DIR"; do
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

# ─── Lista vídeos .mp4 na pasta do OBS ────────────────────
shopt -s nullglob
videos=("$OBS_DIR"/*.mp4)
shopt -u nullglob

if [ ${#videos[@]} -eq 0 ]; then
    log "Nenhum vídeo encontrado em $OBS_DIR"
    # exit 0
fi

# ─── Processa um vídeo por vez ────────────────────────────
for video in "${videos[@]}"; do
    basename_video=$(basename "$video")
    log "▶ Processando: $basename_video"

    # ─── Gera prefixo dd.mm.yyyy com incremento ──────────
    prefixo_data=$(date +%d.%m.%Y)
    sufixo=""
    contador=1
    while true; do
        nome_final="${prefixo_data}_aovivo${sufixo}.mp4"
        nome_sem_ext="${prefixo_data}_aovivo${sufixo}"
        pasta_destino="$TRANSCRIBED_DIR/${prefixo_data}${sufixo}"

        if [ ! -d "$pasta_destino" ]; then
            break
        fi
        sufixo=$(printf "_%02d" "$contador")
        contador=$((contador + 1))
    done

    log "  → Renomeado para: $nome_final"

    # ─── Prefixo sem pontos para nome do arquivo de transcrição ─
    prefixo_data_arquivo=$(date +%d%m%Y)

    # ─── Move para input/ ──────────────────────────────
    mv "$video" "$INPUT_DIR/$nome_final"
    log "  → Movido para input/"

    # ─── Ativa venv e executa transcrição ──────────────
    cd "$(dirname "$0")"
    source "$VENV_DIR/bin/activate"
    log "  → Iniciando transcrição com faster-whisper..."
    python faster_transcribe.py
    deactivate
    log "  → Transcrição concluída"

    # ─── Cria pasta de destino ─────────────────────────
    mkdir -p "$pasta_destino"

    # ─── Move o vídeo de transcribed_videos/ para a pasta destino ───
    if [ -f "$TRANSCRIBED_DIR/$nome_final" ]; then
        mv "$TRANSCRIBED_DIR/$nome_final" "$pasta_destino/"
        log "  → Vídeo movido para $pasta_destino/"
    fi

    # ─── Move .srt renomeado como transcricao.txt ──────
    if [ -d "$OUTPUT_DIR/$nome_sem_ext" ]; then
        if [ -f "$OUTPUT_DIR/$nome_sem_ext/$nome_sem_ext.srt" ]; then
            mv "$OUTPUT_DIR/$nome_sem_ext/$nome_sem_ext.srt" "$pasta_destino/${prefixo_data_arquivo}_transcricao.txt"
            log "  → Transcrição (.srt → .txt) salva em $pasta_destino/"
        fi
        rm -rf "$OUTPUT_DIR/$nome_sem_ext"
        log "  → Arquivos .txt e .json descartados"
    else
        log "  ⚠ Pasta de transcrição não encontrada em output/$nome_sem_ext"
    fi

    # ─── Gera relatório via opencode ───────────────────
    if [ "$SKIP_REPORT" = false ]; then
        log "  → Gerando relatório via opencode..."

        arquivo_transcricao="$pasta_destino/${prefixo_data_arquivo}_transcricao.txt"
        if [ -f "$arquivo_transcricao" ]; then
            prompt_content="$(cat "$PROMPT_FILE")"
            log "  → Executando: opencode run \"...\""
            opencode run --model opencode/mimo-v2.5-free --auto \
            "Leia o arquivo $prompt_content para fazer o relatório da transcrição \
            $arquivo_transcricao" > "$pasta_destino/${prefixo_data}_relatorio.docx"
            log "  → Relatório salvo em $pasta_destino/${prefixo_data}_relatorio.docx"
        else
            log "  ⚠ Arquivo .txt de transcrição não encontrado, pulando relatório"
        fi
    fi

    log "✓ Finalizado: $nome_final"
    xdg-open /home/renanclemonini/projects/video-transcriber-py/transcribed_videos
    echo ""
done

log "🎉 Todos os vídeos foram processados!"
