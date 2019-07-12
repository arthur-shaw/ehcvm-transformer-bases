# Table des matières

- [Présentation rapide](#présentation-rapide)
- [Installation](#installation)
- [Paramétrage](#paramétrage)
- [Mode d'emploi](#mode-demploi)
- [Explication des programmes ressource](#explication-des-programmes-ressource)

## Présentation rapide

Les données de l'EHCVM sont exportées dans un format différent que les attentes habituelles des utilisateurs de données. Les programmes de ce répositoires transforment les données brutes en format voulu. Notamment:

- Créant autant de fichiers que de sections dans le questionnaire papier. (Survey Solutions exporte un fichier par niveau d'observation. Par exemple, une base du niveau ménage, une de niveau membres du ménage, etc., toute section confuse.)
- Ramenant les questions "source" dans les rosters. (Survey Solutions les place dans la base du niveau d'observation supérieure à la base roster. Par exemple, la liste des membres du ménage se trouve au niveau ménage, les questions oui/non concernant la consommation alimentaire se trouvent au niveau ménage, etc.)
- Harmonisant les noms de varaible, autant que possible, avec les indications sur le papier.

## Installation

### Télécharger ce répositoire

- Cliquer sur le bouton `Clone or download`
- Cliquer sur l'option `Download ZIP`
- Télécharger dans le dossier sur votre machine où vous voulez héberger ce projet

### Copier les bases dans les répertoires

Pour les bases du questionnaire ménage, dans le répertoire `/data/raw/`.
Pour les bases du questionnaire prix, le répertoire `/data/input/prix/`.

## Paramétrage

### transformerQnrMenage

Ouvrir `transformerQnrMenage.do`, et renseigner les paramètres suivants:

- `projDir`. Chemin du projet.
- `pays`. Raccourci du nom du pays.

Sauvegarder le fichier.

### transformerQnrPrix

Ouvrir `transformerQnrPrix.do`, et renseigner les paramètres suivants:

- `projDir`. Chemin du projet.
- `pays`. Raccourci du nom du pays.
- `qnrNom`. Nom de la base principale (sans extension `.dta` à la fin)

Sauvegarder le fichier.

## Mode d'emploi

Lancer le programme pour transformer les bases brûtes en de bases du nombre et du format voulu.

## Explication des programmes ressource

### combineConsumption

À VENIR

### mergeTrigger

À VENIR

### reshapeNestedLaborToWide

À VENIR

### saveSection

À VENIR
