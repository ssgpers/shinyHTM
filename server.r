# ==========================================================================
# Phylosophy: the 'htm' data.frame is placed in the global enviromnent, 
# where it can be accessed and updated by reactive functions
#
# all data columns added by shinyHTM have the prefix 'HTM_'
#
# The list 'UI' keeps track of all UI settings and allows restoring the shinyHTM session
#
# Heatmaps are built from a reactive data.frame 'htmHM()'
#
# ==========================================================================

# To do:
# Sync negative control across Normalize&Summarize
# Update plot symbols each time QC is applied
# Correct the way shiny 'upload files', using a temporary folder (makes it difficult to restore session)
# Streamline the QC GUI
enableBookmarking(store = "url")
source("./functions.r")
loadpackage("shiny")
loadpackage("plotly")
loadpackage("ggplot2")
loadpackage("ggbeeswarm")
loadpackage("tcltk")
loadpackage("openxlsx")
loadpackage("shinyjs")
loadpackage("raster")
loadpackage("shinyalert")


# Adjust maximum upload size to 2 Gb
options(shiny.maxRequestSize=2*1024^3)

col_QC <- "HTM_QC"

widgetnames <- {c("colTreatment", "colBatch", "colWell", "colPos", 
                  "fiji_binary", "images2display", 
                  "pathInTable", "pathInComputer", "prefixPath", "prefixFile",
                  "colObjectPosX", "colObjectPosY", "colObjectPosZ",
                  "wells_Y", "wells_X", "npos_Y", "npos_X", 
                  "squaredodge", "squaresize",
                  
                  "selection", "plotScatterBoxOrHeatmap", "plotType", 
                  "batch", "Xaxis", "Yaxis", 
                  "highlightQCfailed", "PointplotsplitBy", "PointplotfilterColumn", "PointplotfilterValues",
                  "BoxplothighlightCenter", "BoxplotsplitBy", "LUTcolors", "LUTminmax", 
                  
                  "QCfailedExperiment", "QCnumMeasurement", "QCnumMin", "QCnumMax", 
                  "QCtxtMeasurement", "QCtxtBad", "QCcheckGroup", 
                  
                  "NormFeatures", "NormDataTransform", "NormGradientCorr", "NormMethod", "NormNegCtrl", 
                  
                  "SummaryMeasurements", "SummaryNegCtrl", "SummaryPosCtrl", "SummaryNumObjects", 
                  
                  "echo_TreatmentSummary", "TreatmentSummaryTable",
                  
                  "ValuesTable")}


shinyServer(function(input, output, session){

    ################################################################
    # 0. INITIALIZE VARIABLES                                      #
    ################################################################
    if(exists("htm")) rm(htm, inherits = TRUE)
    if(exists("QCsettings")) rm(QCsettings, inherits = TRUE)
    for(i in widgetnames) reset(i)
    
    QCsettings <<- data.frame(type             = character(), 
                              measurement      = character(), 
                              minimum          = character(), 
                              maximum          = character(),
                              failed           = integer(),
                              stringsAsFactors = FALSE)
    
    widgetSettings <- reactiveValues(LUTminmax = c(0,1))
    
    # This variable stores info on the kind of plot to draw
    plotType <- reactiveValues(type="none", subtype="none", XaxisType="none")
    

                               
    
    ################################################################
    # 1. FILE INPUT                                                #
    ################################################################

    observeEvent(input$loadFileType, {
        
        if(input$loadFileType == "Auto"){
            updateRadioButtons(session, "loadDecimalSeparator",
                               label = h4("File format"),
                               choices = list("Auto detect" = "Auto", "Dot (.)" = ".", "Comma (,)" = ","),
                               selected = "Auto"
            )
        }
        
        if(input$loadFileType == "csv"){
            updateRadioButtons(session, "loadDecimalSeparator",
                               label = h4("File format"),
                               choices = list("Comma (.)" = "."),
                               selected = "."
            )
        }
        
        if(input$loadFileType == "tsv"){
            updateRadioButtons(session, "loadDecimalSeparator",
                               label = h4("File format"),
                               choices = list("Auto detect" = "Auto", "Dot (.)" = ".", "Comma (,)" = ","),
                               selected = "Auto"
            )
        }
        
        if(input$loadFileType == "xlsx"){
            updateRadioButtons(session, "loadDecimalSeparator",
                               label = h4("File format"),
                               choices = list("Auto detect" = "Auto"),
                               selected = "Auto"
            )
        }
        
    })
    
    observeEvent(input$file1, {

        # Reset datasets
        if(exists("htm")) rm(htm, inherits = TRUE)

        QCsettings <<- data.frame(type             = character(), 
                                  measurement      = character(), 
                                  minimum          = character(), 
                                  maximum          = character(),
                                  failed           = integer(),
                                  stringsAsFactors = FALSE)


        # Read new dataset
        htm <- read.HTMtable(input$file1$datapath, filetype = input$loadFileType, decimalseparator = input$loadDecimalSeparator)

        # Check if data has been successfully read
        if(is.null(htm)){
            if(input$loadFileType == "Auto"){
                shinyalert("Oops!", "shinyHTM could not read your data file. These are the only file formats supported by shinyHTM: 'csv', 'txt', 'tsv' and 'xlsx'.", type = "error")
            } else{
                shinyalert("Oops!", paste0("shinyHTM could not read your data file. Please check whether the file format is '", input$loadFileType, "', as specified in the load options."), type = "error")
            }
            
        } else if(nrow(htm) == 0){
            shinyalert("Oops!", "It seems like your data file has no data.", type = "warning")
        } else{
            htm[[col_QC]] <- TRUE
            htm <<- htm 
        }

        
        # Reset widgets to their original values
        for(i in widgetnames){
            reset(i)
        }
        
    })

    
    ################################################################
    # 2. SETTINGS                                                  #
    ################################################################
    output$UIcolNameTreatment        <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL

        selectInput("colTreatment", "Treatment:", mychoices, width = "100%")
    })
    output$UIcolNameBatch            <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        selectInput("colBatch", "Batch:", mychoices, width = "100%")
    })
    output$UIcolNameWell             <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        selectInput("colWell", "Well coordinate:", mychoices, width = "100%")
    })
    output$UIcolNamePos              <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        selectInput("colPos", "Sub-position coordinate:", mychoices, width = "100%")
    })
    output$UIpathInTable             <- renderUI({
        textInput("pathInTable", "Image root folder name in table", "c:\\tutorial\\myplate_01", width = "100%")
    })
    output$UIpathInComputer          <- renderUI({
        textInput("pathInComputer", "Image root folder name in this computer", "c:\\myplate_01", width = "100%")
    })
    output$UIprefixPath              <- renderUI({
        textInput("prefixPath", "Prefix: column with folder name", "PathName_")
    })
    output$UIprefixFile              <- renderUI({
        textInput("prefixFile", "Prefix: column with file name", "FileName_")
    })
    output$UIcolNameObjectPosX       <- renderUI({
      input$file1
      input$applyNorm
      
      mychoices  <- if (exists("htm")) as.list( c("NA", names(htm))) else NULL
      myselected <- if (exists("htm")) getObjectPositionColumn( names(htm), "X") else NULL
      
      selectInput("colObjectPosX", "Object's x-position:", mychoices, selected = myselected, width = "100%")
    })

    output$UIcolNameObjectPosY       <- renderUI({
      input$file1
      input$applyNorm
      
      mychoices  <- if (exists("htm")) as.list( c("NA", names(htm))) else NULL
      myselected <- if (exists("htm")) getObjectPositionColumn( names(htm), "Y") else NULL
      
      selectInput("colObjectPosY", "Object's y-position:", mychoices, selected = myselected, width = "100%")
    })
	
    output$UIcolNameObjectPosZ       <- renderUI({
      input$file1
      input$applyNorm
      
      mychoices  <- if (exists("htm")) as.list( c("NA", names(htm))) else NULL
      myselected <- if (exists("htm")) getObjectPositionColumn( names(htm), "Z") else NULL
      
      selectInput("colObjectPosZ", "Object's z-position:", mychoices, selected = myselected, width = "100%")
    })
    output$UIwells_Y                 <- renderUI({
        numericInput("wells_Y", "Number of Rows", 16)
    })
    output$UIwells_X                 <- renderUI({
        numericInput("wells_X", "Number of Columns", 24)
    })
    output$UInpos_Y                  <- renderUI({
        numericInput("npos_Y", "Number of subposition Rows", 2)
    })
    output$UInpos_X                  <- renderUI({
        numericInput("npos_X", "Number of subposition Columns", 2)
    })
    output$UIsquaredodge             <- renderUI({
        sliderInput("squaredodge", "Separation between positions", min=0, max=0.5, value=0.2, step=0.1)
    })
    output$UIsquaresize              <- renderUI({
        sliderInput("squaresize", "Square size", min=0.5, max=5, value=1, step=0.5)
    })

    
    
    
    
    
    
    
    
    
    output$UIfiji_path        <- renderUI({
        
        if (Sys.info()['sysname'] == "Windows")
        {
            fiji_binary_path = "C:/Fiji.app/ImageJ-win64.exe"
        } 
        else 
        {
            fiji_binary_path = "/Applications/Fiji.app/Contents/MacOS/ImageJ-macosx"
        }

        textInput("fiji_binary", "Path to Fiji ", value = fiji_binary_path, width = "100%")
    
    })
    
    output$UIavailableimages  <- renderUI({
        input$file1
        
        if(exists("htm")){
            img_names <- gsub(paste0("^", input$prefixPath, "(.*)"), "\\1", names(htm)[grep(paste0("^", input$prefixPath), names(htm))])
        } else{
            img_names <- NULL
        }
        
        checkboxGroupInput("images2display", "Select images to be viewed upon clicking within a plot", as.list(img_names), width = "100%")
    })
    
    
    
    ################################################################
    # 3. PLOTTING                                                  #
    ################################################################
    
    # Determine the kind of plot to draw #1: auto-detect plot type
    observeEvent(c(input$file1, input$plotType, input$Xaxis, input$PointplotsBeeswarm),{
        
        if (exists("htm") & !is.null(input$Xaxis) & !is.null(input$Yaxis)){
            switch(input$plotType,
                   "Scatter plot" = {
                       plotType[["type"]]      <- "scatter"
                       if(is.numeric( htm[[input$Xaxis]] ) ){

                           # The X axis can be treated as continuous or categorical
                           plotType[["XaxisType"]] <- "continuous"
                           output$UIXContinuousCategorical <- renderUI(radioButtons("XContinuousCategorical", label = "How to treat X axis values",
                                                                                    choices = list("continuous", "categorical"),
                                                                                    selected = "continuous"))
                           # Plot subtype can only be determined once the 'XContinuousCategorical' widget exists
                           # if(input$XContinuousCategorical == "continuous"){
                           #     plotType[["subtype"]]   <- "scatter"
                           # }
                           # 
                           # if(input$XContinuousCategorical == "categorical"){
                           #     if(input$PointplotsBeeswarm){
                           #         plotType[["subtype"]]   <- "beeswarm"
                           #     } else{
                           #         plotType[["subtype"]]   <- "jitter"
                           #     }
                           # }

                       } else{
                           if(input$PointplotsBeeswarm){
                               plotType[["subtype"]]   <- "beeswarm"
                               plotType[["XaxisType"]] <- "categorical"
                               output$UIXContinuousCategorical <- renderUI(NULL)
                           } else{
                               plotType[["subtype"]]   <- "jitter"
                               plotType[["XaxisType"]] <- "categorical"
                               output$UIXContinuousCategorical <- renderUI(NULL)
                           }
                       }
                   },
                   "Boxplot" = {
                       plotType[["type"]]      <- "Boxplot"
                       plotType[["subtype"]]   <- "Boxplot"
                       plotType[["XaxisType"]] <- "none"
                       output$UIXContinuousCategorical <- renderUI(NULL)
                   },
                   "Heatmap" = {
                       plotType[["type"]]      <- "Heatmap"
                       plotType[["subtype"]]   <- "Heatmap"
                       plotType[["XaxisType"]] <- "none"
                       output$UIXContinuousCategorical <- renderUI(NULL)
                   }
            )
        } else{
            plotType[["type"]]      <- "none"
            plotType[["subtype"]]   <- "none"
            plotType[["XaxisType"]] <- "none"
            output$UIXContinuousCategorical <- renderUI(NULL)
        }

    })
    
    # Determine the kind of plot to draw #2: in some plot types the user can select how to handle X axis values
    observeEvent(input$XContinuousCategorical,{
        plotType[["XaxisType"]] <- input$XContinuousCategorical
        
        # Determine the scatter plot subtype
        switch(input$XContinuousCategorical, 
            "continuous" = {
                plotType[["subtype"]]   <- "scatter"
            },
            "categorical" = {
                if(input$PointplotsBeeswarm){
                    plotType[["subtype"]]   <- "beeswarm"
                } else{
                    plotType[["subtype"]]   <- "jitter"
                }
            }
        )
        
    })
    
    
    output$UIselectBatch <- renderUI({
        input$file1
        input$plotType
        input$plotScatterBoxOrHeatmap
        
        mychoices     <- if (exists("htm")) as.list( c( unique( htm[[input$colBatch]] ) ) ) else NULL
        mychoices_all <- if (exists("htm")) as.list( c( "All batches", unique( htm[[input$colBatch]] ) ) ) else NULL
        
        if( is.null( input$colBatch ) )
        {
          selectInput("batch", "Show this batch:", as.list( c( "All batches" ) ) )
        }
        else if( input$plotType == "Heatmap" )
        {
          selectInput("batch", "Show this batch:", mychoices ) 
        }
        else
        {
          selectInput("batch", "Show this batch:", mychoices_all )
        }
    })
    

    observeEvent(c(input$file1, input$buttonSessionLoad, input$plotType, input$applyNorm),{

        mychoices_allcols          <- if (exists("htm")) as.list(names(htm)) else NULL
        mychoices_allcols_none     <- if (exists("htm")) as.list(c("None", names(htm))) else NULL
        
        # Display plot control widgets depending on which plot type is selected
        switch(input$plotType,
            "Scatter plot" = {
                output$UIselectXaxis <- renderUI(selectInput("Xaxis", "X axis:", choices = mychoices_allcols, width = "200%"))
                output$UIselectYaxis <- renderUI(selectInput("Yaxis", "Y axis:", choices = mychoices_allcols, width = "200%"))
                
                output$UIhighlightQCfailed     <- renderUI(selectInput("highlightQCfailed", "Display data points that failed QC", choices = c("Don't show","Show with cross")))
                
                output$UIPointplotsBeeswarm    <- renderUI(checkboxInput("PointplotsBeeswarm", label = "Remove point overlay", value = FALSE))
                output$UIPointplotsplitBy      <- renderUI(selectInput("PointplotsplitBy", "Split plot by", choices = mychoices_allcols_none))
                output$UIPointplotfilterColumn <- renderUI(selectInput("PointplotfilterColumn", "Only show images where column:", choices = mychoices_allcols_none, width = "100%"))
                
                output$UIPointplotSubsample    <- renderUI(checkboxInput("PointplotSubsample", label = "Subsample data?", value = FALSE))
                output$UIPointplotSubsampleN   <- renderUI(if(input$PointplotSubsample){
                    numericInput("PointplotSubsampleN", label = "Plot every Nth data point (black dots)", value = 10, min = 1, max = nrow(htm))
                }else{
                    NULL
                })
                output$UIPointplotSubsampleM   <- renderUI(if(input$PointplotSubsample){
                    numericInput("PointplotSubsampleM", label = "Show the M lowest and highest values (red dots)", value = 10, min = 1, max = floor(nrow(htm)/2))
                }else{
                    NULL
                })
                
                output$UIPointplotfilterValues <- renderUI(
                  if ( is.null( input$PointplotfilterColumn ) )
                  {
                    selectInput("PointplotfilterValues", "Matches:", choices = as.list(c("All")) , width = "100%", multiple = TRUE)
                  }
                  else
                  {
                      mychoices_filter_val_point <- if (exists("htm")) as.list(c("All", htm[[input$PointplotfilterColumn]])) else NULL
                      selectInput("PointplotfilterValues", "Matches:", choices = mychoices_filter_val_point, width = "100%", multiple = TRUE)
                  }
                  )
                output$UIBoxplothighlightCenter <- renderUI(NULL)
                output$UIBoxplotsplitBy <- renderUI(NULL)
                
                output$UILUTminmax <- renderUI(NULL)
                
                output$UILUTcolors <- renderUI(NULL)
            },
            "Boxplot"      = {
                output$UIselectXaxis <- renderUI(selectInput("Xaxis", "Categories:", choices = mychoices_allcols, width = "200%"))
                output$UIselectYaxis <- renderUI(selectInput("Yaxis", "Values:", choices = mychoices_allcols, width = "200%"))
                
                output$UIhighlightQCfailed     <- renderUI(selectInput("highlightQCfailed", "Display data points that failed QC", choices = c("Don't show","Show as cross")))
                
                output$UIPointplotsBeeswarm    <- renderUI(NULL)
                output$UIPointplotsplitBy      <- renderUI(NULL)
                output$UIPointplotfilterColumn <- renderUI(NULL)
                output$UIPointplotSubsample    <- renderUI(NULL)
                output$UIPointplotSubsampleN   <- renderUI(NULL)
                output$UIPointplotSubsampleM   <- renderUI(NULL)
                output$UIPointplotfilterValues <- renderUI(NULL)
                
                output$UIBoxplothighlightCenter <- renderUI(selectInput("BoxplothighlightCenter", "Highlight box center?", choices = list("No", "Mean", "Median")))
                output$UIBoxplotsplitBy <- renderUI(selectInput("BoxplotsplitBy", "Split plot by", choices = mychoices_allcols_none))
                
                output$UILUTminmax <- renderUI(NULL)
                output$UILUTcolors <- renderUI(NULL)
            },
            "Heatmap"      = {
                output$UIselectXaxis <- renderUI(NULL)
                output$UIselectYaxis <- renderUI(selectInput("Yaxis", "Values:", choices = mychoices_allcols, width = "200%"))
                
                output$UIPointplotsBeeswarm     <- renderUI(NULL)
                output$UIPointplotsplitBy       <- renderUI(NULL)
                output$UIPointplotfilterColumn  <- renderUI(NULL)
                output$UIPointplotSubsample     <- renderUI(NULL)
                output$UIPointplotSubsampleN    <- renderUI(NULL)
                output$UIPointplotSubsampleM    <- renderUI(NULL)
                output$UIPointplotfilterValues  <- renderUI(NULL)
                
                output$UIBoxplothighlightCenter <- renderUI(NULL)
                output$UIBoxplotsplitBy         <- renderUI(NULL)
                
                output$UILUTminmax              <- renderUI({
                    # Do not show LUT adjustments if a dataset is not loaded
                    Ymin <- if (exists("htm")) min(htm[[input$Yaxis]], na.rm = TRUE) else 0
                    Ymax <- if (exists("htm")) max(htm[[input$Yaxis]], na.rm = TRUE) else 0
                    
                    # Do not show LUT adjustments if the user selects a non-numerical column
                    if(!is.numeric(Ymin) | !is.numeric(Ymax)) return(NULL)
                    
                    tagList(
                        fluidRow(column(12,
                                    sliderInput("LUTminmax", "LUT adjustment", min = Ymin, max = Ymax, value = c(Ymin, Ymax), width = "100%")
                                )
                        # ),
                        # fluidRow(column(4,
                        #             actionButton("LUTreset", "Reset LUT", width = "100%")
                        #         ),
                        #         column(1),
                        #         column(7,
                        #             actionButton("LUTquantile", "Autoscale LUT to 3% quantiles of each batch", width = "100%")
                        #         )
                        )
                    )

                })
                
                output$UILUTcolors              <- renderUI({
                    
                    # Do not show LUT colors if the user selects a non-numerical column
                    if(is.null(input$LUTminmax)) return(NULL)
                    
                    selectInput("LUTcolors", "LUT colors", choices = c("Red-White-Green", "Blue-White-Red"), width = "100%")
                })
                
                output$UIhighlightQCfailed      <- renderUI({
                    
                    # Do not show LUT colors if the user selects a non-numerical column
                    if(is.null(input$LUTminmax)) return(NULL)
                    
                    selectInput("highlightQCfailed", "Display data points that failed QC", choices = c("Don't show","Show with cross"))
                })
                
            }
        )
    })
    
    htmHeatMap <- reactive({

        if( input$batch == "All batches" ) return( NULL )

        makeHeatmapDataFrame(df           = htmFilteredForCurrentPlot(), 
                             WellX        = input$wells_X,
                             WellY        = input$wells_Y,
                             PosX         = input$npos_X,
                             PosY         = input$npos_Y,
                             subposjitter = input$squaredodge,
                             batch_col    = input$colBatch,
                             batch        = input$batch,
                             col_Well     = input$colWell,
                             col_Pos      = input$colPos,
                             col_QC       = col_QC)
    })
    
    
    htmFilteredForCurrentPlot <- reactive({
      
      input$plotScatterBoxOrHeatmap
      
      isolate({

        filterDataFrame(df                = htm, 
                        x_col             = input$Xaxis,
                        y_col             = input$Yaxis,
                        batch_col         = input$colBatch, 
                        batch             = input$batch, 
                        highlightQCfailed = input$highlightQCfailed, 
                        filterByColumn    = input$PointplotfilterColumn,  
                        whichValues       = input$PointplotfilterValues, 
                        col_QC            = col_QC,
                        subsampledata     = ifelse(is.null(input$PointplotSubsample), FALSE, input$PointplotSubsample),
                        XAxisType         = plotType[["XaxisType"]],
                        subsampleN        = ifelse(is.null(input$PointplotSubsample) | is.null(input$PointplotSubsampleN), NULL, input$PointplotSubsampleN),
                        extremevalues     = ifelse(is.null(input$PointplotSubsample) | is.null(input$PointplotSubsampleM), NULL, input$PointplotSubsampleM))
        
      })
      
    })



    # Plot
    output$plot <- renderPlotly({
        
        input$plotScatterBoxOrHeatmap

        isolate({
          
            if( ! is.null( input$batch ) )
            {
              switch(input$plotType,
                     
                     "Scatter plot" = pointPlot(
                         df =  htmFilteredForCurrentPlot(), 
                         x = input$Xaxis, 
                         y = input$Yaxis, 
                         plottype = plotType[["subtype"]],
                         col_QC = col_QC, 
                         highlightQCfailed = input$highlightQCfailed, 
                         beeswarm = input$PointplotsBeeswarm,
                         splitBy = input$PointplotsplitBy, 
                         colTreatment = input$colTreatment, 
                         colBatch = input$colBatch,
                         colColors = if("HTM_color" %in% names(htmFilteredForCurrentPlot())) "HTM_color"),
                       
                     "Boxplot"      = boxPlot(
                         df =  htmFilteredForCurrentPlot(), 
                         batch = input$colBatch, 
                         x = input$Xaxis, 
                         y = input$Yaxis, 
                         col_QC = col_QC, 
                         highlightCenter = input$BoxplothighlightCenter, 
                         splitBy = input$PointplotsplitBy, 
                         colTreatment = input$colTreatment, 
                         colBatch = input$colBatch),
                       
                     "Heatmap"      = heatmapPlot( 
                       df = htmHeatMap(), 
                       measurement = input$Yaxis, 
                       batch = input$batch,
                       nrows = input$wells_Y, 
                       ncolumns = input$wells_X, 
                       symbolsize = input$squaresize, 
                       col_QC =   col_QC, 
                       highlightQCfailed = input$highlightQCfailed, 
                       colorMin = input$LUTminmax[1], 
                       colorMax = input$LUTminmax[2], 
                       lutColors = input$LUTcolors, 
                       colTreatment = input$colTreatment, 
                       colBatch = input$colBatch )
              )
            }
            else
            {
              ggplotly( ggplot() ) 
            }
         
          })
      
    })
    
    
    
    ################################################################
    # 4. QUALITY CONTROL                                           #
    ################################################################
    approvedExperiments   <- reactive({
        input$QCAddfailedExperiments
        input$QCcheckGroup
        
        if(exists("htm")){
            return(
                unique(as.character(htm[[input$colBatch]]))[!(unique(as.character(htm[[input$colBatch]])) %in% as.character(QCsettings[QCsettings$type == "Failed experiment","minimum"]))]
            )
        } else{
            return(NULL)
        }
        
    })
    
    output$UIQCfailedExperiments <- renderUI({
        input$file1
        input$applyNorm
        
        fluidRow(
            column(6,
                selectInput("QCfailedExperiment", "Failed experiments:", approvedExperiments(), width = "200%")
            ),
            column(2,
                NULL
            ),
            column(2,
                   NULL
            ),
            column(1,
                   actionButton("QCAddfailedExperiments", "Add QC", icon = icon("plus-square"), width = "100px")
            ),
            tags$style(type='text/css', "#QCAddfailedExperiments { width:100%; margin-top: 25px;}")
        )
    })
    
    
    output$UIQCnumeric  <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        fluidRow(
            column(6,
                selectInput("QCnumMeasurement", "Number-based QC:", mychoices, width = "200%")
            ),
            column(2,
                numericInput("QCnumMin", "Minimum:", value=1)
            ),
            column(2,
                numericInput("QCnumMax", "Maximum:", value=100)
            ),
            column(1,
                actionButton("QCAddnumeric", "Add QC", icon = icon("plus-square"), width = "100px")
            ),
            tags$style(type='text/css', "#QCAddnumeric { width:100%; margin-top: 25px;}")
        )
    })
    output$UIQCtext              <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        fluidRow(
            column(6,
                   selectInput("QCtxtMeasurement", "Failed images (text-based):", mychoices, width = "200%")
            ),
            column(2,
                   textInput("QCtxtBad", "Value:")
            ),
            column(2,
                   NULL
            ),
            column(1,
                   actionButton("QCAddtxt", "Add QC", icon = icon("plus-square"), width = "100px")
            ),
            tags$style(type='text/css', "#QCAddtxt { width:100%; margin-top: 25px;}")
        )
    })

    observeEvent(input$buttonSessionLoad,{
        output$QCtable    <- renderTable(QCsettings[,1:4])
    })
    observeEvent(input$QCAddfailedExperiments,{
        temp <- data.frame(
            type        = "Failed experiment",
            measurement = isolate(input$colBatch),
            minimum     = isolate(input$QCfailedExperiment),
            maximum     = isolate(input$QCfailedExperiment),
            failed      = sum(htm[[isolate(input$colBatch)]] == isolate(input$QCfailedExperiment))
        )
        QCsettings <<- rbind(QCsettings, temp)
        
        # Update show/remove QC
        output$QCtable    <- renderTable(QCsettings[,1:4])
        output$UIQCactive <- renderUI({
            checkboxGroupInput("QCcheckGroup",
                               label = strong("Disable this QC"), 
                               choices = as.list(row.names(QCsettings))
            )
        })
        
        # Reset QC report
        output$QCreport <- renderPrint("")
    })
    observeEvent(input$QCAddnumeric,{
        temp <- data.frame(
                    type        = "Numeric QC",
                    measurement = isolate(input$QCnumMeasurement),
                    minimum     = as.character(isolate(input$QCnumMin)),
                    maximum     = as.character(isolate(input$QCnumMax)),
                    failed      = sum((htm[[isolate(input$QCnumMeasurement)]] < isolate(input$QCnumMin) | htm[[isolate(input$QCnumMeasurement)]] > isolate(input$QCnumMax)) & !is.na(htm[[isolate(input$QCnumMeasurement)]]))
                )
        QCsettings <<- rbind(QCsettings, temp)
        
        # Update show/remove QC
        output$QCtable    <- renderTable(QCsettings[,1:4])
        output$UIQCactive <- renderUI({
            checkboxGroupInput("QCcheckGroup",
                               label = strong("Disable this QC"), 
                               choices = as.list(row.names(QCsettings))
            )
        })
        
        # Reset QC report
        output$QCreport <- renderPrint("")
    })
    observeEvent(input$QCAddtxt,{
        temp <- data.frame(
            type        = "Text QC",
            measurement = isolate(input$QCtxtMeasurement),
            minimum     = isolate(input$QCtxtBad),
            maximum     = isolate(input$QCtxtBad),
            failed      = sum(htm[[isolate(input$QCtxtMeasurement)]] == isolate(input$QCtxtBad))
        )
        QCsettings <<- rbind(QCsettings, temp)
        
        # Update show/remove QC
        output$QCtable    <- renderTable(QCsettings[,1:4])
        output$UIQCactive <- renderUI({
            checkboxGroupInput("QCcheckGroup",
                               label = strong("Disable this QC"), 
                               choices = as.list(row.names(QCsettings))
            )
        })
        
        # Reset QC report
        output$QCreport <- renderPrint("")
    })    
    observeEvent(input$QCcheckGroup, {
        QCsettings <<- QCsettings[row.names(QCsettings) != input$QCcheckGroup,]
        
        # Update show/remove QC
        output$QCtable    <- renderTable(QCsettings[,1:4])
        output$UIQCactive <- renderUI({
            checkboxGroupInput("QCcheckGroup",
                               label = strong("Disable this QC"), 
                               choices = as.list(row.names(QCsettings))
            )
        })
        
        # Reset QC report
        output$QCreport <- renderPrint("")
    })
    observeEvent(input$applyQC,{
        
        withCallingHandlers({
            html("echo_QC", "", add = FALSE)
            
            echo("Performing QCs:")
            echo("")
            
            if(nrow(QCsettings) == 0){
                
                # If no QC setting is selected, approve all images
                htm[[col_QC]] <- TRUE
                htm <<- htm
                
                echo("  No QCs selected. Setting all data to valid.")
                echo("  Total measurements: ", nrow(htm))
                echo("")
                echo("The column ", col_QC, " has been updated.")
                echo("The updated data table can be viewed in 'More > View table'.")
                
            } else{
                
                # If QC parameters have been selected, label the htm data.frame accordingly
                temp <- applyQC(htm, QCsettings)
                htm[[col_QC]] <- temp
                htm <<- htm
                
                echo("QCs:")
                for(i in 1:nrow(QCsettings)){
                    switch(as.character(QCsettings[i, "type"]),
                        "Failed experiment" = {
                            echo("Failed experiment:")
                            echo("  Batch: ", QCsettings[i, "minimum"])
                        },
                        "Numeric QC" = {
                            echo("Measurement: ", QCsettings[i, "measurement"])
                            echo("  Allowed range: ", QCsettings[i, "minimum"], " ... ", QCsettings[i, "maximum"], " and not NA.")
                        },
                        "Text QC" = {
                            echo("Measurement: ", QCsettings[i, "measurement"])
                            echo("  Reject text: ", QCsettings[i, "minimum"])
                        }
                    )
                    
                    echo("  Total: ", nrow(htm))
                    echo("  Failed: ", QCsettings[i, "failed"])
                    echo("")
                }
                
                echo("Summary of all QCs:")
                echo("  Total (all QCs): ", nrow(htm))
                echo("     Approved (all Qcs): ", sum(htm[[col_QC]]))
                echo("     Failed (all Qcs): ", sum(!htm[[col_QC]]))
                echo("")
                echo("The column ", col_QC, " has been updated.")
            }
            
        },
            message = function(m) html("echo_QC", m$message, add = TRUE)
        )
    })
    
    
    
    ################################################################
    # PLOT-FIJI INTERACTION                                        #
    ################################################################
    output$selection <- renderPrint( {
        
        s <- event_data( "plotly_click" )
        
        if( is.null( s ) ) 
        {
          return( "Welcome!" );
        }
        
        isolate({
          
          if ( length( input$images2display ) == 0 )
          {
            return( "There are no images for viewing selected." );
          }
          
          print( "You selected:" )
          print( s )
          i = s[[ "pointNumber" ]] + 1
          
          # get the currently plotted dataframe, where the row numbers match the 
          # numbers returned but the clicking observer
          df <- htmFilteredForCurrentPlot()
          
          tempPathInTable    <- gsub("\\\\", "/", input$pathInTable)
          tempPathInComputer <- gsub("\\\\", "/", input$pathInComputer)
          
          directories <- df[i, paste0(input$prefixPath, input$images2display)]
          directories <- gsub("\\\\", "/", directories)
          directories <- sub( tempPathInTable, tempPathInComputer, directories, ignore.case = TRUE)
          
          filenames <- df[i, paste0( input$prefixFile, input$images2display )]
          
          print( paste0( "Launching Fiji: ", input$fiji_binary ) )
          print( directories )
          print( filenames )
          
          x <- "NA"; y <- "NA"; z <- "NA";
          if ( input$colObjectPosX != "NA ") { x <- df[i, input$colObjectPosX] }
          if ( input$colObjectPosY != "NA ") { y <- df[i, input$colObjectPosY] }
          if ( input$colObjectPosZ != "NA ") { z <- df[i, input$colObjectPosZ] }
          
          print( input$colObjectPosX )
          print( input$colObjectPosY )
          print( input$colObjectPosZ )
          print( paste( "Object position: ", x, y, z ) )
          
          OpenInFiji( directories, filenames, input$fiji_binary, x, y, z )
          
        }) # isolate
    
    })

    
    
    ################################################################
    # 5. NORMALIZATION                                             #
    ################################################################
    output$UINormFeatures      <- renderUI({
        input$file1
        input$applySummary
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        selectInput("NormFeatures", "Data features to be analyzed", choices = mychoices, width = "100%", multiple = FALSE)
    })
    
    output$UINormDataTransform <- renderUI({
        input$file1
        
        selectInput("NormDataTransform", "Data transformation", choices = list("None selected", "log2"), width = "100%")
    })
    
    output$UINormGradientCorr  <- renderUI({
        input$file1
        
        selectInput("NormGradientCorr", "Batch-wise spatial gradient correction", choices = list("None selected", "median polish", "median 7x7", "median 5x5", "median 3x3", "z-score 5x5"), width = "100%")
    })
    
    output$UINormMethod        <- renderUI({
        input$file1
        
        selectInput("NormMethod", "Batch-wise normalisation against negative control", choices = list("None selected", "z-score", "z-score (median subtraction)", "robust z-score", "subtract mean ctrl", "divide by mean ctrl", "subtract median ctrl", "divide by median ctrl"), width = "100%")
    })
    
    output$UINormFormula       <- renderUI({
        
        input$NormMethod
        
        norm_formula_latex <- NULL
        if(input$NormMethod == "z-score") {
            norm_formula_latex <- "$$\\Huge{Z-Score (x_{plate_{i}}) = \\frac{x_{plate_{i}}-Average_{NegCtrl,plate_{i}}}{sd_{NegCtrl,plate_{i}}}}$$"
        } 
        else if(input$NormMethod == "z-score (median subtraction)") {
            norm_formula_latex <- "$$\\Huge{Z-Score (x_{plate_{i}}) = \\frac{x_{plate_{i}}-Median_{NegCtrl,plate_{i}}}{sd_{NegCtrl,plate_{i}}}}$$"
        }
        else if(input$NormMethod == "robust z-score") {
            norm_formula_latex <- "$$\\Huge{Robust Z-Score (x_{plate_{i}}) = \\frac{x_{plate_{i}}-Median_{NegCtrl,plate_{i}}}{MAD_{NegCtrl,plate_{i}}}}$$"
        }
        else if(input$NormMethod == "subtract mean ctrl") {
            norm_formula_latex <- "$$\\Huge{Difference to Mean (x_{plate_{i}}) = x_{plate_{i}} - Average_{NegCtrl,plate_{i}}}$$"
        }
        else if(input$NormMethod == "divide by mean ctrl") {
            norm_formula_latex <- "$$\\Huge{Fold Change versus Mean (x_{plate_{i}}) = \\frac{x_{plate_{i}}}{Average_{NegCtrl,plate_{i}}}}$$"
        }
        else if(input$NormMethod == "subtract median ctrl") {
            norm_formula_latex <- "$$\\Huge{Difference to Median (x_{plate_{i}}) = x_{plate_{i}} - Median_{NegCtrl,plate_{i}}}$$"
        }
        else if(input$NormMethod == "divide by median ctrl") {
            norm_formula_latex <- "$$\\Huge{Fold Change versus Median (x_{plate_{i}}) = \\frac{x_{plate_{i}}}{Median_{NegCtrl,plate_{i}}}}$$"
        }

        withMathJax(norm_formula_latex)
    })

    
    output$UINormNegCtrl       <- renderUI({
        input$file1
        
        mychoices <- if (exists("htm")) as.list(c("None selected", "All treatments", sort(htm[[input$colTreatment]]))) else NULL
        
        selectInput("NormNegCtrl", "Negative control", choices = mychoices, width = "100%")
    })
    
    observeEvent(input$applyNorm,{
        
        withCallingHandlers({
            html("echo_Normalization", "", add = FALSE)
            
            htm <<- htmNormalization(data                = htm,
                                     measurements        = input$NormFeatures,
                                     col_Experiment      = input$colBatch,
                                     transformation      = input$NormDataTransform,
                                     gradient_correction = input$NormGradientCorr,
                                     normalisation       = input$NormMethod,
                                     negcontrol          = input$NormNegCtrl,
                                     col_QC              = col_QC,
                                     col_Well            = input$colWell,
                                     col_Treatment       = input$colTreatment,
                                     num_WellX           = input$wells_X,
                                     num_WellY           = input$wells_Y)
        },
            message = function(m) html("echo_Normalization", m$message, add = TRUE)
        )
        
    })


    
    ################################################################
    # 6. TREATMENT SUMMARY                                         #
    ################################################################
    output$UISummaryMeasurements <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        selectInput("SummaryMeasurements", "Measurements to be analyzed", choices = mychoices, width = "100%", multiple = TRUE)
    })
    output$UISummaryNegCtrl      <- renderUI({
        input$file1
        input$applyNorm
        input$NormNegCtrl
        
        mychoices <- if (exists("htm")) as.list(c("None selected", "All treatments", sort(htm[[input$colTreatment]]))) else NULL
        
        selectInput("SummaryNegCtrl", "Negative control", choices = mychoices, width = "100%")
    })
    output$UISummaryPosCtrl      <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(c("None selected", sort(htm[[input$colTreatment]]))) else NULL
        
        selectInput("SummaryPosCtrl", "Positive control", choices = mychoices, width = "100%")
    })
    output$UISummaryNumObjects   <- renderUI({
        input$file1
        input$applyNorm
        
        mychoices <- if (exists("htm")) as.list(names(htm)) else NULL
        
        selectInput("SummaryNumObjects", "Number of objects per image", choices = mychoices, width = "100%")
    })
    
    observeEvent(input$SummaryMeasurements,{
        output$TreatmentSummaryTable <- renderDataTable(data.frame())
        output$SummaryReport <- renderPrint("")
    })
    observeEvent(input$SummaryNegCtrl,{
        output$TreatmentSummaryTable <- renderDataTable(data.frame())
        output$SummaryReport <- renderPrint("")
    })
    observeEvent(input$SummaryPosCtrl,{
        output$TreatmentSummaryTable <- renderDataTable(data.frame())
        output$SummaryReport <- renderPrint("")
    })
    observeEvent(input$SummaryNumObjects,{
        output$TreatmentSummaryTable <- renderDataTable(data.frame())
        output$SummaryReport <- renderPrint("")
    })
    observeEvent(input$applySummary,{
        
        withCallingHandlers({
            html("echo_TreatmentSummary", "", add = FALSE)
            
            temp <- htmTreatmentSummary(data                 = htm,
                                        measurements         = input$SummaryMeasurements,
                                        col_Experiment       = input$colBatch,
                                        col_Treatment        = input$colTreatment,
                                        col_ObjectCount      = input$SummaryNumObjects,
                                        col_QC               = col_QC,
                                        negative_ctrl        = input$SummaryNegCtrl,
                                        positive_ctrl        = input$SummaryPosCtrl,
                                        excluded_Experiments = "")
            
            # Display the summary table in the html page
            output$TreatmentSummaryTable <- renderDataTable(temp[,c("treatment", "median__means", "t_test__p_value", "t_test__signCode", "numObjectsOK", "numImagesOK", "numReplicatesOK")])
            
            # Save summary table
            echo("")
            echo("Please save the summary table using the popup window.")
            path <- tclvalue(tkgetSaveFile(initialfile = paste0("TreatmentSummary--", input$SummaryMeasurements, ".csv")))
            write.csv(temp, path, row.names = FALSE)
            
            if(path == ""){
                echo("Did not save treatment summary table!")
            } else{
                echo("Saved summary table to ", path)
            }
            
        },
            message = function(m) html("echo_TreatmentSummary", m$message, add = TRUE)
        )
        
    })

    
    
    ################################################################
    # R CONSOLE                                                    #
    ################################################################
    runcodeServer()
    
    
    
    ################################################################
    # DATA TABLE                                                   #
    ################################################################
    observeEvent(input$saveHTMtable,{
        path <- tclvalue(tkgetSaveFile(initialfile = "HTMtable.csv"))
        write.csv(htm, path, row.names = FALSE)
    })
    
    
    
    
    ################################################################
    # SAVE & LOAD SESSION                                          #
    ################################################################
    
    # Keep track of the state of all items in the UI
    UI <<- reactive(
        list(
            list(type     = "input",
                 name     = "file1",
                 choices  = NA,
                 selected = input$file1$datapath,
                 comment  = "The location of the raw data table"),
            list(type     = "input",
                 name     = "colTreatment",
                 choices  = "NOT SUPPORTED",
                 selected = input$colTreatment,
                 comment  = ""),
            list(type     = "input",
                 name     = "colBatch",
                 choices  = "NOT SUPPORTED",
                 selected = input$colBatch,
                 comment  = ""),
            list(type     = "input",
                 name     = "colWell",
                 choices  = "NOT SUPPORTED",
                 selected = input$colWell,
                 comment  = ""),
            list(type     = "input",
                 name     = "colPos",
                 choices  = "NOT SUPPORTED",
                 selected = input$colPos,
                 comment  = ""),
            list(type     = "input",
                 name     = "fiji_binary",
                 choices  = "NOT SUPPORTED",
                 selected = input$fiji_binary,
                 comment  = ""),
            list(type     = "input",
                 name     = "images2display",
                 choices  = "NOT SUPPORTED",
                 selected = input$images2display,
                 comment  = ""),
            list(type     = "input",
                 name     = "pathInTable",
                 choices  = "NOT SUPPORTED",
                 selected = input$pathInTable,
                 comment  = ""),
            list(type     = "input",
                 name     = "pathInComputer",
                 choices  = "NOT SUPPORTED",
                 selected = input$pathInComputer,
                 comment  = ""),
            list(type     = "input",
                 name     = "prefixPath",
                 choices  = "NOT SUPPORTED",
                 selected = input$prefixPath,
                 comment  = ""),
            list(type     = "input",
                 name     = "prefixFile",
                 choices  = "NOT SUPPORTED",
                 selected = input$prefixFile,
                 comment  = ""),
            list(type     = "input",
                 name     = "colObjectPosX",
                 choices  = "NOT SUPPORTED",
                 selected = input$colObjectPosX,
                 comment  = ""),
            list(type     = "input",
                 name     = "colObjectPosY",
                 choices  = "NOT SUPPORTED",
                 selected = input$colObjectPosY,
                 comment  = ""),
            list(type     = "input",
                 name     = "colObjectPosZ",
                 choices  = "NOT SUPPORTED",
                 selected = input$colObjectPosZ,
                 comment  = ""),
            list(type     = "input",
                 name     = "wells_Y",
                 choices  = "NOT SUPPORTED",
                 selected = input$wells_Y,
                 comment  = ""),
            list(type     = "input",
                 name     = "wells_X",
                 choices  = "NOT SUPPORTED",
                 selected = input$wells_X,
                 comment  = ""),
            list(type     = "input",
                 name     = "npos_Y",
                 choices  = "NOT SUPPORTED",
                 selected = input$npos_Y,
                 comment  = ""),
            list(type     = "input",
                 name     = "npos_X",
                 choices  = "NOT SUPPORTED",
                 selected = input$npos_X,
                 comment  = ""),
            list(type     = "input",
                 name     = "squaredodge",
                 choices  = "NOT SUPPORTED",
                 selected = input$squaredodge,
                 comment  = ""),
            list(type     = "input",
                 name     = "squaresize",
                 choices  = "NOT SUPPORTED",
                 selected = input$squaresize,
                 comment  = ""),
            list(type     = "input",
                 name     = "plotType",
                 choices  = "NOT SUPPORTED",
                 selected = input$plotType,
                 comment  = ""),
            list(type     = "input",
                 name     = "batch",
                 choices  = "NOT SUPPORTED",
                 selected = input$batch,
                 comment  = ""),
            list(type     = "input",
                 name     = "Xaxis",
                 choices  = "NOT SUPPORTED",
                 selected = input$Xaxis,
                 comment  = ""),
            list(type     = "input",
                 name     = "Yaxis",
                 choices  = "NOT SUPPORTED",
                 selected = input$Yaxis,
                 comment  = ""),
            list(type     = "input",
                 name     = "highlightQCfailed",
                 choices  = "NOT SUPPORTED",
                 selected = input$highlightQCfailed,
                 comment  = ""),
            list(type     = "input",
                 name     = "PointplotsplitBy",
                 choices  = "NOT SUPPORTED",
                 selected = input$PointplotsplitBy,
                 comment  = ""),
            list(type     = "input",
                 name     = "PointplotfilterColumn",
                 choices  = "NOT SUPPORTED",
                 selected = input$PointplotfilterColumn,
                 comment  = ""),
            list(type     = "input",
                 name     = "PointplotfilterValues",
                 choices  = "NOT SUPPORTED",
                 selected = input$PointplotfilterValues,
                 comment  = ""),
            list(type     = "input",
                 name     = "BoxplothighlightCenter",
                 choices  = "NOT SUPPORTED",
                 selected = input$BoxplothighlightCenter,
                 comment  = ""),
            list(type     = "input",
                 name     = "BoxplotsplitBy",
                 choices  = "NOT SUPPORTED",
                 selected = input$BoxplotsplitBy,
                 comment  = ""),
            list(type     = "input",
                 name     = "LUTcolors",
                 choices  = "NOT SUPPORTED",
                 selected = input$LUTcolors,
                 comment  = ""),
            list(type     = "input",
                 name     = "LUTminmax",
                 choices  = "NOT SUPPORTED",
                 selected = input$LUTminmax,
                 comment  = ""),
            list(type     = "input",
                 name     = "NormFeatures",
                 choices  = "NOT SUPPORTED",
                 selected = input$NormFeatures,
                 comment  = ""),
            list(type     = "input",
                 name     = "NormDataTransform",
                 choices  = "NOT SUPPORTED",
                 selected = input$NormDataTransform,
                 comment  = ""),
            list(type     = "input",
                 name     = "NormGradientCorr",
                 choices  = "NOT SUPPORTED",
                 selected = input$NormGradientCorr,
                 comment  = ""),
            list(type     = "input",
                 name     = "NormMethod",
                 choices  = "NOT SUPPORTED",
                 selected = input$NormMethod,
                 comment  = ""),
            list(type     = "input",
                 name     = "NormNegCtrl",
                 choices  = "NOT SUPPORTED",
                 selected = input$NormNegCtrl,
                 comment  = ""),
            list(type     = "input",
                 name     = "SummaryMeasurements",
                 choices  = "NOT SUPPORTED",
                 selected = input$SummaryMeasurements,
                 comment  = ""),
            list(type     = "input",
                 name     = "SummaryNegCtrl",
                 choices  = "NOT SUPPORTED",
                 selected = input$SummaryNegCtrl,
                 comment  = ""),
            list(type     = "input",
                 name     = "SummaryPosCtrl",
                 choices  = "NOT SUPPORTED",
                 selected = input$SummaryPosCtrl,
                 comment  = ""),
            list(type     = "input",
                 name     = "SummaryNumObjects",
                 choices  = "NOT SUPPORTED",
                 selected = input$SummaryNumObjects,
                 comment  = "")
        )
    )
    
    
    observeEvent(input$buttonSessionSave, {
        
        withCallingHandlers({
            html("echo_SaveLoadSession", "", add = FALSE)
            
            echo("Dialog box: Where is the data table currently loaded?")
            echo("")
            path_to_htm <- tclvalue( tkgetOpenFile() )

            temp <- UI()
            temp[[1]]$selected <- path_to_htm
            UI <- reactive(temp)
            
            echo("Dialog box: Where shall the session file be saved?")
            echo("")
            targetpath <- tclvalue( tkgetSaveFile(initialfile = "shinyHTM_session.RData") )
            
            echo("")
            echo("Gathering session state information...")
            
            # Columns generated by shinyHTM
            htm_columns <- htm[,grepl("^HTM_", colnames(htm)), drop=FALSE]
            
            echo("")
            echo("Saving shinyHTM session to ", targetpath)
            save(UI, QCsettings, htm_columns, file = "c:/users/hugo/Desktop/shinyHTM_session.RData")
            
            echo("")
            echo("Done!")
            echo("The session can only be restored if the dataset is kept in its current location:")
            echo("     ", isolate(UI())[[1]]$selected)
            
        },
        message = function(m) html("echo_SaveLoadSession", m$message, add = TRUE)
        )
    })
    
    observeEvent(input$buttonSessionLoad, {
        
        withCallingHandlers({
            html("echo_SaveLoadSession", "", add = FALSE)

            echo("Loading shinyHTM settings.")
            echo("")
            settingsFilePath <-  tclvalue(tkgetOpenFile(title = "Open shinyHTM session file.")) 

            # Clean work environment
            echo("* Resetting session")
            if(exists("htm"))         rm(htm, inherits = TRUE)
            if(exists("htm_columns")) rm(htm_columns, inherits = TRUE)
            if(exists("QCsettings"))  rm(QCsettings, inherits = TRUE)
            if(exists("UI"))          rm(UI, inherits = TRUE)

            # Load R objects
            load(settingsFilePath)
            QCsettings <<- QCsettings
            
            path_to_htm <- isolate(UI())[[1]]$selected
            
            # Integrity check
            if(!file.exists(path_to_htm)){
                echo("CANNOT RESTORE SESSION: Data table file does not extist")
                echo("     ", path_to_htm)
            } else{
                
                # Reconstitute the htm data frame
                echo("* Loading data table")

                htm <- read.HTMtable(path_to_htm)
                htm <- htm[,setdiff(colnames(htm), colnames(htm_columns))]       # Avoid column duplication
                htm <- cbind(htm, htm_columns)
                rm(htm_columns, inherits = TRUE)
                htm <<- htm
                
                echo("* Loading widget settings")
                
                output$UIcolNameTreatment    <- renderUI({
                    selectInput("colTreatment", "Treatment:", as.list(names(htm)), selected = subsetUI(UI, "input", "colTreatment"),  width = "100%")
                })
                output$UIcolNameBatch        <- renderUI({
                    selectInput("colBatch", "Batch:", as.list(names(htm)), selected = subsetUI(UI, "input", "colBatch"), width = "100%")
                })
                output$UIcolNameWell         <- renderUI({
                    selectInput("colWell", "Well coordinate:", as.list(names(htm)), selected = subsetUI(UI, "input", "colWell"), width = "100%")
                })
                output$UIcolNamePos          <- renderUI({
                    selectInput("colPos", "Sub-position coordinate:", as.list(names(htm)), selected = subsetUI(UI, "input", "colPos"), width = "100%")
                })
                output$UIfiji_path           <- renderUI({
                    if (Sys.info()['sysname'] == "Windows")
                    {
                        fiji_binary_path = subsetUI(UI, "input", "fiji_binary")
                    } 
                    else 
                    {
                        fiji_binary_path = "/Applications/Fiji.app/Contents/MacOS/ImageJ-macosx"
                    }
                    textInput("fiji_binary", "Path to Fiji ", value = subsetUI(UI, "input", "fiji_binary"), width = "100%")
                })
                output$UIavailableimages     <- renderUI({
                    img_names <- gsub(paste0("^", subsetUI(UI, "input", "prefixPath"), "(.*)"), "\\1", names(htm)[grep(paste0("^", subsetUI(UI, "input", "prefixPath")), names(htm))])
                    checkboxGroupInput("images2display", "Select images to be viewed upon clicking within a plot", as.list(img_names), selected = subsetUI(UI, "input", "images2display"))
                })
                output$UIpathInTable         <- renderUI({
                    textInput("pathInTable", "Image root folder name in table", value = subsetUI(UI, "input", "pathInTable"), width = "100%")
                })
                output$UIpathInComputer      <- renderUI({
                    textInput("pathInComputer", "Image root folder name in this computer", value = subsetUI(UI, "input", "pathInComputer"), width = "100%")
                })
                output$UIprefixPath          <- renderUI({
                    textInput("prefixPath", "Prefix: column with folder name", value = subsetUI(UI, "input", "prefixPath"))
                })
                output$UIprefixFile          <- renderUI({
                    textInput("prefixFile", "Prefix: column with file name", value = subsetUI(UI, "input", "prefixFile"))
                })
                output$UIcolNameObjectPosX   <- renderUI({
                    selectInput("colObjectPosX", "Object's x-position:", as.list( c("NA", names(htm))), selected = subsetUI(UI, "input", "colObjectPosX"), width = "100%")
                })
                output$UIcolNameObjectPosY   <- renderUI({
                    selectInput("colObjectPosY", "Object's y-position:", as.list( c("NA", names(htm))), selected = subsetUI(UI, "input", "colObjectPosY"), width = "100%")
                })
                output$UIcolNameObjectPosZ   <- renderUI({
                    selectInput("colObjectPosZ", "Object's z-position:", as.list( c("NA", names(htm))), selected = subsetUI(UI, "input", "colObjectPosZ"), width = "100%")
                })
                output$UIwells_Y             <- renderUI({
                    numericInput("wells_Y", "Number of Rows", value = subsetUI(UI, "input", "wells_Y"))
                })
                output$UIwells_X             <- renderUI({
                    numericInput("wells_X", "Number of Columns", value = subsetUI(UI, "input", "wells_X"))
                })
                output$UInpos_Y              <- renderUI({
                    numericInput("npos_Y", "Number of subposition Rows", value = subsetUI(UI, "input", "npos_Y"))
                })
                output$UInpos_X              <- renderUI({
                    numericInput("npos_X", "Number of subposition Columns", value = subsetUI(UI, "input", "npos_X"))
                })
                output$UIsquaredodge         <- renderUI({
                    sliderInput("squaredodge", "Separation between positions", min=0, max=0.5, value=subsetUI(UI, "input", "squaredodge"), step=0.1)
                })
                output$UIsquaresize          <- renderUI({
                    sliderInput("squaresize", "Square size", min=0.5, max=5, value=subsetUI(UI, "input", "squaresize"), step=0.5)
                })
                # This is where one would restore the plotting settings
                output$UINormFeatures        <- renderUI({
                    selectInput("NormFeatures", "Data features to be analyzed", choices = as.list(names(htm)), selected = subsetUI(UI, "input", "NormFeatures"), width = "100%", multiple = FALSE)
                })
                output$UINormDataTransform   <- renderUI({
                    selectInput("NormDataTransform", "Data transformation", choices = list("None selected", "log2"), selected = subsetUI(UI, "input", "NormDataTransform"), width = "100%")
                })
                output$UINormGradientCorr    <- renderUI({
                    selectInput("NormGradientCorr", "Batch-wise spatial gradient correction", choices = list("None selected", "median polish", "median 7x7", "median 5x5", "median 3x3", "z-score 5x5"), selected = subsetUI(UI, "input", "NormGradientCorr"), width = "100%")
                })
                output$UINormMethod          <- renderUI({
                    selectInput("NormMethod", "Batch-wise normalisation against negative control", choices = list("None selected", "z-score", "z-score (median subtraction)", "robust z-score", "subtract mean ctrl", "divide by mean ctrl", "subtract median ctrl", "divide by median ctrl"), selected = subsetUI(UI, "input", "NormMethod"), width = "100%")
                })
                output$UINormNegCtrl         <- renderUI({
                    selectInput("NormNegCtrl", "Negative control", choices = as.list(c("None selected", "All treatments", sort(htm[[subsetUI(UI, "input", "colTreatment")]]))), selected = subsetUI(UI, "input", "NormNegCtrl"), width = "100%")
                })
                output$UISummaryMeasurements <- renderUI({
                    selectInput("SummaryMeasurements", "Measurements to be analyzed", choices = as.list(names(htm)), selected = subsetUI(UI, "input", "SummaryMeasurements"), width = "100%", multiple = TRUE)
                })
                output$UISummaryNegCtrl      <- renderUI({
                    selectInput("SummaryNegCtrl", "Negative control", choices = as.list(c("None selected", "All treatments", sort(htm[[subsetUI(UI, "input", "colTreatment")]]))), selected = subsetUI(UI, "input", "SummaryNegCtrl"), width = "100%")
                })
                output$UISummaryPosCtrl      <- renderUI({
                    selectInput("SummaryPosCtrl", "Positive control", choices = as.list(c("None selected", sort(htm[[subsetUI(UI, "input", "colTreatment")]]))), selected = subsetUI(UI, "input", "SummaryPosCtrl"), width = "100%")
                })
                output$UISummaryNumObjects   <- renderUI({
                    selectInput("SummaryNumObjects", "Number of objects per image", choices = as.list(names(htm)), selected = subsetUI(UI, "input", "SummaryNumObjects"), width = "100%")
                })
                
                echo("")
                echo("Loaded all settings!")
                
            }

        },
        message = function(m) html("echo_SaveLoadSession", m$message, add = TRUE)
        )
    })
    
    
    
    ################################################################
    # DATA TABLE                                                   #
    ################################################################
    observeEvent(c(input$file1, input$buttonSessionLoad, input$applyQC, input$applyNorm, input$applySummary, input$update_dataTable), {

        if(exists("htm")){
            output$UIValuesTable <- renderUI({
                output$valuestable <- renderDataTable(htm)
                dataTableOutput("valuestable")
            })
        } else{
            output$UIValuesTable <- renderUI(
                tagList(br(), p("Nothing to show here: there is no data table currently loaded."))
            )
        }
 
    })
})
