library(shiny)
library(igraph)
library(magrittr)
library(visNetwork)
library(data.table)
library(DT)
library(shinydashboard)
library("shinydashboardPlus")
library(shinythemes)

set.seed(5)

## Read table to convert acronyms into names
correspondencias<-read.csv2("Files/Table_Names_And_Acronyms.txt",stringsAsFactors = F,sep="\t")
cancers<-correspondencias[3:24,]
neuros<-correspondencias[1:2,]

## The app will have two tabs, one for the visualization of the pathways associated to specific diseases,
## another one for the visualizacion of the pathways involved in comorbidity relations
ui <- navbarPage("NDG-cancer comorbidities",theme=shinytheme("yeti"),
                 tabPanel("Pathways in diseases",
                          sidebarLayout(
                            sidebarPanel(
                              width = 2,
                              ## Add buttons with options:
                              ## Select the disease of interest
                              selectInput("ndgs","Select a disease:",choices = correspondencias[,1]),
                              ## Select the category of pathways
                              selectInput("category","Select a category",choices = c("HallMarks","Gene Ontology","Canonical Pathways")),
                              ## Select the FDR threshold, ranging from 0 to 1, starting fixed at 0.05
                              sliderInput("fdr","Select a FDR threshold:", min=0, max=1, value=0.05),
                              ## Select the NES threshold, in absolute terms from 0 to 4
                              sliderInput("nes","Select the Normalized Effect Size (NES) threshold:", min=0, max=4, value=0),
                              ## Select the number of genes a pathways must have to be displayed
                              sliderInput("size","Select the minimum number of genes:", min=0, max=200, value=0)
                            ),
                            mainPanel(
                              width=10,
                              fluidRow(
                                ## Represent the table with the results
                                DTOutput("dt_table",width='95%'),
                                align="center"
                              )
                            )
                          )
                 ),
                 tabPanel("Pathways in comorbidities",
                          sidebarLayout(
                            sidebarPanel(
                              width = 0
                            ),
                            mainPanel(
                              width=12,
                              fluidRow(
                                ## Represent the network with the comorbidity interactions
                                box(visNetworkOutput("net_plot", height = "500px"),width=8),
                                ## Add a "Documentation text"
                                box(h3("Documentation:"),
                                    textOutput('textneuro'),
                                    tags$head(tags$style("#textneuro{color: #DFA64F}")),
                                    textOutput('textcancer'),
                                    tags$head(tags$style("#textcancer{color: #8D99D0}")),
                                    textOutput('textd'),
                                    tags$head(tags$style("#textd{color: #D54F4F}")),
                                    textOutput('texti'),
                                    tags$head(tags$style("#texti{color: #3C58A8}")),
                                    textOutput('textnodes'),
                                    width=4,align="left"),
                                DTOutput("net_dt_table",width='95%'),
                                align="center"
                              )
                            )
                          )
                 )
)

server <- function(input, output) {
  ## Section 1 ##
  ## @@ @ @ @@ ##
  # Table ##
  output$dt_table <- renderDT({
    ## Read the table
    df <- read.csv(paste(input$category,"/",correspondencias[which(correspondencias[,1]==input$ndgs),2],".txt",sep=""),stringsAsFactors = F,sep="\t",header=T)
    ## Filter by FDR
    df<- df[which(abs(as.numeric(df$padj))<=input$fdr),]
    ## Filter by NES
    df <- df[which(abs(as.numeric(df$NES))>input$nes),]
    ## Filter by size
    df <- df[which(as.numeric(df$size)>input$size),]
    df<-df[,1:4]
    ## Display the table
    df
  })
  ## Section 2 ##
  ## @@ @ @ @@ ##
  # Network ##
  output$net_plot <- renderVisNetwork({
    ## Read network and node information
    df <- read.csv("Files/Network.txt",stringsAsFactors = F,sep="\t",header=T)
    nodetab<-read.csv("Files/Nodes.txt",stringsAsFactors = F,sep="\t",header=T)
    nodecolor<-nodetab[,2] ; names(nodecolor)<-nodetab[,1]
    ## Read the graph and add colors and weights to the edges and nodes
    graph <- graph_from_data_frame(df, directed=FALSE)
    E(graph)$color<-df$interaction
    E(graph)$weight <- df$size
    V(graph)$color<-as.character(nodecolor[names(V(graph))])
    nodes <- data.frame(id = V(graph)$name, title = V(graph)$name, color = V(graph)$color)
    nodes <- nodes[order(nodes$id, decreasing = F),]
    edges <- get.data.frame(graph, what="edges")[1:4]
    colnames(edges)[4]<-"value"
    colnames(edges)[3]<-"color"
    ## Display the network
    visNetwork(nodes, edges) %>%
      visExport() %>%
      visOptions(highlightNearest = list(enabled=TRUE, degree=1,algorithm="hierarchical",labelOnly=FALSE),
                 nodesIdSelection = list(enabled=TRUE,style="width: 300px; height: 26px",main="Select a disease")) %>%
      visIgraphLayout() %>%
      visInteraction(multiselect = T) %>%
      visEvents(select = "function(nodes) {
                Shiny.onInputChange('current_node_id', nodes.nodes);
                ;}")
  })
  ## Highlight the selected node 
  observeEvent(input$current_node_id, {
    visNetworkProxy("net_plot") %>%
      visGetSelectedNodes()
  })
  ## Documentation text
  output$textneuro <- renderText({"Neurodegenerative disorders are colored in orange"})
  output$textcancer <- renderText({"Cancers are colored in blue"})
  output$texti <- renderText({"Blue edges denote positive interactions (evidence of direct comorbidity)"})
  output$textd <- renderText({"Red edges denote negative interactions (evidence of inverse comorbidity)"})
  output$textnodes<-renderText({"Two diseases are positively connected if a significant overlap between their genes differentially expressed in the same direction is detected. 
    On the other hand, two diseases are negatively connected if a significant overlap is detected between the genes up-regulated in one disease and down-regulated in the other one, and vice versa. 
    Only those pathways de-regulated in the same direction in positively connected diseases (or in opposite directions for negatively connected diseases) are shown."})
  ## Represent the table, which will be update when you select one node, displaying the pathways in the interaction between the selected node and its' neighbours 
  output$net_dt_table <- renderDT({
    df2 <- read.csv("Files/All_comorbidities.txt",stringsAsFactors = F,sep="\t",header=T)
    ## Filter by Category
    if(is.null(input$net_plot_selected) | input$net_plot_selected == ''){
      df2
    }else{
      df3<-read.csv2(paste("Files/",input$net_plot_selected,"_comorbidities.txt",sep=""),stringsAsFactors = F,sep="\t")
      df3
    }
  })
}
shinyApp(ui = ui, server = server)

# To share the library
# library(rsconnect)
# rsconnect::deployApp('/Users/jonsanchezvalle/Desktop/ndg_cancer_comorbidities')



















