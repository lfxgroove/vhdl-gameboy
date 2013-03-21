#!/bin/bash

php conversion/mark2html.php $1 $1.html
wkhtmltopdf $1.html $1.pdf
rm $1.html
