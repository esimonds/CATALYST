library(CATALYST)
library(shiny)
library(shinydashboard)
library(shinyjs)
library(shinyBS)
library(ggplot2)
library(grid)
library(gridExtra)
library(htmltools)
library(plotly)
library(flowCore)
library(magrittr)
library(DT)

# change background color of textInput
restyleMetals <- "shinyjs.restyleMetal=function(pars){
    $('#'+pars.id).css('background-color',pars.col);}"

# force collapse shinydashboard::box
collapseBox <- "shinyjs.collapse=function(id){
    $('#'+id).closest('.box').not('.collapsed-box')
    .find('[data-widget=collapse]').click();}"

source("helpers.R")

source("module-yieldPlot.R")
source("module-debaPars.R")

source("ui-guides.R")
source("ui-concatenation.R")
source("ui-normalization.R")   
source("ui-FCSchecking.R")
source("ui-compensation.R")
source("ui-debarcoding.R")
