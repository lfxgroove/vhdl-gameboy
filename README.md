Vad ska vi göra i vårt projekt? Kravspec etc.

Konvertera markup till html/pdf
==============================

Börja med att installera PHP och köra mark2html.php som finns i mappen conversion genom att skriva exempelvis:

    cd conversion
    php mark2html.php fil_att_konvertera.txt

En fil som heter `fil_att_konvertera.html` skapas och den kan du sen konvertera till pdf mha wkhtmltopdf (ladda hem via AUR, ex: `yaourt -S wkhtmltopdf`) genom att skriva

    wkhtmltopdf from.html to.pdf

Prova att köra detta på filen `conversion/exempel1.txt` för att få en pdf-fil

====Kod snodd från====
*http://johbuc6.coconia.net/doku.php/mediawiki2html_machine/code