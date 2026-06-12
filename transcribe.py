import os
import whisper

# ─────────────────────────────────────────────
#  CONSTANTES — edite aqui conforme necessário
# ─────────────────────────────────────────────
INPUT_FOLDER  = "input"       # pasta com os vídeos (relativa à raiz do projeto)
OUTPUT_FOLDER = "output"      # pasta de saída     (relativa à raiz do projeto)
MODEL         = "small"       # tiny | base | small | medium | large
LANGUAGE      = "Portuguese"  # idioma do áudio

# Extensões de vídeo aceitas
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".avi", ".mov", ".webm", ".flv", ".m4v"}

# ─────────────────────────────────────────────


def get_video_files(folder: str) -> list[str]:
    """Retorna todos os arquivos de vídeo encontrados na pasta (recursivo)."""
    videos = []
    for root, _, files in os.walk(folder):
        for file in files:
            if os.path.splitext(file)[1].lower() in VIDEO_EXTENSIONS:
                videos.append(os.path.join(root, file))
    return videos


def transcribe_video(model, video_path: str, output_dir: str) -> None:
    """Transcreve um vídeo e salva os arquivos na pasta de saída correspondente."""
    video_name = os.path.splitext(os.path.basename(video_path))[0]
    video_output_dir = os.path.join(output_dir, video_name)
    os.makedirs(video_output_dir, exist_ok=True)

    print(f"\n🎬 Transcrevendo: {video_path}")
    print(f"   📁 Saída: {video_output_dir}")

    result = model.transcribe(video_path, language=LANGUAGE)

    # ── Salva .txt (texto puro) ──────────────────────────────────────────
    txt_path = os.path.join(video_output_dir, f"{video_name}.txt")
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(result["text"].strip())
    print(f"   ✅ {video_name}.txt")

    # ── Salva .srt (legenda com timestamps) ─────────────────────────────
    srt_path = os.path.join(video_output_dir, f"{video_name}.srt")
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, segment in enumerate(result["segments"], start=1):
            start = format_timestamp(segment["start"])
            end   = format_timestamp(segment["end"])
            text  = segment["text"].strip()
            f.write(f"{i}\n{start} --> {end}\n{text}\n\n")
    print(f"   ✅ {video_name}.srt")

    # ── Salva .json (dados completos) ────────────────────────────────────
    import json
    json_path = os.path.join(video_output_dir, f"{video_name}.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"   ✅ {video_name}.json")


def format_timestamp(seconds: float) -> str:
    """Converte segundos para o formato SRT: HH:MM:SS,mmm"""
    hours   = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs    = int(seconds % 60)
    millis  = int(round((seconds - int(seconds)) * 1000))
    return f"{hours:02}:{minutes:02}:{secs:02},{millis:03}"


def main() -> None:
    # Resolve caminhos relativos à raiz do projeto (onde o script está)
    base_dir    = os.path.dirname(os.path.abspath(__file__))
    input_path  = os.path.join(base_dir, INPUT_FOLDER)
    output_path = os.path.join(base_dir, OUTPUT_FOLDER)

    if not os.path.isdir(input_path):
        print(f"❌ Pasta de entrada não encontrada: {input_path}")
        return

    videos = get_video_files(input_path)

    if not videos:
        print(f"⚠️  Nenhum vídeo encontrado em: {input_path}")
        return

    print(f"📂 Pasta de entrada : {input_path}")
    print(f"📂 Pasta de saída   : {output_path}")
    print(f"🤖 Modelo Whisper   : {MODEL}")
    print(f"🌐 Idioma           : {LANGUAGE}")
    print(f"🎬 Vídeos encontrados: {len(videos)}")

    print(f"\n⏳ Carregando modelo '{MODEL}'...")
    model = whisper.load_model(MODEL)
    print("✅ Modelo carregado!\n")

    for video_path in videos:
        transcribe_video(model, video_path, output_path)

    print(f"\n🎉 Concluído! Transcrições salvas em: {output_path}")


if __name__ == "__main__":
    main()
