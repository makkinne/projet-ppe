import os
import pandas as pd # type: ignore
import matplotlib.pyplot as plt
from wordcloud import WordCloud # type: ignore , ignore sert à bypasser les erreurs de type dans les imports externes

DEFAULT_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_PATH = DEFAULT_FONT if os.path.exists(DEFAULT_FONT) else None

def load_freqs_from_pals_tsv(tsv_path: str, drop_words=None, topn=200) -> dict:
    """
    Lit un TSV PALS (cooccurrents) et construit un dict {mot: poids}.
    Hypothèse robuste : mot = 1ère colonne, poids = 1ère colonne numérique trouvée.
    """
    df = pd.read_csv(tsv_path, sep="\t", header=None, dtype=str, engine="python")
    if df.shape[1] < 2:
        raise ValueError(f"TSV trop court/étrange: {tsv_path}")

    words = df.iloc[:, 0].astype(str)

    # trouver une colonne numérique exploitable
    num_series = None
    for c in range(1, df.shape[1]):
        s = pd.to_numeric(df.iloc[:, c].str.replace(",", ".", regex=False), errors="coerce")
        if s.notna().sum() > max(10, int(0.2 * len(s))):
            num_series = s.fillna(0.0)
            break

    drop_words = set(drop_words or [])
    freqs = {}

    if num_series is None:
        # fallback (poids = 1)
        for w in words:
            w = w.strip()
            if w and w not in drop_words and len(w) > 1:
                freqs[w] = freqs.get(w, 0) + 1
    else:
        for w, v in zip(words, num_series):
            w = str(w).strip()
            if not w or w in drop_words or len(w) <= 1:
                continue
            freqs[w] = float(v)

    freqs = dict(sorted(freqs.items(), key=lambda x: x[1], reverse=True)[:topn])
    return freqs

def make_wc(freqs: dict, out_png: str, title: str):
    wc = WordCloud(
        width=1400,
        height=900,
        background_color="white",
        font_path=FONT_PATH,
        collocations=False,
        prefer_horizontal=0.9,
        max_words=200
    ).generate_from_frequencies(freqs)

    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    plt.figure(figsize=(12, 8))
    plt.imshow(wc, interpolation="bilinear")
    plt.axis("off")
    plt.title(title)
    plt.tight_layout()
    plt.savefig(out_png, dpi=200)
    plt.close()

def main():
    jobs = [
        ("pals_output/it_cooccurrents.tsv", "figures/wordclouds/wc_it.png",
         "Italiano — cooccorrenze di “spirito”", {"spirito", "spiriti"}),
        ("pals_output/fr_cooccurrents.tsv", "figures/wordclouds/wc_fr.png",
         "Français — cooccurrences de “esprit”", {"esprit", "esprits"}),
    ]

    for tsv, out_png, title, drop in jobs:
        if not os.path.exists(tsv):
            print(f"[WARN] introuvable: {tsv} (skip)")
            continue
        freqs = load_freqs_from_pals_tsv(tsv, drop_words=drop, topn=200)
        make_wc(freqs, out_png, title)
        print(f"[OK] {out_png}")

if __name__ == "__main__":
    main()