library(tidyverse)

## Load the dataset ds_salaries
data <- read.csv("dataset/ds_salaries.csv")
head(data)
summary(data)

## get rid of ID column 
data$X <- NULL
head(data)
