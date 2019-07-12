capture program drop reshapeNestedLaborToWide
program define reshapeNestedLaborToWide
syntax 						///
	using , 				///
	allIDs(string) 			///
	[filterVar(string)] 	///
	currID(string) 			///
	[newID(string)] 			///
	varsToKeep(string) 		///

	* read in labor roster
	use `using', clear
		
	* keep only: plot ID(s), member ID, filter question about whether worked, attributes of work
	keep `allIDs' `filterVar' `varsToKeep'

	* if there is a filter question
	if "`filterVar'" != "" {

		* drop non-working members
		keep if `filterVar' == 1
		drop `filterVar'

		* create a new serial number from 1 to N for each working member
		sort `allIDs'
		local allIDButCurrID : list allIDs - currID
		bysort `allIDButCurrID' : gen newSerialID = _n

	}
	if "`filterVar'" == "" {
		local allIDButCurrID : list allIDs - currID
	}


	* rename variables before reshape so that varname and index are separated by "_"
	if "`filterVar'" != "" {
		rename `currID' `newID'_
	}
	else if "`filterVar'" == "" {

	}
	foreach var of local varsToKeep {
		rename `var' `var'_
		local newVarsToKeep "`newVarsToKeep' `var'_"
	}

	* reshape from long to wide
	if "`filterVar'" != "" {
		reshape wide `newID'_ `newVarsToKeep' , i(`allIDButCurrID') j(newSerialID)
	}
	else if "`filterVar'" == "" {
		reshape wide `newVarsToKeep' , i(`allIDButCurrID') j(`currID')
	}

end
