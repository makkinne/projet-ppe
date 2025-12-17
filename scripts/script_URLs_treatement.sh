#!/bin/bash
if [ $# -ne 3 ]
then
    echo "ATTENTION! ce script va supprimer le contenu du dossier aspirations"
    echo "Le script attend strictement trois arguments: le chemin vers le fichier d'URL et le chemin vers le dossier de sortie"
    exit
fi

FICHIER_URL=$1 # fichier contenant les URLs à traiter
DOSSIER_SORTIE=$2 # dossier de sortie pour les fichiers générés
FICHIER_RESULTAT=$3 # nom de fichier résultat

 # Créer le dossier aspirations s'il n'existe pas
mkdir -p "$DOSSIER_SORTIE/../aspirations"
# supprime le contenu de aspirations s'il y en a
rm -f "$DOSSIER_SORTIE/../aspirations/"*

num=1
while read -r line; do
    if [ -n "$line" ]; then
        echo "Traitement de l'URL: $line"
        code=$(curl -s -o /dev/null -w "%{http_code}" "$line")
        content=$(curl -s "$line")
        encoding=$(echo $content | grep -ioP 'charset=["'\''"]?\K[^"'\'' >]+' | head -n 1)
        if [ -z "$encoding" ]; then
            encoding="non présent"
        fi
        # nb_mots=$(lynx -dump -nolist "$line" | wc -w)
        html_file="$DOSSIER_SORTIE/HTMLs/page_$num.html"
        lynx -source "$line" > "$html_file"
        nb_mots=$(cat "$html_file" | wc -w)
        # output pour le tableau, avec une ligne par URL
        echo -n "$num - " >> "$FICHIER_RESULTAT"
        echo -n "$line - " >> "$FICHIER_RESULTAT"
        echo -n "$code - " >> "$FICHIER_RESULTAT"
        echo -n "$encoding - " >> "$FICHIER_RESULTAT"
        echo "$nb_mots" >> "$FICHIER_RESULTAT"
        ((num++))

    fi
done < "$FICHIER_URL"
>> "$FICHIER_RESULTAT"

echo "fichier texte généré: $FICHIER_RESULTAT"
