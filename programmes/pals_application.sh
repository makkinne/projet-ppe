#!/bin/bash
# 0) Créer une arbo "jolie"
mkdir -p corpus pals_input pals_output figures

# 1) Construire les corpus concaténés par langue
# IT : fichiers it-XX.txt
cat dumps-text/it-*.txt > corpus/it.txt

# FR : fichiers fr-XX.txt
cat dumps-text/fr-*.txt > corpus/fr.txt

# RU : fichiers numérotés (1.txt, 28.txt, 87.txt...)
find dumps-text -maxdepth 1 -type f -name "*.txt" -printf "%f\n" \
| grep -E '^[0-9]+\.txt$' \
| sort -n \
| sed 's|^|dumps-text/|' \
| xargs cat > corpus/ru.txt

# 2) Tokeniser au format PALS (1 token par ligne, lignes vides = séparation phrases)
for L in it fr ru; do
  cat "corpus/${L}.txt" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[.!?]/\n\n/g' \
  | sed "s/’/'/g" \
  | sed "s/[^[:alnum:][:space:]а-яёА-ЯЁàèéìòùáíóúâêîôûäëïöüç'-]/ /g" \
  | tr -s ' ' '\n' \
  | sed '/^[[:space:]]*$/d' \
  > "pals_input/${L}.tok"
done

# 3) Lancer PALS (cooccurrents) et écrire dans pals_output/
# IT : adapte si votre mot italien n'est pas "spirito" ou "spiriti"
python3 programmes/PALS/cooccurrents.py pals_input/it.tok \
  --target "^spirit[oi]$" --match-mode regex \
  2>/dev/null > pals_output/it_cooccurrents.tsv

python3 programmes/PALS/cooccurrents.py pals_input/fr.tok \
  --target "^esprit(s)?$" --match-mode regex \
  2>/dev/null > pals_output/fr_cooccurrents.tsv

# RU : adapte si votre mot russe n'est pas "дух"
python3 programmes/PALS/cooccurrents.py pals_input/ru.tok \
  --target "^(дух|духа|духу|духом|духе)$" --match-mode regex \
  2>/dev/null > pals_output/ru_cooccurrents.tsv

# 4) Comparaison inter-langues (spécificités) -> un seul TSV
python3 programmes/PALS/partition.py \
  -i pals_input/it.tok -i pals_input/fr.tok -i pals_input/ru.tok \
  -t TXM \
  2>/dev/null > pals_output/specificites_langues.tsv

# 5) Vérifs rapides
ls -lh corpus pals_input pals_output | sed -n '1,120p'
head -n 10 pals_output/it_cooccurrents.tsv