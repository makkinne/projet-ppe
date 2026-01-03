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
mkdir -p "$DOSSIER_TABLEAUX/../concordances"
mkdir -p "$DOSSIER_TABLEAUX/../bigrams"

echo "Nettoyage des anciens fichiers pour la langue: $LANGUE ..."
rm -f "$DOSSIER_TABLEAUX/../aspirations/${LANGUE}-"*
rm -f "$DOSSIER_TABLEAUX/../dumps-text/${LANGUE}-"*
rm -f "$DOSSIER_TABLEAUX/../contextes/${LANGUE}-"*
rm -f "$DOSSIER_TABLEAUX/../concordances/${LANGUE}-"*
rm -f "$DOSSIER_TABLEAUX/../bigrams/${LANGUE}-"*

echo "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    <title>Tableau des résultats : $MOT_CLE</title>
    <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@1.0.4/css/bulma.min.css\">
    <style>
        :root {
            --primary-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        body {
            background-color: white;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .hero {
            background: var(--primary-gradient);
            color: white;
        }
        .section {
            flex: 1;
        }
    </style>
</head>
<body>
    <section class=\"hero is-small\">
        <div class=\"hero-body\">
            <div class=\"container\">
                <div class=\"columns is-vcentered\">
                    <div class=\"column\">
                        <h1 class=\"title has-text-white\">Résultats pour : '$MOT_CLE'</h1>
                    </div>
                    <div class=\"column is-narrow\">
                        <a href=\"../index.html\" class=\"button is-light is-outlined\">
                            Retour à l'accueil
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class=\"section\">
        <div class=\"container\">
            <div class=\"box\">
                <div class=\"table-container\">
                    <table class=\"table is-bordered is-striped is-hoverable is-fullwidth\">
                        <thead>
                            <tr>
                                <th>N°</th>
                                <th>URL</th>
                                <th>Code HTTP</th>
                                <th>Encodage</th>
                                <th>Occurrences</th>
                                <th>Concordancier</th>
                                <th>Bigrammes</th>
                                <th>HTML</th>
                                <th>TXT</th>
                                <th>Contexte</th>
                            </tr>
                        </thead>
                        <tbody>" > "$FICHIER_RESULTAT"

lineno=1
while read -r URL; do
	URL=$(echo "$URL" | tr -d '\r')

    if [ -n "$URL" ]; then
        echo "Traitement de la ligne $lineno: $URL"

        f_aspirations="$DOSSIER_TABLEAUX/../aspirations/${LANGUE}-${lineno}.html"
        f_dump="$DOSSIER_TABLEAUX/../dumps-text/${LANGUE}-${lineno}.txt"
        f_contexte="$DOSSIER_TABLEAUX/../contextes/${LANGUE}-${lineno}.txt"
        f_concordance="$DOSSIER_TABLEAUX/../concordances/${LANGUE}-${lineno}.html"
        f_2gram="$DOSSIER_TABLEAUX/../bigrams/${LANGUE}-${lineno}.html"

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

            # Compte des occurrences
            compte=$(grep -o -i "$MOT_CLE" "$f_dump" | wc -l)

            # Construction du concordancier
            echo "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <title>Concordancier : $MOT_CLE</title>
    <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@1.0.4/css/bulma.min.css\">
</head>
<body>
    <section class=\"section\">
        <div class=\"container\">
            <h1 class=\"title\">Concordancier pour le mot : $MOT_CLE</h1>
            <a href=\"../$FICHIER_RESULTAT\" class=\"button is-small is-link is-outlined mb-4\">Retour au tableau</a>
            <table class=\"table is-striped is-hoverable is-fullwidth\">
                <thead>
                    <tr>
                        <th class=\"has-text-right\" style=\"width:45%\">Contexte gauche</th>
                        <th class=\"has-text-centered\">Mot</th>
                        <th class=\"has-text-left\" style=\"width:45%\">Contexte droit</th>
                    </tr>
                </thead>
                <tbody>" > "$f_concordance"

            grep -E -o -i ".{0,50}$MOT_CLE.{0,50}" "$f_dump" | sed -E "s/($MOT_CLE)/<\/td><td class=\"has-text-centered\"><strong>\1<\/strong><\/td><td class=\"has-text-left\">/I" | sed -E "s/^/<tr><td class=\"has-text-right\">/" | sed -E "s/$/<\/td><\/tr>/" >> "$f_concordance"

            echo "</tbody>
            </table>
        </div>
    </section>
</body>
</html>" >> "$f_concordance"


 # Construction des 2-grammes
            echo "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <title>Bigrammes : $MOT_CLE</title>
    <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@1.0.4/css/bulma.min.css\">
</head>
<body>
    <section class=\"section\">
        <div class=\"container\">
            <h1 class=\"title\">Bigrammes pour le mot : $MOT_CLE</h1>
            <a href=\"../$FICHIER_RESULTAT\" class=\"button is-small is-link is-outlined mb-4\">Retour au tableau</a>
            <table class=\"table is-striped is-hoverable is-fullwidth\">
                <thead>
                    <tr>
                        <th class=\"has-text-right\" style=\"width:45%\">Contexte gauche</th>
                        <th class=\"has-text-centered\">Mot</th>
                        <th class=\"has-text-left\" style=\"width:45%\">Contexte droit</th>
                    </tr>
                </thead>
                <tbody>" > "$f_2gram"

            # grep -P : utilise des regex Perl pour une meilleure gestion des mots (\w) et non-mots (\W)
            # -o : affiche uniquement la partie correspondante (le bigramme)
            # -i : insensible à la casse
            # Regex : \w+ (mot gauche) \W+ (séparateur) \w*$MOT_CLE\w* (mot contenant le mot clé) \W+ (séparateur) \w+ (mot droit)
            # sed 1 : remplace le mot central par des balises de fin/début de colonne pour le centrer
            # sed 2 : ajoute le début de ligne du tableau
            # sed 3 : ajoute la fin de ligne du tableau
            grep -P -o -i "\w+\W+\w*$MOT_CLE\w*\W+\w+" "$f_dump" | sed -E "s/(\w*$MOT_CLE\w*)/<\/td><td class=\"has-text-centered\"><strong>\1<\/strong><\/td><td class=\"has-text-left\">/I" | sed -E "s/^/<tr><td class=\"has-text-right\">/" | sed -E "s/$/<\/td><\/tr>/" >> "$f_2gram"

            echo "</tbody>
            </table>
        </div>
    </section>
</body>
</html>" >> "$f_2gram"

        else
            echo "" > "$f_dump"
            echo "Erreur HTTP $code" > "$f_contexte"
            echo "" > "$f_concordance"
            compte=0
        fi

        # output pour le tableau, avec une ligne par URL
        echo "    <tr>
        <td>$lineno</td>
        <td><a href="$URL" target="_blank">lien</a></td>
        <td>$code</td>
        <td>$encoding</td>
        <td>$compte</td>
        <td><a href=\"../concordances/${LANGUE}-${lineno}.html\">concordance</a></td>
        <td><a href=\"../bigrams/${LANGUE}-${lineno}.html\">bigrammes</a></td>
        <td><a href=\"../aspirations/${LANGUE}-${lineno}.html\">html</a></td>
        <td><a href=\"../dumps-text/${LANGUE}-${lineno}.txt\">txt</a></td>
        <td><a href=\"../contextes/${LANGUE}-${lineno}.txt\">contexte ($nb_contexte lignes)</a></td>
        </tr>" >> "$FICHIER_RESULTAT"

        ((lineno++))

    fi
done < "$FICHIER_URL"

echo "</tbody>
</table>
</div>
</div>
</div>
</section>" >> "$FICHIER_RESULTAT"
echo "fichier texte généré: $FICHIER_RESULTAT"
