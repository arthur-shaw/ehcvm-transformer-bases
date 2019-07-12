
capture program drop combineConsumption
program define combineConsumption
syntax ,					///
	inputDir(string)		///
	outputDir(string)		///
	labelDir(string)		///

	/*=============================================================================
							CHECK PROGRAM SET-UP
	=============================================================================*/
/*
	* répertoires existent
	foreach dirVoulu in inputDir outputDir {

		capture cd "``dirVoulu''"
		if _rc != 0 {
			di as error "ERREUR: Le répertoire `dirVoulu', dicté en début de programme, n'existe pas. Veuillez corriger l'emplacement du répertoire ou créer le répertoire"
			error 1
		}
		
	}

	* tous les fichiers de produits existent
	local produits = "`products'"
	local produitsManquants ""

	foreach produit of local produits {
		capture confirm file "`inputDir'/`produit'.dta"
		if _rc !=0 {
			local produitsManquants "`produitsManquants' `produit'"
		}
	}
	if "`produitsManquants'" != "" {
		di as error "Les produits suivants ne sont pas parmi les bases de ce répertoire : "
		di as error "`produitsManquants'"
		error 1
	}
*/
	/*=============================================================================
							COMBINE CONSUMPTION DATA SETS
	=============================================================================*/

	* créer une base par groupe de produit avec des noms de variable harmonisés
	local produits "cereales viandes poissons huiles laitier fruits legumes legtub sucreries epices boissons"
	foreach produit of local produits {

		use "`inputDir'/`produit'.dta", clear

		qui : d *_`produit', varlist
		local consVars = r(varlist)

		label save `produit'__id using "`labelDir'/`produit'__id.do", replace

* save value labels
		qui : ds, has(vallabel)
		local varsWithVLabels = r(varlist)
		local idVar "`produit'__id"
		local varsWithVLabels : list varsWithVLabels - idVar

		foreach varWith of local varsWithVLabels {
			label save `varWith' using "`labelDir'/`varWith'.do", replace
		}

		foreach consVar of local consVars {

			local consVarSansSuffixe = subinstr("`consVar'", "_`produit'", "", .)
			rename `consVar' `consVarSansSuffixe'

		}

		rename `produit'__id produitID

		tempfile `produit'_harmonise
		save "``produit'_harmonise'"

	}

	foreach produit of local produits {

		local varsWithVLabels_noSuffix = subinstr("`varsWithVLabels'", "_`produit'", "", .)

	}

	* append labels
	foreach produit of local produits {

		import delimited using "`labelDir'/`produit'__id.do", ///
			delimiters("\t") varnames(nonames) stripquote(no) clear

		replace v1 = subinstr(v1, "`produit'__id", "produitID", .)

		save "`labelDir'/`produit'__id.dta", replace

* save value labels
		foreach varWith_noSuffix of local varsWithVLabels_noSuffix {

			import delimited using "`labelDir'/`varWith_noSuffix'_`produit'.do", ///
				delimiters("\t") varnames(nonames) stripquote(no) clear

			replace v1 = subinstr(v1, "_`produit'", "", .)

			save "`labelDir'/`varWith_noSuffix'_`produit'.dta", replace

		}


	}

	local prodCounter = 1

	foreach produit of local produits {

		if `prodCounter' == 1 {
			use "`labelDir'/`produit'__id.dta", clear
		}
		else if `prodCounter' > 1 {
			append using "`labelDir'/`produit'__id.dta"
		}

		local ++prodCounter		

	}

	outsheet using "`labelDir'/produitID.do", nonames noquote replace

* save labels
	foreach varWith_noSuffix of local varsWithVLabels_noSuffix {

		local prodCounter = 1

		foreach produit of local produits {

			if `prodCounter' == 1 {
				use "`labelDir'/`varWith_noSuffix'_`produit'.dta", clear
			}
			else if `prodCounter' > 1 {
				append using "`labelDir'/`varWith_noSuffix'_`produit'.dta"
			}

			local ++prodCounter		

		}	

		duplicates drop v1, force
		outsheet using "`labelDir'/`varWith_noSuffix'.do", nonames noquote replace

	}


	* append data files together
	local premierProduit : word 1 of `produits'
	local produitsRestants : list produits - premierProduit

	local prodCounter = 1

	foreach produit of local produits {

		if `prodCounter' == 1 {

			use "``produit'_harmonise'", clear 

	/* TODO: add coercion to type if not expected type */

		}
		else if `prodCounter' > 1 {

			append using "``produit'_harmonise'"

		}

		local ++prodCounter

	}

	* apply variable labels
	include "`labelDir'/produitID.do"
	label values produitID produitID

* save labels
	foreach varWith_noSuffix of local varsWithVLabels_noSuffix {

		include "`labelDir'/`varWith_noSuffix'.do"
		label values `varWith_noSuffix' `varWith_noSuffix'

	}

	save "`outputDir'/consommationAlimentaire.dta", replace

end
