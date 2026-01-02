#!/bin/bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

if [ $# -ne 5 ]
then
    echo "ATTENTION! ce script va supprimer le contenu du dossier aspirations"
    echo "Le script attend strictement cinq arguments: le chemin vers le fichier d'URL et le chemin vers le dossier de sortie"
    echo "et le nom du fichier de résultat, le mot clé et la langue"
    echo "pour la langue écrire 'it|fr|ru'"
    exit
fi

FICHIER_URL=$1 # fichier contenant les URLs à traiter
DOSSIER_TABLEAUX=$2 # dossier de sortie pour les fichiers générés
FICHIER_RESULTAT=$3 # nom de fichier résultat
MOT_CLE=$4 # regex
LANGUE=$5 # la langue, pour pouvoir nommer les fichiers

# Créer les dossiers s'ils n'existent pas
mkdir -p "$DOSSIER_TABLEAUX/../aspirations"
mkdir -p "$DOSSIER_TABLEAUX/../dumps-text"
mkdir -p "$DOSSIER_TABLEAUX/../contextes"

echo "<html>
<head>
    <meta charset=\"UTF-8\">
    <title>Tableau des résultats</title>
    <style>table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid black; padding: 8px; } th { background-color: #f2f2f2; }</style>
</head>
<body>
<h1>Résultats pour le mot : $MOT_CLE</h1>
<table>
    <tr>
        <th>N°</th>
        <th>URL</th>
        <th>Code HTTP</th>
        <th>Encodage détecté</th>
        <th>Page Aspirée (HTML)</th>
        <th>Dump Textuel (TXT)</th>
        <th>Contexte</th>
    </tr>" > "$FICHIER_RESULTAT"

lineno=1
while read -r URL; do
	URL=$(echo "$URL" | tr -d '\r')

    if [ -n "$URL" ]; then
        echo "Traitement de la ligne $lineno: $URL"

        f_aspirations="$DOSSIER_TABLEAUX/../aspirations/${LANGUE}-${lineno}.html"
        f_dump="$DOSSIER_TABLEAUX/../dumps-text/${LANGUE}-${lineno}.txt"
        f_contexte="$DOSSIER_TABLEAUX/../contextes/${LANGUE}-${lineno}.txt"

        # Récupérer la page
        code=$(curl -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" -L -s -o "$f_aspirations" -w "%{http_code}" "$URL")
        encoding="N/A"
        nb_contexte=0

        # Si pas d'erreur lors de la récupération
        # Alors
        if [ "$code" == "200" ]; then
            encoding=$(file -b --mime-encoding "$f_aspirations")
            
            if [ "$encoding" == "utf-8" ]; then
                # En extraire le texte
                lynx -stdin -dump -nolist -display_charset=UTF-8 < "$f_aspirations" > "$f_dump"
                # En extraire des contextes
                grep -E -i -C 2 "$MOT_CLE" "$f_dump" > "$f_contexte" #egrep est obsolette usage de grep -E à la place
            # Sinon
            else
                #  on essaie de détecter l'encodage
                if [ -n "$encoding" ] && [ "$encoding" != "binary" ]; then
                    # l’encodage est reconnu
                    # Conversion en UTF-8 et extraction du texte
                    iconv -f "$encoding" -t "UTF-8//IGNORE" -c "$f_aspirations" | lynx -stdin -dump -nolist -display_charset=UTF-8 > "$f_dump"
                    # En extraire des contextes
                    grep -E -i -C 2 "$MOT_CLE" "$f_dump" > "$f_contexte" #egrep est obsolette usage de grep -E à la place
                else
                    # Sinon on ne fait rien
                    echo "" > "$f_dump"
                    echo "" > "$f_contexte"
                fi
            fi

            # Calcul du nombre de lignes de contexte si le fichier existe et n'est pas vide
            if [ -s "$f_contexte" ]; then
                nb_contexte=$(grep -c . "$f_contexte")
            else
                nb_contexte=0
            fi

        else
            echo "" > "$f_dump"
            echo "Erreur HTTP $code" > "$f_contexte"
        fi

        # output pour le tableau, avec une ligne par URL
        echo "    <tr>
            <td>$lineno</td>
            <td><a href=\"$URL\" target=\"_blank\">$URL</a></td>
            <td>$code</td>
            <td>$encoding</td>
            <td><a href=\"../aspirations/${LANGUE}-${lineno}.html\">html</a></td>
            <td><a href=\"../dumps-text/${LANGUE}-${lineno}.txt\">txt</a></td>
            <td><a href=\"../contextes/${LANGUE}-${lineno}.txt\">contexte ($nb_contexte lignes)</a></td>
        </tr>" >> "$FICHIER_RESULTAT"

        ((lineno++))

    fi
done < "$FICHIER_URL"

echo "</table></body></html>" >> "$FICHIER_RESULTAT"
echo "fichier texte généré: $FICHIER_RESULTAT"
