
/*=============================================================================
paramètres du programme
=============================================================================*/

local projDir 	""
local progs 	"`projDir'/programmes/"

* data
local rawDtaDir "`projDir'/data/raw/"		// données brutes
local inDtaDir 	"`projDir'/data/input/" 	// données légèrement modifiées
local tmpDtaDir "`projDir'/data/temp/" 		// fichiers temporaires
local outDtaDir "`projDir'/data/output/" 	// données finales

* labels
local inLblDir 	"`projDir'/labels/input/"
local tmpLblDir "`projDir'/labels/temp/"
local outLblDir "`projDir'/labels/output/"

* paramètres pays
local pays 		"" 							// nom raccourci du pays

set more 1

/*=============================================================================
charger les programmes de service
=============================================================================*/

* harmoniser le nom des fichiers

include "`progs'/combineConsumption"

include "`progs'/mergeTrigger.do"

include "`progs'/reshapeNestedLaborToWide.do"

/*=============================================================================
		SUPPRIMER LES DONNÉES DE LA SÉANCE ULTÉRIEURE
=============================================================================*/

* supprimer l'ensemble des données pour des soucis de ne pas créer des doublons (dû à la manière dont les fichiers préliminaires sont créées)

local repertoires "inDtaDir tmpDtaDir outDtaDir tmpLblDir outLblDir"

foreach repertoire of local repertoires {

	! rmdir "``repertoire''/" /s /q
	! mkdir "``repertoire''/"

}

* supprimer des bases crées dans dataDir
local bases "menage2 consommationAlimentaire"

foreach base of local bases {

	capture rm "`inDtaDir'/`base'.dta"
	
}

/*=============================================================================
harmoniser le nom des bases d'entrée
=============================================================================*/

/*-----------------------------------------------------------------------------
confirmer que les bases attendues sont présentes
-----------------------------------------------------------------------------*/

* puiser le nom des fichiers attends d'une compilation externe
file open expectedFiles using "`progs'/expectedFiles.txt", read text
file read expectedFiles line

* allant entrée par entrée du fichier, confirmer l'existence d'un fichier de ce nom
while r(eof) == 0 {
	local dfile = "`line'"
	capture confirm file "`rawDtaDir'/`dfile'"
	if _rc != 0 {
		local missingDfiles = "`missingDfiles' `dfile'"
	}
	file read expectedFiles line
}

file close expectedFiles

* afficher un message d'erreur si au moins un fichier frustre les attentes
local numMissingFiles : list sizeof missingDfiles
if `numMissingFiles' > 0 {

	local errMsg = "ERREUR: Les fichiers suivants sont absents ou présents sous d'autres noms. " + ///
		"Veuillez corriger le nom de ces fichiers en les alignant avec les attentes" + ///
		"Les fichiers sont : `missingDfiles'"
	pause "`errMsg'"			

}

/*-----------------------------------------------------------------------------
modifier les noms pour s'accorder avec les attentes du programme
-----------------------------------------------------------------------------*/

if `numMissingFiles' > 0 {

	cd "`rawDtaDir'/"

	local oldNames "Qx_MENAGE_EHCVM_TG1.dta equipment.dta"
	local newNames "menage.dta equipements.dta"

	local numNames : word count `oldNames'

	if ("`numNames'" == "") | ("`oldNames'" == "") {
		di as error "ERREUR: Veuillez spécifiez des fichiers à renommer"
		error 1
	}

	forvalues i = 1 / `numNames' {

		local oldName : word `i' of `oldNames'
		local newName : word `i' of `newNames'

		! ren "`oldName'" "`newName'"

	}

}

/*=============================================================================
définir les étiquettes de variable
=============================================================================*/

/*-----------------------------------------------------------------------------
créer des défintions d'étiquettes à partir des fichiers Excel
-----------------------------------------------------------------------------*/

file open expectedFiles using "`progs'/expectedFiles.txt", read text
file read expectedFiles line

while r(eof) == 0 {
	local lfile = "`line'"
	local lfile = subinstr("`lfile'", ".dta", "", .)

	* confirmer que un fichier avec étiquettes est présente
	capture confirm file "`inLblDir'/`lfile'_varnames_varlab.xlsx"
	
	* si le fichier est absent, prendre note
	if _rc != 0 {
		local missingLfiles = "`missingLfiles' `lfile'"
	}

	* si le fichier est présent, l'exploiter
	if _rc == 0 {

		di "Opening `lfile'"

		* ouvrir le fichier
		import excel using "`inLblDir'/`lfile'_varnames_varlab.xlsx", firstrow case(preserve) allstring clear

		* confirmer que les deux colonnes nécessaires sont présentes
		capture confirm variable VarName NewLabel
		
		* si non, prendre note et continuer au fichier prochain
		if _rc != 0 {

			local problemLabels = "`problemLabels' `lfile'"
			file read expectedFiles line
			continue

		}

		* retenir les variables nécessaires et les observations avec contenu
		keep VarName NewLabel
		drop if NewLabel == ""
		qui: d

		* écrire un fichier .do dictant les étiquettes à partir de l'info dans le fichier Excel
		file open `lfile' using "`outLblDir'/`lfile'.do", write append

		forvalues i = 1 / `r(N)' {

			local currVar = VarName[`i']
			local currLabel = NewLabel[`i']
			if `i' == 1 {
				file write `lfile' "#delim ;" _n
			}
			file write `lfile' `"capture label variable `currVar' `"`currLabel'"';   "' _n
			if `i' == `r(N)' {
				file write `lfile' "#delim cr" _n
			}

		}

		file close `lfile'

	}

	file read expectedFiles line

	}

file close expectedFiles

* émettre des messages d'erreur pour les fichiers introuvables et/ou inexploitable
if "`missingLfiles'" != "" {
	di "ERREUR: Des étiquettes pour les bases suivantes n'ont pas été retrouvées : `missingLfiles'"
	* error 1
}
if "`problemLabels'" != "" {
	di "ERREUR: Des fichiers d'étiquettes ont un contenu qui n'est pas en phase avec les attentes du programme : `problemLabels'"
	* error 1
}

/*-----------------------------------------------------------------------------
appliquer les étiquettes de variable dictées dans des fichiers externes
-----------------------------------------------------------------------------*/

file open expectedFiles using "`progs'/expectedFiles.txt", read text
file read expectedFiles line

while r(eof) == 0 {
	local dfile = "`line'"
	local lfile = subinstr("`dfile'", ".dta", "", .)

	capture confirm file "`rawDtaDir'/`dfile'"
	if _rc != 0 {

		local missingDfiles = "`missingDfiles' `dfile'"		
		file read expectedFiles line
		continue

	}

	capture use "`rawDtaDir'/`dfile'", clear
	capture include "`outLblDir'/`lfile'.do"
	save "`inDtaDir'/`dfile'", replace

	file read expectedFiles line
}

file close expectedFiles

* émettre des messages d'erreur pour les fichiers introuvables et/ou inexploitable
if "`missingDfiles'" != "" {
	di "ERREUR: Des bases n'ont pas été retrouvées : `missingDfiles'"
	* error 1
}

/*=============================================================================
RENDRE LES ROSTERS CONFORMES AU QUESTIONNAIRE PAPIER
=============================================================================*/

* 7B : consommation alimentaire

// "fusionner" toute les bases de consommation alimentaire
combineConsumption ,								///
	inputDir("`inDtaDir'")							///
	outputDir("`inDtaDir'")							///
	labelDir("`tmpLblDir'")							///


// ramener le nom des questions filter au modèle attendu par mergeTrigger
use "`inDtaDir'/menage.dta", clear
qui: d s07Bq02_*, varlist
local ynVars = r(varlist)
foreach yn of local ynVars {
	local match = regexm("`yn'", "(s07Bq02)_[a-z]+(__[0-9]+)")
	if `match' == 1 {
		local newYN = regexs(1) + regexs(2)
		rename `yn' `newYN'
	}
	else if `match' == 0 {
		di as error "Variable not renamed: `yn'"
	}
}

tempfile menage
save "`menage'"
save "`inDtaDir'/menage2.dta", replace
save "`inDtaDir'/menage.dta", replace

use "`inDtaDir'/consommationAlimentaire.dta", clear
rename produitID consommationAlimentaire__id
save "`inDtaDir'/consommationAlimentaire.dta", replace

// intégrer la questionn source dans le roster
mergeTrigger, 										///
	rosterTrigger(s07Bq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage2") 							///
	rosterFile("consommationAlimentaire")			///
	newRosterID("s07Bq01")							///
	saveDir("`inDtaDir'")

/* TODO: Combine value labels from all dsets */
label values s07Bq01 produitID
save "`inDtaDir'/consommationAlimentaire.dta", replace

* 9A: dépenses des fêtes et cérémonies au cours des 12 derniers mois
mergeTrigger, 										///
	rosterTrigger(s09Aq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("depense_fete")						///
	newRosterID("s09Aq01")							///
	saveDir("`inDtaDir'")

* 9B. dépenses non-alimentaires des 7 derniers jours
mergeTrigger, 										///
	rosterTrigger(s09Bq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("depense_7j")						///
	newRosterID("s09Bq01")							///	
	saveDir("`inDtaDir'")

* 9C: dépenses non-alimentaires des 30 derniers jours
mergeTrigger, 										///
	rosterTrigger(s09Cq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("depense_30j") 						///
	newRosterID("s09Cq01")							///	
	saveDir("`inDtaDir'")

* 9D: dépenses non-alimentaires des 3 derniers mois
mergeTrigger, 										///
	rosterTrigger(s09Dq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("depense_3m") 						///
	newRosterID("s09Dq01")							///	
	saveDir("`inDtaDir'")

* 9E: dépenses non-alimentaires des 6 derniers mois
mergeTrigger, 										///
	rosterTrigger(s09Eq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("depense_6m") 						///
	newRosterID("s09Eq01")							///	
	saveDir("`inDtaDir'")

* 9F: dépenses non-alimentaires des 12 derniers mois
mergeTrigger, 										///
	rosterTrigger(s09Fq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("depense_12m") 						///
	newRosterID("s09Fq01")							///	
	saveDir("`inDtaDir'")

* 10: entreprises

	* ramener au niveau parcelle le travail familial ...
	reshapeNestedLaborToWide using "`inDtaDir'/entreprise_travailFamilial.dta", 							///
		allIDs(interview__id interview__key entreprises__id entreprise_travailFamilial__id) 	///
		filterVar(s10q61a) 		///
		currID(entreprise_travailFamilial__id) 	///
		newID(s10q61a) 			///
		varsToKeep(s10q61b s10q61c s10q61d) 		///

	tempfile entreprise_travailFamilial
	save "`entreprise_travailFamilial'"

	* ramener au niveau parcelle le travail salarié ...
	reshapeNestedLaborToWide using "`inDtaDir'/entreprise_travailSalarie.dta", 						///
		allIDs(interview__id interview__key entreprises__id entreprise_travailSalarie__id) 			///
		currID(entreprise_travailSalarie__id) 	///
		varsToKeep(s10q62a s10q62b s10q62c s10q62d) 	///

	tempfile entreprise_travailSalarie
	save "`entreprise_travailSalarie'"

	use "`inDtaDir'/entreprises.dta", clear
	merge 1:1 interview__id entreprises__id using "`entreprise_travailFamilial'", nogenerate
	merge 1:1 interview__id entreprises__id using "`entreprise_travailSalarie'", nogenerate

	* modifier le nom des identifiants numériques et string
	rename entreprises__id s10q12a_1
	rename s10q12a s10q12a_2

	tempfile entreprises
	save "`entreprises'"
	save "`inDtaDir'/entreprises.dta", replace

* 12 : actifs du ménage
mergeTrigger, 										///
	rosterTrigger(s12q02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("actifs") 							///
	newRosterID("s12q01")							///	
	saveDir("`inDtaDir'")

* 14 : chocs et stratégies de survie

	* inclure d'abord 14.03
	mergeTrigger, 									///
		rosterTrigger(s14q03) 						///
		triggerType("multi-select-ordered")			///
		dataDir("`inDtaDir'")						///
		mainFile("menage") 							///
		rosterFile("chocs")							///
		saveDir("`inDtaDir'")

	tempfile chocsImportants
	save "`chocsImportants'"

	* transformer 14.02 en format long
	use "`menage'", clear
	keep interview__id interview__key s14q02__*
	reshape long s14q02__, i(interview__key interview__id) j(chocs__id)
	rename s14q02__ s14q02


	* fusionner les rosters
	merge 1:1 interview__id chocs__id using "`chocsImportants'"

	* rattacher les étiquettes de valeur
	label values chocs__id chocs__id

	recode s14q02 (0=1)
	label define s14q02 1 "Oui" 2 "Non"
	label values s14q02 s14q02

	recode s14q03 (0 = .)
	label define s14q03 1 "Le plus sévère" 2 "Deuxième" 3 "Le moins sévère des trois"
	label values s14q03 s14q03

	save "`inDtaDir'/chocs.dta", replace

* 15 : filets de sécurité
mergeTrigger, 										///
	rosterTrigger(s15q02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("filets_securite") 					///
	newRosterID("s15q01")							///	
	saveDir("`inDtaDir'")


* 16A : champs-parcelles

	* créer une base champs-parcelles
	use "`inDtaDir'/champs.dta", clear
	drop s16Aa01b*
	merge 1:m interview__id champs__id using "`inDtaDir'/parcelles.dta", assert(1 3) nogenerate
	drop s16Cq03*	/// sélection de cultures pratiquées

	tempfile champs_parcelles
	save "`champs_parcelles'"
	save "`inDtaDir'/champs_parcelles.dta", replace

	* ramener au niveau parcelle le travail familial ...

		* ...  lors du semis 
		reshapeNestedLaborToWide using "`inDtaDir'/preparation_f.dta", 							///
			allIDs(interview__id interview__key champs__id parcelles__id preparation_f__id) 	///
			filterVar(s16Aq33a) 		///
			currID(preparation_f__id) 	///
			newID(s16Aq33a) 			///
			varsToKeep(s16Aq33b) 		///

		tempfile semisFamilial
		save "`semisFamilial'"

		* ... lors du sarclage
		reshapeNestedLaborToWide using "`inDtaDir'/preparation_f.dta", 							///
			allIDs(interview__id interview__key champs__id parcelles__id preparation_f__id) 	///
			filterVar(s16Aq35a) 		///
			currID(preparation_f__id) 	///
			newID(s16Aq35a) 			///
			varsToKeep(s16Aq35b) 		///

		tempfile sarclageFamilial
		save "`sarclageFamilial'"

		* ... lors de la récolte
		reshapeNestedLaborToWide using "`inDtaDir'/preparation_f.dta", 							///
			allIDs(interview__id interview__key champs__id parcelles__id preparation_f__id) 	///
			filterVar(s16Aq37a) 		///
			currID(preparation_f__id) 	///
			newID(s16Aq37a) 			///
			varsToKeep(s16Aq37b) 		///

		tempfile recolteFamilial
		save "`recolteFamilial'"

	* ramener au niveau parcelle la main d'oeuvre non-familiale

		* ...  lors du semis 
		reshapeNestedLaborToWide using "`inDtaDir'/preparation_sol_semi_nf.dta", 						///
			allIDs(interview__id interview__key champs__id parcelles__id preparation_sol_semi_nf__id) 	///
			currID(preparation_sol_semi_nf__id) 	///
			varsToKeep(s16Aq39a s16Aq39b s16Aq39c) 	///

		tempfile semisNonFam
		save "`semisNonFam'"

		* ... lors du sarclage
		reshapeNestedLaborToWide using "`inDtaDir'/entretien_nf.dta", 						///
			allIDs(interview__id interview__key champs__id parcelles__id entretien_nf__id) 	///
			currID(entretien_nf__id) 	///
			varsToKeep(s16Aq41a s16Aq41b s16Aq41c) 	///

		tempfile sarclageNonFam
		save "`sarclageNonFam'"

		* ... lors de la récolte
		reshapeNestedLaborToWide using "`inDtaDir'/recolte_nf.dta", 							///
			allIDs(interview__id interview__key champs__id parcelles__id recolte_nf__id) 	///
			currID(recolte_nf__id) 					///
			varsToKeep(s16Aq43a s16Aq43b s16Aq43c) 	///

		tempfile recolteNonFam
		save "`recolteNonFam'"

	* rattacher les bases concernant le travail à la base champ-parcelle

	use "`champs_parcelles'", clear

	local baseTravail "semisFamilial sarclageFamilial recolteFamilial semisNonFam sarclageNonFam recolteNonFam"

	foreach base of local baseTravail {

		di "Base en cours de fusion: `base'"
		merge 1:1 interview__id interview__key champs__id parcelles__id using "``base''", nogenerate

	}

	* renommer les identifiants de champ et de parcelle pour s'aligner avec le papier
	rename champs__id 		s16aq02
	rename parcelles__id	s16aq03

	save "`inDtaDir'/champs_parcelles.dta", replace

* 16B : coût des intrants
mergeTrigger, 										///
	rosterTrigger(s16Bq02) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("cout_intrants") 					///
	newRosterID("s16Bq01")							///	
	saveDir("`inDtaDir'")

* 16C : champs-parcelles-cultures

use "`champs_parcelles'", clear
keep interview__key interview__id champs__id s16A01a parcelles__id s16Aa01b
merge 1:m interview__id champs__id parcelles__id using "`inDtaDir'/cultures.dta", ///
	assert(1 3) 	/// admettre la possibilité de n'avoir aucune culture
	nogenerate 		///

	* renommer les identifiants de champ, de parcelle, et de culture pour s'aligner avec le papier

	// champs
	rename s16A01a			s16cq01		/* TODO: Determine whether name should be separate champs and parcelles string vars or the concatenation of the two stored in s16c01 */
	rename champs__id 		s16cq02

	// parcelles
	rename s16Aa01b 		s16cq03b
	rename parcelles__id	s16cq03

	// cultures
	rename cultures__id 	s16cq04
	/* TODO: Create cultures name by creating a string var that is label for val of s16cq04 */

tempfile champs_parcelles_cultures
save "`champs_parcelles_cultures'"
save "`inDtaDir'/champs_parcelles_cultures.dta", replace

* 17 : élevage
mergeTrigger, 										///
	rosterTrigger(s17q03) 							///
	triggerType("multi-select-yn") 					///
	dataDir("`inDtaDir'")							///
	mainFile("menage") 								///
	rosterFile("elevage") 							///
	newRosterID("s17q02")							///	
	saveDir("`inDtaDir'")

/* TODO: Create animal names by creating a string var that is label for val of s17q02 */

/*=============================================================================
CRÉER DES FICHIERS PAR SECTION-NIVEAU
=============================================================================*/

local SuSoIDs "interview__key interview__id"
local caseIDs 	"grappe Id_menage vague"

use "`inDtaDir'/menage.dta", clear

/*-----------------------------------------------------------------------------
rosters des membres
-----------------------------------------------------------------------------*/

capture program drop saveSection
program define saveSection
syntax 						///
	using/ , 				///
	mainFile(string)		///
	susoIDs(string) 		///
	caseIDs(string) 		///
	currVarStub(string) 	///
	[newVarStub(string)] 	///
	roster(string)			///
	[othVars(string)]		///
	[varsToExclude(string)] ///
	[rosterIDFrom(string)] 	///
	[rosterIDTo(string)] 	///
	[listNameFrom(string)] 	///
	[listNameTo(string)] 	///
	[listIdFrom(string)] 	///
	[listIdTo(string)] 		///
	[sortBy(string)] 		///
	saveStub(string) 		///
	pays(string) 			///
	saveDir(string) 		///

	* if a roster, merge in roster file
	if "`roster'" == "yes" {
		use "`mainFile'", clear
		keep `susoIDs' `caseIDs'
		merge 1:m `susoIDs' using "`using'", nogenerate
	}
	else if "`roster'" == "no" {
		use "`mainFile'", clear
	}

	* if list roster, rename ID and name variables to fit section naming scheme
	if ("`listIdFrom'" != "") & ("`listIdTo'" != "") {
		rename `listIdFrom' `listIdTo'
	}
	if ("`listNameFrom'" != "") & ("`listNameTo'" != "") {
		rename `listNameFrom' `listNameTo'
	}

	* if multi-select roster, rename ID to fit section naming scheme
	if ("`rosterIDFrom'" == "") & ("`rosterIDTo'" != "") {
		local detectFile = regexm("`using'", "[\/\]([A-Za-z_0-9]+).dta$")
		local fileName = regexs(1)
		rename `fileName'__id `rosterIDTo'
	}
	if ("`rosterIDFrom'" != "") & ("`rosterIDTo'" != "") {
		rename `rosterIDFrom' `rosterIDTo'
	}

	* discard variables to be excluded
	if "`varsToExclude'" != "" {
		capture drop `varsToExclude'
	}

	* rename variables if old andd new stubs specified
	if ("`currVarStub'" != "") & ("`newVarStub'" != "") {
		qui: d s`currVarStub'*, varlist
		local oldVars = r(varlist)
		local newVars = subinstr("`oldVars'", "s`currVarStub'", "s`newVarStub'", .)
		rename (`oldVars') (`newVars')
		keep `susoIDs' `caseIDs' s`newVarStub'* `othVars'
	}
	else if ("`currVarStub'" != "") & ("`newVarStub'" == "") {
		keep `susoIDs' `caseIDs' s`currVarStub'* `othVars'
	}

	* sort data by indicated variables
	if ("`sortBy'" != "") {
		sort `sortBy'
	}

	* output a file with section name
	save "`saveDir'/s`saveStub'_me_`pays'2018.dta", replace

end


/*-----------------------------------------------------------------------------
section 0
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///	
	othVars(GPS* nom_prenom_cm localisation_menage visite* format_interview 	///
		observation) 															///
	currVarStub(00) saveStub(00) roster(no) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 1
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///
	sortBy(interview__id s01q00a) 												///
	currVarStub(01) saveStub(01) roster(yes) pays(`pays') saveDir(`outDtaDir')

* ne retenir que les colonnes utilisées pour capter toutes les épouses (de l'échantillon)

// obtenir la liste de colonnes suivant ce schéma
capture drop s01q09_accord* // laisser tomber des variables superflues avec un nom semblable
qui: d s01q09*, varlist
local spouseVars = r(varlist)

// calculer le nombre de colonnes utilisées avec une formule différente selon le type de stockage
local spouseVarType : type s01q09__0
if (substr("`spouseVarType'", 1, 3) == "str") {
	foreach spouseVar of local spouseVars {
		replace `spouseVar' = "" if (`spouseVar' == "-999999999")
	}	
	egen numSpouse = rownonmiss(`spouseVars'), strok
}
else if inlist("`spouseVarType'", "byte", "int", "long", "float", "double") {
	egen numSpouse = rownonmiss(`spouseVars')
}

// supprimer les colonnes non-utilisées
qui: sum numSpouse
local maxSpouse = r(max)
drop s01q09__`maxSpouse' - s01q09__59
drop numSpouse

// convertir les colonnes en format numériques, si nécessaire
if (substr("`spouseVarType'", 1, 3) == "str") {
	qui: d s01q09*, varlist
	local newSpouseVars = r(varlist)
	destring `newSpouseVars', replace
}

* sauvegarder la base sous le même nom que plus haut
save "`outDtaDir'/s01_me_`pays'2018.dta", replace

/*-----------------------------------------------------------------------------
section 2
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') othVars(s01q00a s01q00b)				///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///	
	sortBy(interview__id s01q00a) 												///
	currVarStub(02) saveStub(02) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 3
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') othVars(s01q00a s01q00b)				///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///
	sortBy(interview__id s01q00a) 												///	
	currVarStub(03) saveStub(03) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 4
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') othVars(s01q00a s01q00b)				///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///
	sortBy(interview__id s01q00a) 												///	
	currVarStub(04) saveStub(04) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 5
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') othVars(s01q00a s01q00b)				///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///
	sortBy(interview__id s01q00a) 												///	
	currVarStub(05) saveStub(05) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 6
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') othVars(s01q00a s01q00b)				///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///
	sortBy(interview__id s01q00a) 												///	
	currVarStub(06) saveStub(06) roster(yes) pays(`pays') saveDir(`outDtaDir')

* corriger le nom de variable
capture rename s06q011_autre s06q11_autre 
save "`outDtaDir'/s06_me_`pays'2018.dta", replace

/*-----------------------------------------------------------------------------
section 7A1
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(07A) newVarStub(07a) saveStub(07a1) roster(no) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 7A2
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/membres.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') othVars(s01q00a s01q00b)				///
	listIdFrom(membres__id) listIdTo(s01q00a) 									///
	listNameFrom(NOM_PRENOMS) listNameTo(s01q00b) 								///	
	sortBy(interview__id s01q00a) 												///
	currVarStub(07A) newVarStub(07a) saveStub(07a2) roster(yes) 				///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 7B
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/consommationAlimentaire.dta" , 					///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s07bq01) 												///
	currVarStub(07B) newVarStub(07b) saveStub(07b) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')	

/*-----------------------------------------------------------------------------
section 8A
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(08A) newVarStub(08a) saveStub(08a) roster(no) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 8B1
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(08B) newVarStub(08b) saveStub(08b1) roster(no) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 8B2
-----------------------------------------------------------------------------*/

* TODO: check whether there is a trigger to merge; check var names since don't match paper

saveSection using "`inDtaDir'/repas_non_membre.dta" , 							///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	rosterIDTo(s08bq03) 														///
	sortBy(interview__id s08bq03) 												///
	currVarStub(08B) newVarStub(08b) saveStub(08b2) roster(yes) 				///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 9A
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/depense_fete.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s09aq01) 												///
	currVarStub(09A) newVarStub(09a) saveStub(09a) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 9B
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/depense_7j.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
 	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s09bq01) 												///
	currVarStub(09B) newVarStub(09b) saveStub(09b) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 9C
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/depense_30j.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s09cq01) 												///
	currVarStub(09C) newVarStub(09c) saveStub(09c) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 9D
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/depense_3m.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s09dq01) 												///
	currVarStub(09D) newVarStub(09d) saveStub(09d) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 9E
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/depense_6m.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s09eq01) 												///
	currVarStub(09E) newVarStub(09e) saveStub(09e) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 9F
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/depense_12m.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s09fq01) 												///
	currVarStub(09F) newVarStub(09f) saveStub(09f) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 10A
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(10) saveStub(10_1) roster(no) 									///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 10B
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/entreprises.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(10) saveStub(10_2) roster(yes) 									///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 11
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(11) saveStub(11) roster(no) 									///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 12
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/actifs.dta" , 									///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s12q01) 												///
	currVarStub(12) saveStub(12) roster(yes) 									///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 13A_1
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , 									///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(13A) newVarStub(13a) saveStub(13a_1) roster(no) 				///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 13A_2
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/transferts_recus.dta" , 							///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	othVars(s13q04b) 															///
	rosterIDTo(s13aq04a) 														///
	sortBy(interview__id s13aq04a) 												///
	currVarStub(13A) newVarStub(13a) saveStub(13a_2) roster(yes) 				///
	pays(`pays') saveDir(`outDtaDir')

rename s13q04b s13aq04b
save "`outDtaDir'/s13a_2_me_`pays'2018.dta", replace

/*-----------------------------------------------------------------------------
section 13B_1
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , 									///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(13B) newVarStub(13b) saveStub(13b_1) roster(no) 				///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 13B_2
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/transferts_emis.dta" , 							///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	othVars(s13q21b) 															///
	rosterIDTo(s13bq21a) 														///
	sortBy(interview__id s13bq21a) 												///
	currVarStub(13B) newVarStub(13b) saveStub(13b_2) roster(yes) 				///
	pays(`pays') saveDir(`outDtaDir')

rename s13q21b s13bq21b
save "`outDtaDir'/s13b_2_me_`pays'2018.dta", replace

/*-----------------------------------------------------------------------------
section 14
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/chocs.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	rosterIDTo(s14q01) 															///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s14q01) 												///
	currVarStub(14) saveStub(14) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 15
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/filets_securite.dta" , 							///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s15q01) 												///	
	currVarStub(15) saveStub(15) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 16A
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/champs_parcelles.dta" , 							///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s16aq02 s16aq03) 										///
	currVarStub(16A) newVarStub(16a) saveStub(16a) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 16B
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/cout_intrants.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///	
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s16bq01) 												///
	currVarStub(16B) newVarStub(16b) saveStub(16b) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 16C
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/champs_parcelles_cultures.dta" , 					///
	mainFile("`inDtaDir'/menage.dta") 											///	
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s16cq02 s16cq03 s16cq04) 								///
	currVarStub(16C) newVarStub(16c) saveStub(16c) roster(yes) 					///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 17
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/elevage.dta" , 									///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	sortBy(interview__id s17q02) 												///
	currVarStub(17) saveStub(17) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 18
-----------------------------------------------------------------------------*/

* partie 1: niveau ménage
saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") ///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	varsToExclude(s18q12* s18q18*) 												///
	currVarStub(18) saveStub(18_1) roster(no) pays(`pays') saveDir(`outDtaDir')

	* ne retenir que les colonnes utilisées pour capter toutes les épouses (de l'échantillon)
	
	// obtenir la liste de colonnes suivant ce schéma
	qui: d s18q02*, varlist
	local pecheurVars = r(varlist)

	// calculer le nombre de colonnes utilisées avec une formule différente selon le type de stockage
	local pecheurVarType : type s18q02__0
	if (substr("`pecheurVarType'", 1, 3) == "str") {
		foreach pecheurVar of local pecheurVars {
			replace `pecheurVar' = "" if (`pecheurVar' == "-999999999")
		}
		egen numPecheurs = rownonmiss(`pecheurVars'), strok
	}
	else if inlist("`pecheurVarType'", "byte", "int", "long", "float", "double") {
		egen numPecheurs = rownonmiss(`pecheurVars')
	}

	// supprimer les colonnes non-utilisées
	qui: sum numPecheurs
	local maxPecheurs = r(max)
	drop s18q02__`maxPecheurs' - s18q02__59
	drop numPecheurs

	// convertir les colonnes en format numériques, si nécessaire
	if (substr("`pecheurVarType'", 1, 3) == "str") {
		qui: d s18q02*, varlist
		local newPecheurVars = r(varlist)
		destring `newPecheurVars', replace
	}

	* sauvegarder la base sous le même nom que plus haut
	save "`outDtaDir'/s18_1_me_`pays'2018.dta", replace

* partie 2: cout des licenses
saveSection using "`inDtaDir'/cout_permis.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(18) saveStub(18_2) roster(yes) pays(`pays') saveDir(`outDtaDir')

/* TODO: Merge s18q08 into hhold-level dset in wide format */

* partie 3: haute saison
saveSection using "`inDtaDir'/poisson_haute_saison.dta" , 						///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(18) saveStub(18_3) roster(yes) pays(`pays') saveDir(`outDtaDir')

* partie 4: basse saison
saveSection using "`inDtaDir'/poisson_basse_saison.dta" , 						///
	mainFile("`inDtaDir'/menage.dta") 											///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(18) saveStub(18_4) roster(yes) pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 19
-----------------------------------------------------------------------------*/

* aligner le nom de l'identifiant avec les attentes du programmes, s'il y a lieu de faire
use "`inDtaDir'/equipements.dta", clear
capture confirm equipments__id
if _rc != 0 {
	capture rename equipment__id equipements__id
	capture rename equipments__id equipements__id
	save "`inDtaDir'/equipements.dta", replace
}

saveSection using "`inDtaDir'/equipements.dta" , 								///
	mainFile("`inDtaDir'/menage.dta") 											///	
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	rosterIDFrom(equipements__id) rosterIDTo(s19q02) 							/// /* TODO: determine the "from" name programmatically since should be original raw file name + __id */
	sortBy(interview__id s19q02) 												///
	currVarStub(19) saveStub(19) roster(yes) 									///
	pays(`pays') saveDir(`outDtaDir')

/*-----------------------------------------------------------------------------
section 20
-----------------------------------------------------------------------------*/

saveSection using "`inDtaDir'/menage.dta" , mainFile("`inDtaDir'/menage.dta") 	///
	susoIDs(`SuSoIDs') caseIDs(`caseIDs') 										///
	currVarStub(20) saveStub(20) roster(no) pays(`pays') saveDir(`outDtaDir')

