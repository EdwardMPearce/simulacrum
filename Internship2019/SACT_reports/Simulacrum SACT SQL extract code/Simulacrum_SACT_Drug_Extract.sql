/* Written by Edward Pearce - 9th September 2019 */
/* Based on work by Bukky Juwa - 17th Jan 2019 */

/* This creates the Drug level SAS extract from Simulacrum datasets (simulated SACT and AV tables) */

/* User Instructions */
/* 1. Set the extract start date in the Extract_Dates table below - to be regularly updated when producing new extracts/snapshots of the datasets */
/* 2. Run the code as a procedure or copy and paste directly into SQL Developer (or your favourite SQL IDE) */

/* Code Explanation */
/* The code is split up into two sections: */
/* In Part One, the 'Derived_Regimen_Fields' table is introduced to define some intermediate variables */
/* In Part Two, the table 'SIM_SACT_DrugLevel' is defined, joining various Simulacrum data sources and constructing several derived fields */
/* The 'SIM_SACT_DrugLevel' table is constrained according to the user-input extract start date from the Extract_Dates table */

/* **************************************** Part One **************************************** */

WITH
/* Change this date at your leisure/when creating a new monthly update */
/* Note: Version 1 of the Simulacrum is based on legacy SACT tables and will only require updating with new versions */
/* We report the following extract sizes (number of rows) for given extract start dates when running the code on Simulacrum Version 1 (SIM_SACT_X_FINAL tables): */
/* Extract_Start = 01-04-2018 returns 4,314 rows; Extract_Start = 01-04-2017 returns 79,080 rows; Extract_Start = 01-01-2013 returns 4,095,738 rows */
/* We report the following extract sizes (number of rows) for given extract start dates when running the code on Simulacrum Version 2 (SIM_SACT_X_SimII tables): */
/* Extract_Start = 01-04-2017 returns 2,469,696 rows; */
Extract_Dates AS
(SELECT 
	TO_DATE('01-04-2017','DD-MM-YYYY') AS Extract_Start
FROM DUAL), 


Derived_Regimen_Fields AS
(SELECT
	SIM_SACT_C.Merged_Regimen_ID AS Merged_Regimen_ID,
/*  The Simulacrum currently does NOT contain the field 'Adult_Perf_Stat_Start_of_Reg' */
/*  An estimate is generated using the earliest Perf_Status_Start_of_Cycle in a regimen */
	MAX(SIM_SACT_C.Perf_Status_Start_of_Cycle) KEEP (DENSE_RANK FIRST ORDER BY SIM_SACT_C.Start_Date_of_Cycle, SIM_SACT_C.Merged_Cycle_ID) AS Perf_Status_Start_of_Reg,
/*  The Simulacrum currently does NOT contain the tumour-level field 'Organisation_Code_of_Provider' (initiating treatment) */
/*  We obtain estimates for the 'Provider' and 'Trust' (initiating treatment) fields using the drug-level field 'Org_Code_of_Drug_Provider' with the earliest 'Administration_Date' in the regimen */
/*  This means that the 'Provider/Trust that initiated treatment' may change between regimens for the same Merged_Tumour_ID where they would not in the real SACT data */
	MAX(SIM_SACT_D.Org_Code_of_Drug_Provider) KEEP (DENSE_RANK FIRST ORDER BY SIM_SACT_D.Administration_Date, SIM_SACT_D.Merged_Drug_Detail_ID) AS Provider,
	MAX(SUBSTR(SIM_SACT_D.Org_Code_of_Drug_Provider, 1, 3)) KEEP (DENSE_RANK FIRST ORDER BY SIM_SACT_D.Administration_Date, SIM_SACT_D.Merged_Drug_Detail_ID) AS Trust
FROM ANALYSISPAULCLARKE.SIM_SACT_CYCLE_SimII SIM_SACT_C
LEFT JOIN ANALYSISPAULCLARKE.SIM_SACT_DRUG_DETAIL_SimII SIM_SACT_D
ON SIM_SACT_D.Merged_Cycle_ID = SIM_SACT_C.Merged_Cycle_ID
GROUP BY SIM_SACT_C.Merged_Regimen_ID),

/* **************************************** Part Two **************************************** */

SIM_SACT_DrugLevel AS
(SELECT
/*  Patient-level fields */
	SIM_SACT_P.Merged_Patient_ID AS Merged_Patient_ID,

/*  Tumour-level fields */
	SIM_SACT_T.Merged_Tumour_ID AS Merged_Tumour_ID, 
	SIM_SACT_T.Primary_Diagnosis AS Primary_Diagnosis,
/*  The field 'GroupDescription2' is derived from Primary Diagnosis using the Diagnosis Subgroup lookup */	
	DSG.Group_Description2 AS Group_Description2,

/*  The Simulacrum currently does NOT contain the tumour-level field 'Organisation_Code_of_Provider' (initiating treatment) */
/*  We obtain estimates for the 'Provider' and 'Trust' (initiating treatment) fields using the drug-level field 'Org_Code_of_Drug_Provider' with the earliest 'Administration_Date' in the regimen */
/*  This means that the 'Provider/Trust that initiated treatment' may change between regimens for the same Merged_Tumour_ID where they would not in the real SACT data */
    R1.Provider AS Provider,
    R1.Trust as Trust,
/*  The Simulacrum currently does NOT contain the tumour-level field 'Consultant_gmc_code' */
/*  Consultant_gmc_code is used to derive 'Consultant_Code_Name' */	
/*  Therefore the field 'Consultant_Code_Name' cannot be extracted from the Simulacrum */

/*  Regimen-level fields */
    SIM_SACT_R.Merged_Regimen_ID AS Merged_Regimen_ID,
	TO_CHAR(SIM_SACT_R.Start_Date_of_Regimen, 'MON/YYYY') AS Start_Month_of_Regimen,
/*  The AgeGroup field defined below is based on age at regimen start date, whilst the Age field in SIM_AV_TUMOUR denotes age at diagnosis */
/*  Therefore we add the difference in time between DiagnosisDateBest and Start_Date_of_Regimen to calculate age at regimen start date */
	CASE
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 0 AND 15 THEN '0-15'
    WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 16 AND 18 THEN '16-18' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 19 AND 24 THEN '19-24'			
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 25 AND 29 THEN '25-29'			 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 30 AND 34 THEN '30-34' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 35 AND 39 THEN '35-39' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 40 AND 44 THEN '40-44' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 45 AND 49 THEN '45-49' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 50 AND 54 THEN '50-54' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 55 AND 59 THEN '55-59' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 60 AND 64 THEN '60-64' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 65 AND 69 THEN '65-69' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 70 AND 74 THEN '70-74' 
	WHEN TRUNC(SIM_AV_T.Age + (MONTHS_BETWEEN(SIM_SACT_R.Start_Date_of_Regimen, SIM_AV_T.DiagnosisDateBest)/12)) BETWEEN 75 AND 79 THEN '75-79' 
	ELSE '80+' END AS AgeGroup,		
	SIM_SACT_R.Intent_of_Treatment AS Intent_of_Treatment,
/*  The Simulacrum currently does NOT contain the field 'Adult_Perf_Stat_Start_of_Reg' */
/*  An estimate is generated using the first Perf_Status_Start_of_Cycle in a regimen */
    R1.Perf_Status_Start_of_Reg AS Perf_Status_Start_of_Reg,
    SIM_SACT_R.Mapped_Regimen AS Mapped_Regimen,
/*  The fields 'Benchmark' and 'Analysis' are derived from MappedRegimen using the Benchmark Analysis Lookup */	
    BAL.Benchmark as Benchmark,
    BAL.Analysis as Analysis,
	
/*  Cycle-level fields */	
    SIM_SACT_C.Merged_Cycle_ID AS Merged_Cycle_ID,
    TO_CHAR(SIM_SACT_C.Start_Date_of_Cycle, 'MON/YYYY') as Start_Month_of_Cycle,
    SIM_SACT_C.Start_Date_of_Cycle as Start_Date_of_Cycle_Full,
/*  This field 'Perf_Status_Start_of_Cycle' has a different name to 'Perf_Stat_Start_of_Cycle_Adult' */
    SIM_SACT_C.Perf_Status_Start_of_Cycle AS Perf_Status_Start_of_Cycle,
/*  The Simulacrum currently does NOT contain the field 'Weight_at_Start_of_Cycle' */
/*  Therefore the fields 'Weight_at_Start_of_Cycle' and 'Weight_Cycle_Completeness' cannot be extracted from the Simulacrum */

/*  Drug-level fields */	
    SIM_SACT_D.Merged_Drug_Detail_ID AS Merged_Drug_Detail_ID,
    TO_CHAR(SIM_SACT_D.Administration_Date, 'MON/YYYY') as Administration_Month,
	TO_CHAR(SIM_SACT_D.Administration_Date, 'DAY') as Weekday,
    SIM_SACT_D.Administration_Route AS Administration_Route,
/*  The Simulacrum currently does NOT contain the field 'Drug_Name', but does contain 'Drug_Group' */
    SIM_SACT_D.Drug_Group AS Drug_Group,
    SIM_SACT_D.Org_Code_of_Drug_Provider AS Org_Code_of_Drug_Provider,
    SUBSTR(SIM_SACT_D.Org_Code_of_Drug_Provider, 1, 3) as Trust_of_Drug_Provider,
/*  Exclusions - A field primarily based on regimen-level field Mapped_Regimen, though the E5 sometimes also depends on tumour-level field Primary_Diagnosis */
/*  The CDF exclusions depend not only on the type of treatment, but also the tumour being treated and treatment dates */
/*  Note: An exclusions lookup table for all types of exclusions may be useful in the future */
    CASE
    WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) = 'NOT CHEMO' OR UPPER(BAL.Benchmark) = 'NOT CHEMO') THEN 'E1'
    WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) IN ('PAMIDRONATE','ZOLEDRONIC ACID') OR UPPER(BAL.Benchmark) IN ('PAMIDRONATE','ZOLEDRONIC ACID')) THEN 'E2'
    WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) = 'DENOSUMAB' OR UPPER(BAL.Benchmark) = 'DENOSUMAB') THEN 'E3'	
    WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) = 'HORMONES' OR UPPER(BAL.Benchmark) = 'HORMONES') THEN 'E4'
    WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) IN ('BCG INTRAVESICAL','MITOMYCIN INTRAVESICAL','EPIRUBICIN INTRAVESICAL'))
      OR (UPPER(SIM_SACT_R.Mapped_Regimen) IN ('MITOMYCIN', 'EPIRUBICIN') AND (SIM_SACT_T.Primary_Diagnosis LIKE 'C67%' OR SIM_SACT_T.Primary_Diagnosis LIKE 'D41%')) THEN 'E5'														
	WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) LIKE '%TRIAL%' OR UPPER(BAL.Benchmark) LIKE '%TRIAL%') THEN 'E6'
    WHEN (UPPER(SIM_SACT_R.Mapped_Regimen) = 'NOT MATCHED' OR UPPER(BAL.Benchmark) = 'NOT MATCHED') THEN 'E7'
/*  CDF Exclusions (coded as 'E8' exclusions) are currently excluded from this extract since they will require extra work to be derived from Simulacrum data */
	ELSE SIM_SACT_R.Mapped_Regimen END
	AS Exclusion
FROM 
/*  SIM_SACT_P is used only as a link between SIM_SACT tables and SIM_AV tables to derive regimen-level field 'AgeGroup' (at regimen start date) */
ANALYSISPAULCLARKE.SIM_SACT_PATIENT_SimII SIM_SACT_P
INNER JOIN ANALYSISPAULCLARKE.SIM_SACT_TUMOUR_SimII SIM_SACT_T
ON SIM_SACT_T.Merged_Patient_ID = SIM_SACT_P.Merged_Patient_ID
INNER JOIN ANALYSISPAULCLARKE.SIM_SACT_REGIMEN_SimII SIM_SACT_R
ON SIM_SACT_R.Merged_Tumour_ID = SIM_SACT_T.Merged_Tumour_ID
INNER JOIN ANALYSISPAULCLARKE.SIM_SACT_CYCLE_SimII SIM_SACT_C
ON SIM_SACT_C.Merged_Regimen_ID = SIM_SACT_R.Merged_Regimen_ID
LEFT JOIN ANALYSISPAULCLARKE.SIM_SACT_DRUG_DETAIL_SimII SIM_SACT_D
ON SIM_SACT_D.Merged_Cycle_ID = SIM_SACT_C.Merged_Cycle_ID
/*  Used to derive regimen-level field 'AgeGroup' (at regimen start date) */
LEFT JOIN ANALYSISPAULCLARKE.SIM_AV_TUMOUR_SimII SIM_AV_T
ON SIM_AV_T.LinkNumber = SIM_SACT_P.Link_Number
/*  Used to derive tumour-level field 'GroupDescription2' */
LEFT JOIN ANALYSISBUKKYJUWA.DIAGNOSIS_SUBGROUP_SACT DSG
ON DSG.ICD_Code = SIM_SACT_T.Primary_Diagnosis
/*  Used to derive regimen-level fields 'Benchmark' and 'Analysis' */
LEFT JOIN ANALYSISBUKKYJUWA.BENCHMARK_ANALYSIS_LOOKUP_NEW BAL
ON BAL.Mapped_Regimen = SIM_SACT_R.Mapped_Regimen
/*  Used to derive 'tumour-level' fields 'Provider' and 'Trust' and regimen-level field 'Adult_Perf_Stat_Start_of_Reg' */
LEFT JOIN Derived_Regimen_Fields R1
ON R1.Merged_Regimen_ID = SIM_SACT_R.Merged_Regimen_ID, 
Extract_dates
WHERE (SIM_SACT_R.Start_Date_of_Regimen >= Extract_Start OR SIM_SACT_C.Start_Date_of_Cycle >= Extract_Start OR SIM_SACT_D.Administration_Date >= Extract_Start))

SELECT * FROM SIM_SACT_DrugLevel;