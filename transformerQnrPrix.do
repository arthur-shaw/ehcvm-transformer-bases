/*=============================================================================
paramètres du programme
=============================================================================*/

local projDir 	""
local progs 	"`projDir'/programmes"

* data
* local rawDtaDir "`projDir'/data/raw/prix/"
local inDtaDir 	"`projDir'/data/input/prix"
local tmpDtaDir "`projDir'/data/temp/prix"
local outDtaDir "`projDir'/data/output"

* labels
* local inLblDir 	"`projDir'/labels/input/prix/"
local tmpLblDir "`projDir'/labels/temp/prix"
local outLblDir "`projDir'/labels/output/prix"

* paramètres pays
local pays 		"" 							// nom raccourci du pays
local qnrNom 	""							// nom de la base principale (sans DTA à la fin)

set more 1

/*=============================================================================
confirmer que les paramètres sont bien spécifiés
=============================================================================*/

* aucun paramètre n'est vide

local parameters "projDir progs inDtaDir tmpDtaDir outDtaDir tmpLblDir outLblDir pays qnrNom"

foreach parameter of local parameters {

	capture assert "``parameter''" != ""
	if _rc != 0 {
		di as error "ERREUR: le paramètre -`parameter'- a été laissé vide. Veuillez le renseigner."
		error 1
	}

}

* tout répertoire existe

local folders "projDir progs inDtaDir tmpDtaDir outDtaDir tmpLblDir outLblDir"

foreach folder of local folders {

	capture cd "``folder''"
	if _rc != 0 {
		di as error "ERREUR: le dossier -`folder'- n'existe pas à l'endroit indiqué. Veuillez corriger."
		di as error "Chemin donné ci-haut: ``folder''"
		error 1
	}

}

/*=============================================================================

=============================================================================*/

/*-----------------------------------------------------------------------------
purger les résultats crées par les séances antérieures
-----------------------------------------------------------------------------*/
/*
local repertoires "tmpDtaDir tmpLblDir outLblDir"

foreach repertoire of local repertoires {

	! rmdir "``repertoire''/" /s /q
	! mkdir "``repertoire''/"

}
*/
/*-----------------------------------------------------------------------------
harmoniser les bases et extraire les étiquettes par base
-----------------------------------------------------------------------------*/

local produits "cereales viandes poissons huiles laitier fruits legumes legtub sucreries epices boissons"

foreach produit of local produits {
	
	* confirmer que le fichier existe ; sinon sauter au produit prochain
	capture confirm file "`inDtaDir'/`produit'.dta"
	if _rc != 0 {
		continue
	}

	* compiler la liste de produits retrouvées, ajoutant l'actuel produit à la liste
	local produitsRetrouves "`produitsRetrouves' `produit'"
	di as error "FICHIERS RETROUVES: `produitsRetrouves'"

	* fusionner les bases de niveau produit et de niveau produit-unité-taille
	use "`inDtaDir'/`produit'.dta", clear
	merge 1:m interview__id `produit'__id using "`inDtaDir'/releve_`produit'.dta", nogen
	
	* purger les variables
	drop s05q02_*
	
	* harmoniser le nom des variables
	rename `produit'__id 			produit__id
	rename releve_`produit'__id 	releve__id
	rename Existe_`produit' 		Existe
	rename s05q03_`produit' 		s05q03
	rename s05q04_`produit' 		s05q04

	* récupérer les étiquettes de valeur
	label save `produit'__id using "`tmpLblDir'/`produit'__id.do", replace
	label save releve_`produit'__id using "`tmpLblDir'/releve_`produit'__id", replace

	* arranger les observations logiquement
	sort interview__id produit__id releve__id
	
	* sauvegarder avec suffix _prix
	tempfile `produit'_prix
	save "``produit'_prix'"
	save "`tmpDtaDir'/`produit'_prix.dta", replace

}

/*-----------------------------------------------------------------------------
créer les étiquettes globales
-----------------------------------------------------------------------------*/

* sauvegarder les étiquettes comme bases de données
foreach produit of local produitsRetrouves {

	foreach prodVar in `produit'__id releve_`produit'__id {

		import delimited using "`tmpLblDir'/`prodVar'.do", ///
			delimiters("\t") varnames(nonames) stripquote(no) clear

		if "`prodVar'" == "`produit'__id" {

			replace v1 = subinstr(v1, "`produit'__id", "produitID", .)

			save "`tmpLblDir'/`produit'__id.dta", replace

		}

		if "`prodVar'" == "releve_`produit'__id" {

			replace v1 = subinstr(v1, "releve_`produit'__id", "releveID", .)

			save "`tmpLblDir'/releve_`produit'__id.dta", replace

		}

	}

}

* combiner et déduplifier les étiquettes

	// identifiants de produit
	local prodCount = 1

	foreach produit of local produitsRetrouves {

		if `prodCount' == 1 {
			use "`tmpLblDir'/`produit'__id.dta", clear
		}
		else if `prodCount' > 1 {
			append using "`tmpLblDir'/`produit'__id.dta"
		}

		local ++prodCount

	}

	duplicates drop v1, force
	order v1
	outsheet using "`outLblDir'/produitID.do", nonames noquote replace

	// identifiants d'unité-taille
	local prodCount = 1

	foreach produit of local produitsRetrouves {

		if `prodCount' == 1 {
			use "`tmpLblDir'/releve_`produit'__id.dta", clear
		}
		else if `prodCount' > 1  {
			append using "`tmpLblDir'/releve_`produit'__id.dta"
		}

		local ++prodCount

	}

	duplicates drop v1, force
	order v1
	outsheet using "`outLblDir'/releveID.do", nonames noquote replace

/*-----------------------------------------------------------------------------
rassembler les bases et afficher les étiquettes
-----------------------------------------------------------------------------*/

local prodCount = 1

foreach produit of local produitsRetrouves {

	if `prodCount' == 1 {
		use "``produit'_prix'", clear
	}
	else if `prodCount' > 1 {
		append using "``produit'_prix'"
	}

	local ++prodCount

}

include "`outLblDir'/produitID.do"
label values produit__id produitID

include "`outLblDir'/releveID.do"
label values releve__id releveID

merge m:1 interview__id using "`inDtaDir'/`qnrNom'.dta", nogen

drop sssys_irnd has__errors interview__status

save "`outDtaDir'/s5_co_`pays'2018.dta", replace
