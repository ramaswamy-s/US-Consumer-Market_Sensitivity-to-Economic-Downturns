#################################### FRAMEWORK TO ANALYZE CONSUMER SPENDING PATTERN ACROSS DIFFERENT INCOME BUCKETS #######################################

######################################## Created by Ram Subramanian, Data Analyst Intern, The Conference Board ############################################### 
############################################################### Dated Apr 23, 2020 ######################################################################

##### INPUT FILES:
# 1. Diary Survey for the given year
# 2. Interview Survey for the given year
# 3. Reference File for Survey Codes by Product Category (ce_source_integrate_mod.xlsx -- First few rows with File Title & Summary removed)

##### OUTPUT FILE:
# 1. Excel Sheet with the Weighted Average Spending and Participation Rates grouped by each Product Category across different Income Buckets



###################################################### STEP 1: LOAD LIBRARIES ##########################################################################

library(ggplot2)
library(dplyr)
library(tidyr)
library(sqldf)
library(bit64)
library(xlsx)
library(scales)
library(openxlsx)

################################################### STEP 2: IMPORT INPUT FILES #######################################################################


setwd('C:/myfiles/TCB/') # Set Working Directory and make sure the input files are placed there

# Import Diary and interview Survey for the Year of interest (e.g. Diary 2018 and Interview 2018 data)
diary2018 = read.csv('diary_2018.csv')
intrvw2018 = read.csv('intrvw_2018.csv')

# Load the Reference sheet with Survey Codes
ce_source_integrate_mod = read.xlsx('ce_source_integrate_mod.xlsx') 


################################################### STEP 3: RUN THE USER-DEFINED FUNCTIONS ###########################################################



#*******************************************   FUNCTION TO CORRECT DECIMAL PLACES ******************************************  

specify_decimal <-
  function(x, k)
    trimws(format(round(x, k), nsmall = k))


#******************************  FUNCTION TO GROUP INTO INCOME BUCKETS USING INCOME DECILES  ****************************** 

income_decile <-
  function (df)
    quantile(df$INCOME, prob = seq(0, 1, length = 11), type = 5)


#************* FUNCTION TO PASS THE DIARY SURVEY DATAFRAME AND OBTAIN WEIGHTED AVERAGE SPENDING & PARTICIPATION RATE AGGREGATED BY PRODUCT CATEGORY & INCOME BUCKETS  *********


DiarySurveyFn <- function(df) {
  DiaryDataAgg = df[c("ID", "UCC", "COST", "FINLWT21", "INCOME")] # Subsetting to Key attributes required for data aggregation
  DiaryDataAgg$ID <-
    as.integer64(DiaryDataAgg$ID)  # Storing HouseHold ID as 64-bit integers to avoid exponential notation
  
  # Create variable for Expense participation to determine if there was spending by a Household on a specific Product or not
  DiaryDataAgg$Participn_Ind <- ifelse(DiaryDataAgg$COST > 0, 1, 0)
  DiaryDataAgg$Wt_Participn_Prdt <-
    DiaryDataAgg$Participn_Ind * DiaryDataAgg$FINLWT21 # Product of Weight & Participation Indicator
  
  
  DiaryDataAgg$WtCostPrdt = DiaryDataAgg$COST * DiaryDataAgg$FINLWT21 # Creating attribute "WtCostPrdt" for Product of Weight and Spending (Cost)
  
  #Feature engineering for Income Category: add a new column income_category to categorize the income by Income deciles
  DiaryDataAgg$income_category <- with(DiaryDataAgg, factor(
    findInterval(INCOME, c(-Inf,
                           quantile(
                             INCOME, probs = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)
                           ), Inf)),
    labels = c(
      "income level 1",
      "income level 2",
      "income level 3",
      "income level 4",
      "income level 5",
      "income level 6",
      "income level 7",
      "income level 8",
      "income level 9",
      "income level 10"
    )
  ))
  # Categorizing zero income or below under the lowest income category
  DiaryDataAgg$income_category[DiaryDataAgg$INCOME <= "0"] <-
    "income level 1"
  
  # Weighted Average Spending at Product Category Level across different Income Buckets
  WtCostPrdt_avg_Income_UCC_D <- DiaryDataAgg %>%
    group_by(income_category, UCC) %>%
    dplyr::summarize(WtCostPrdt_avg_D = (sum(WtCostPrdt) /
                                           sum(FINLWT21)))
  
  # Participation Rate at Product Category Level across different Income Buckets
  PR_avg_Income_UCC_D <- DiaryDataAgg %>%
    group_by(income_category, UCC) %>%
    dplyr::summarize(PR_UCC_D = (sum(Wt_Participn_Prdt) /
                                   sum(FINLWT21)))
  
  # Correct Decimals
  WtCostPrdt_avg_Income_UCC_D$WtCostPrdt_avg_D <-
    specify_decimal(WtCostPrdt_avg_Income_UCC_D$WtCostPrdt_avg_D, 2)
  PR_avg_Income_UCC_D$PR_UCC_D <-
    percent(as.numeric(specify_decimal(PR_avg_Income_UCC_D$PR_UCC_D, 4)), accuracy =
              0.01)
  
  # Merge Weighted Spending and Participation Rate data by Product Category x Income Category combination
  Income_UCC_WtdSpending_PR_D <-
    merge(WtCostPrdt_avg_Income_UCC_D,
          PR_avg_Income_UCC_D,
          by = c("UCC", "income_category"))
  return(Income_UCC_WtdSpending_PR_D)
}


#************  FUNCTION TO PASS THE INTERVIEW SURVEY DATAFRAME AND OBTAIN WEIGHTED AVERAGE SPENDING & PARTICIPATION RATE AGGREGATED BY PRODUCT CATEGORY & INCOME BUCKETS  ************

IntrvwSurveyFn <- function(df) {
  IntrvwDataAgg = df[c("NEWID", "UCC", "COST", "FINLWT21_CAL", "INCOME")] # Subsetting to Key attributes required for data aggregation
  IntrvwDataAgg$NEWID <-
    as.integer64(IntrvwDataAgg$NEWID)  # Storing HouseHold ID as 64-bit integers to avoid exponential notation
  
  # Create variable for Expense participation to determine if there was spending by a Household on a specific Product or not
  IntrvwDataAgg$Participn_Ind <- ifelse(IntrvwDataAgg$COST > 0, 1, 0)
  IntrvwDataAgg$Wt_Participn_Prdt <-
    IntrvwDataAgg$Participn_Ind * IntrvwDataAgg$FINLWT21_CAL # Product of Weight & Participation Indicator

  
  # Feature engineering for Income Category: add a new column income_category to categorize the income by Income deciles
  IntrvwDataAgg$income_category <- with(IntrvwDataAgg, factor(
    findInterval(INCOME, c(-Inf,
                           quantile(
                             INCOME, probs = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)
                           ), Inf)),
    labels = c(
      "income level 1",
      "income level 2",
      "income level 3",
      "income level 4",
      "income level 5",
      "income level 6",
      "income level 7",
      "income level 8",
      "income level 9",
      "income level 10"
    )
  ))
  # Categorizing zero income or below under the lowest income category
  IntrvwDataAgg$income_category[IntrvwDataAgg$INCOME <= "0"] <-
    "income level 1"
  
  # Creating attribute "WtCostPrdt" for Product of Weight and Spending (Cost)
  IntrvwDataAgg$WtCostPrdt = IntrvwDataAgg$COST * IntrvwDataAgg$FINLWT21_CAL
  
  # Weighted Avg Spending at Product Category Level across different Income Buckets
  WtCostPrdt_avg_Income_UCC_I <- IntrvwDataAgg %>%
    group_by(income_category, UCC) %>%
    dplyr::summarize(WtCostPrdt_avg_I = (sum(WtCostPrdt) /
                                           sum(FINLWT21_CAL)))
  
  # Participation Rate at Product Category Level across different Income Buckets
    PR_avg_Income_UCC_I <- IntrvwDataAgg %>%
    group_by(income_category, UCC) %>%
    dplyr::summarize(PR_UCC_I = (sum(Wt_Participn_Prdt) /
                                   sum(FINLWT21_CAL)))
  
  # Correct Decimals
  WtCostPrdt_avg_Income_UCC_I$WtCostPrdt_avg_I <-
    specify_decimal(WtCostPrdt_avg_Income_UCC_I$WtCostPrdt_avg_I, 2)
  PR_avg_Income_UCC_I$PR_UCC_I <-
    percent(as.numeric(specify_decimal(PR_avg_Income_UCC_I$PR_UCC_I, 4)), accuracy =
              0.01)
  
  # Merge Weighted Spending and Participation Rate data by Product Category x Income Category combination
  Income_UCC_WtdSpending_PR_I <-
    merge(WtCostPrdt_avg_Income_UCC_I,
          PR_avg_Income_UCC_I,
          by = c("UCC", "income_category"))
  
  return(Income_UCC_WtdSpending_PR_I)
  
}
########################### STEP 4: AGGREGATION OF DIARY AND INTERVIEW SURVEY DATA & MERGING THEM INTO ONE COMBINED SURVEY DATAFRAME #####################################################

# Aggregate Diary Survey data as required
DiarySurveyAgg2018 = DiarySurveyFn(diary2018) 
View(DiarySurveyAgg2018)
# View Income Deciles from Diary Survey
income_decile(diary2018) #Pls note that income_decile function is written such that any income <= 0 always goes into the lowest income bucket - income level 1, no matter how the deciles are distributed

# Aggregate Interview Survey data as required
IntrvwSurveyAgg2018 = IntrvwSurveyFn(intrvw2018)
View(IntrvwSurveyAgg2018)
# View Income Deciles from Interview Survey
income_decile(intrvw2018)#Pls note that income_decile function is written such that any income <= 0 always goes into the lowest income bucket - income level 1, no matter how the deciles are distributed

# Returns all rows from both Dataframes (Aggregated Diary Survey data and Aggregated Interview Survey data), join records from the left which have matching Product Category X Income Category combinations in the right table (Outer Join).

CombinedSurveyAgg2018 <-
  merge(
    x = DiarySurveyAgg2018,
    y = IntrvwSurveyAgg2018,
    by = c("UCC", "income_category"),
    all = TRUE
  )
View(CombinedSurveyAgg2018)

##################################### STEP 5: MERGE COMBINED SURVEY DATA WITH SURVEY CODE REFERENCE FILE ############################################

# NOTE: This step is necessary to select Weighted Average Spending and Participation Rate data for each of the Product Category from either of the respective Diary or Interview Survey values by using Survey Code Reference File
# Variable y18 will need to be changed in the subsequent coding lines under STEP 5 depending on the year you want (e.g. we have used y18 for 2018)

# Confine ce_source_integrate_mod dataframe (Survey Code Reference File) to just the key attributes - Product Description, Product Code and Survey Codes for the year of interest

ce_source_integrate_mod <-
  ce_source_integrate_mod[!(ce_source_integrate_mod$y18 == "G" |
                              is.na(ce_source_integrate_mod$y18)), c("Description", "UCC", "y18")] 
View(ce_source_integrate_mod)


# Merge the Survey Code Reference File with the aggregated results to list the Survey Codes against the Product Categories
CombinedSurveyAgg2018 <-
  merge(CombinedSurveyAgg2018, ce_source_integrate_mod, by = "UCC")

# Assign the corresponding Weighted Average Spending and the Participation Rate to the Product Categories based on the respective Survey Codes
CombinedSurveyAgg2018$WtCostPrdt_avg_final <-
  ifelse(
    CombinedSurveyAgg2018$y18 == "D",
    CombinedSurveyAgg2018$WtCostPrdt_avg_D,
    CombinedSurveyAgg2018$WtCostPrdt_avg_I
  )
CombinedSurveyAgg2018$PR_UCC_final <-
  ifelse(
    CombinedSurveyAgg2018$y18 == "D",
    CombinedSurveyAgg2018$PR_UCC_D,
    CombinedSurveyAgg2018$PR_UCC_I
  )


############################################# STEP 6: PIVOT THE COMBINED SURVEY DATAFRAME ########################################################

#DCAST function is used to pivot the table and show the Weighted Average Spending and Participation Rates across different Income Buckets for each Product Category

Agg_UCC_Income_WtdAvgSpending <-
  dcast(CombinedSurveyAgg2018,
        Description + UCC ~ income_category,
        value.var = "WtCostPrdt_avg_final")
View(Agg_UCC_Income_WtdAvgSpending)

Agg_UCC_Income_PR <-
  dcast(CombinedSurveyAgg2018,
        Description + UCC ~ income_category,
        value.var = 'PR_UCC_final')
View(Agg_UCC_Income_PR)

############################################# STEP 7: EXPORT THE OUTPUT INTO EXCEL FILES ########################################################

#Export Diary, Interview and Combined Survey aggregate results to one Excel Book across different Sheets
wb <- createWorkbook()
addWorksheet(wb, "WtdAvgSpending_2018")
addWorksheet(wb, "Participation_rate_2018")
writeData(wb, 1, Agg_UCC_Income_WtdAvgSpending)
writeData(wb, 2, Agg_UCC_Income_PR)
saveWorkbook(wb, file = "Consumer spending_2018.xlsx", overwrite = TRUE)

########################### ############################## ############################## ############################ ########################################################## 
