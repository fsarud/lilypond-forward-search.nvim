# Forward search bidireccional en Neovim-lilypond-suite

## Descripción

Este pequeño proyecto es una implementación en neovim/zathura de la funcionalidad de Frescobaldi para la edición en Lilypond.

## Requisitos

- PyMuPdf
- neovim-lilypond-suite

## main file

Incluí una pequeña opción para trabajar con libros con includes. La idea es que si el archivo no compila, sino que lo que lo hace es otro archivo, hay que poner

% master: file.ly

así, comentado, para que lo reconozca. Así, cuando se compila con F5, se compila file.ly directamente.

Eso sí, todos los archivos .ly (el master y los includes) deben estar en la misma carpeta.
