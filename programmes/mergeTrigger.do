
capture program drop mergeTrigger
program define mergeTrigger
syntax , 							///
	rosterTrigger(string)			/// stub name of roster tigger question, as it appears in Designer, without "__"
	triggerType(string)				/// type: list, multi-select-yn, multi-select-ordered
	dataDir(string)					///
	mainFile(string)			/// file where roster trigger found--full path, with .dta extension
	rosterFile(string)			/// file with target roster--full path, with .dta extension
	[ newColName(string) ]			/// new roster ID in target file
	[ saveDir(string) ]				/// where created file should be stored
	[ newRosterID(string) ]			///

	* check that trigger type is valid
	capture assert inlist("`triggerType'", "list", "multi-select", "multi-select-yn", "multi-select-ordered")
	if _rc != 0 {
		di as error "Invalid roster type entered. Use one of the following: list, multi-select"
		error 1
	}

	* check that main file exists
	capture confirm file "`dataDir'/`mainFile'.dta"
	if _rc != 0 {
		di as error "Main file not found at indicated location. Please confirm the file location"
		error 1
	}

	* check that roster file exists
	capture confirm file "`dataDir'/`rosterFile'.dta"
	if _rc != 0 {
		di as error "Roster file not found at indicated location. Please confirm the file location"
		error 1
	}

	* load main file
	use "`dataDir'/`mainFile'.dta", clear

	* check that variables with this stub exist
	qui: d `rosterTrigger'*, varlist
	local varsFound = r(varlist)
	local numVarsFound : list sizeof varsFound
	if `numVarsFound' == 0 {
		di as error "No variables found with stub `rosterTrigger'"
		error 1
	}

	use "`dataDir'/`mainFile'.dta", clear
	keep interview__id `rosterTrigger'*
	if "`triggerType'" == "list" {	
		drop if `rosterTrigger'__0 == ""
	}
	qui: d `rosterTrigger'*, varlist
	local vars = r(varlist)
	local vars = subinstr("`vars'", "`rosterTrigger'__autre", "", .)
	local numVars : list sizeof vars

	if "`rosterType'" == "list" {		
		forvalues i = `numVars'(-1)1 {

			local j = `i' - 1
			di "i: `i'"
			di "j: `j'"
			di ""
			rename `rosterTrigger'__`j' `rosterTrigger'__`i'

		}
	}

	* transform trigger into long format
	qui: reshape long `rosterTrigger'__, i(interview__id) j(`rosterFile'__id)

	rename `rosterTrigger'__ `rosterTrigger'

	if "`triggerType'" == "multi-select-yn" {
		recode `rosterTrigger' (0 = 2)
	}

	* remove all value labels from main file
	label drop _all

	* merge trigger and roster
	qui: merge 1:1 interview__id `rosterFile'__id using "`dataDir'/`rosterFile'.dta", nogen

	* label value labels of trigger
	if "`triggerType'" == "multi-select-yn" {
		label define `rosterTrigger' 1 "Oui" 2 "Non"
		label values `rosterTrigger' `rosterTrigger'
	}	

	* rename roster ID
	if "`newRosterID'" != "" {
		rename `rosterFile'__id `newRosterID'
	}

	* apply ID variable labels from roster file, removed during merge
	if "`newRosterID'" == "" {
		label values `rosterFile'__id `rosterFile'__id
	}
	else if "`newRosterID'" != "" {
		label values `newRosterID' `rosterFile'__id
	}

	if "`saveDir'" != "" {
		save "`saveDir'/`rosterFile'.dta", replace
	}

end

/*
local dataDir "C:\Users\Arthur\Desktop\UEMOA\data-cleaning\data/" 
local resourceDir "C:\Users\Arthur\Desktop\UEMOA\data-cleaning\ressources"

mergeTrigger, 										///
	rosterTrigger(s09Bq02) 							///
	triggerType("multi-select") 					///
	dataDir("`dataDir'")							///
	mainFile("Qx_MENAGE_EHCVM_TG1") 				///
	rosterFile("depense_7j")
*/
