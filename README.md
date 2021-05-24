# Projet réalisé par MANGEL Léo et MICHEL Thomas

Nous avons réalisé le niveau 2 du projet.

Nous avons implémenté l'amélioration 2, c'est à dire les
labels. Dans la version implémentée, les prédicats de la forme p@ici peuvent se
trouver dans toutes les expressions du programme (et donc pas seulement dans
les spécifications). Nous avons également choisi que ```ici : stmt1; stmt2```
s'interprète comme ```ici : (stmt1; stmt2)``` (ie. stmt1 et stmt2 sont tous les deux étiquetés "ici").

Nous avons également implémenté en partie l'amélioration 1. Cette partie est peu personnalisée et utilise simplement l'une des fonctionnalités de Bison. En cas d'erreur lors de l'analyse syntaxique, le token attendu ainsi que le numéro de la ligne correspondante sont affichés.

## Choix d'implémentation:
- Le parser prend deux paramètres supplémentaires : Le nombre d'exécution du programme et le nombre maximal d'étapes du programme lors d'une exécution.
- Choix de l'une des alternatives parmi celles dont la condition est vérifiée avec une probabilité uniforme.
- L'instruction break met fin au processus si elle se trouve en dehors d'une boucle.
- Une variable doit être initialisée par un processus avant d'être utilisée. Ainsi toute expression contenant une variable non initialisée sera évaluée à 0. Cela permettait de résoudre le problème des variables initialisées à 0 dans le programme ```lock.prog``` mais c'est moins utile suite au correctif de ce programme reçu par mail.
