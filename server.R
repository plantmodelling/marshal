# Guillaume Lobet - Forschungszentrum Julich

shinyServer(
  
  function(input, output, clientData, session) {  
    
    rs <- reactiveValues(rootsystem = NULL, 
                         dataset = NULL, 
                         plant = NULL,
                         params = NULL, 
                         litt = NULL, 
                         plot=NULL,
                         conductivities = NULL,
                         krs = NULL,
                         tact = NULL,
                         soil = NULL,
                         evol = NULL,
                         krs_first = NULL,
                         krs_act = NULL)
    
    observe({
      fileName <- 'www/litterature.txt'
      litt <- read.table(fileName, sep="\t", stringsAsFactors = F, header = T)
      rs$litt <- litt
      fileName <- 'www/modelparameter'
      flist <- unique(gsub(".pparam", "", gsub(".rparam", "", list.files(fileName))))
      fl <- litt$name[litt$id %in% flist]
      updateSelectInput(session, "dataset", choices = fl)  
      
    })  

    observe({
      if(is.null(rs$rootsystem)){return()}
      types <- unique(rs$rootsystem$name)
      ct_options <- list()
      sel <- input$choosetype
      if(length(sel) == 0) sel = types
      for(ct in types) ct_options[[ct]] <- ct
      updateSelectInput(session, "choosetype", choices = ct_options, selected=sel)       
      
    })
    
    # Sliders for the root system SUF
    observe({
      if(is.null(rs$rootsystem)){return()}
      sel <- round(quantile(rs$rootsystem$suf, c(.01, .99), na.rm = T), 2)
      lim <- round(range(rs$rootsystem$suf, na.rm = T), 2)
      if(lim[1] == -Inf) lim[1] <- sel[1]
      updateSliderInput(session, "sufrange", min=lim[1], max=lim[2], value=c(sel[[1]],sel[[2]]))
    })
    
    # Sliders for the root system potentials
    observe({
      if(is.null(rs$rootsystem)){return()}
      sel <- round(quantile(rs$rootsystem$psi, c(0, 1), na.rm = T), 2)
      lim <- round(range(rs$rootsystem$psi, na.rm = T), 2)
      if(lim[1] == -Inf) lim[1] <- sel[1]
      updateSliderInput(session, "psirange", min=lim[1], max=lim[2], value=c(sel[[1]],sel[[2]]))
    }) 
    
    # Sliders for the root system axial fluxes
    observe({
      if(is.null(rs$rootsystem)){return()}
      sel <- round(quantile(rs$rootsystem$jxl, c(.01, .99), na.rm = T), 2)
      lim <- round(range(rs$rootsystem$jxl, na.rm = T), 2)
      if(lim[1] == -Inf) lim[1] <- sel[1]
      updateSliderInput(session, "jxlrange", min=lim[1], max=lim[2], value=c(sel[[1]],sel[[2]]))
    })     
    
    # Sliders for the root system radial fluxes
    observe({
      if(is.null(rs$rootsystem)){return()}
      sel <- round(quantile(rs$rootsystem$jr, c(.01, .99), na.rm = T), 2)
      lim <- round(range(rs$rootsystem$jr, na.rm = T), 2)
      if(lim[1] == -Inf) lim[1] <- sel[1]
      updateSliderInput(session, "jrrange", min=lim[1], max=lim[2], value=c(sel[[1]],sel[[2]]))
    })     
    
    
    # Get the click inside the soil graph
    observe({
      if(is.null(rs$soil)){return()}
      # Because it's a ggplot2, we don't need to supply xvar or yvar; if this
      # were a base graphics plot, we'd need those.
      sel <- nearPoints(rs$soil, input$plot2_click)
      updateTextInput(session, "x_input_soil", value=sel$psi)
      updateTextInput(session, "y_input_soil", value=sel$z)
      # paste0(sel$order, " / ", sel$type)
    }) 
    
    
    # Update the simulation with new transpiration values
    
    observeEvent(input$updateDemand, {

      rootsystem <- rs$rootsystem
      
      hydraulics <- getSUF(rootsystem, rs$conductivities, rs$soil, Psi_collar = psicollar_base * (input$psiCollar/100))
      
      rootsystem$suf <- as.vector(hydraulics$suf)
      rootsystem$jr <- as.vector(hydraulics$jr)
      rootsystem$psi <- as.vector(hydraulics$psi)
      rootsystem$suf1 <- as.vector(hydraulics$suf1)
      rootsystem$kx <- hydraulics$kx
      rootsystem$kr <- hydraulics$kr
      rootsystem$jxl <- as.vector(hydraulics$jxl)
      rootsystem$psi_soil <- as.vector(hydraulics$psi_soil)
      
      rs$rootsystem <- rootsystem
      rs$tact <- hydraulics$tact
      rs$krs <- hydraulics$krs
      rs$evol <- rbind( rs$evol, data.frame(krs = hydraulics$krs, tact = hydraulics$tact))
    })
    
    # Update the simulation with new soil values
    observeEvent(input$updateSoil, {
      soil <- rs$soil
      sel <- nearPoints(soil, input$plot2_click)
      
      rootsystem <- rs$rootsystem
      
      soil$psi[soil$id == sel$id] <- as.numeric(input$x_input_soil)
      soil$z[soil$id == sel$id] <- as.numeric(input$y_input_soil)
      
      
      hydraulics <- getSUF(rootsystem, rs$conductivities, soil, Psi_collar = psicollar_base * (input$psiCollar/100))
      
      rootsystem$suf <- as.vector(hydraulics$suf)
      rootsystem$jr <- as.vector(hydraulics$jr)
      rootsystem$psi <- as.vector(hydraulics$psi)
      rootsystem$suf1 <- as.vector(hydraulics$suf1)
      rootsystem$kx <- hydraulics$kx
      rootsystem$kr <- hydraulics$kr
      rootsystem$jxl <- as.vector(hydraulics$jxl)
      rootsystem$psi_soil <- as.vector(hydraulics$psi_soil)
      
      rs$rootsystem <- rootsystem
      rs$soil <- soil
      rs$tact <- hydraulics$tact
      rs$krs <- hydraulics$krs
      evol <- rs$evol
      rs$evol <- rbind(evol, data.frame(krs = hydraulics$krs, tact = hydraulics$tact))
    })    
    
    # Get the click inside the conductivity graph
    observe({
      if(is.null(rs$conductivities)){return()}
      # Because it's a ggplot2, we don't need to supply xvar or yvar; if this
      # were a base graphics plot, we'd need those.
      temp <- filter(rs$conductivities, order == input$roottype1)
      sel <- nearPoints(temp, input$plot1_click)
      updateTextInput(session, "x_input", value=sel$x)
      updateTextInput(session, "y_input", value=sel$y)
      # paste0(sel$order, " / ", sel$type)
    })
    
    
    
    observeEvent(input$updateCond, {
      temp <- filter(rs$conductivities, order == input$roottype1)
      sel <- nearPoints(temp, input$plot1_click)
      
      conds <- rs$conductivities
      rootsystem <- rs$rootsystem
      
      conds$x[conds$id == sel$id] <- as.numeric(input$x_input)
      conds$y[conds$id == sel$id] <- as.numeric(input$y_input)

      
      hydraulics <- getSUF(rootsystem, conds, rs$soil, Psi_collar = psicollar_base * (input$psiCollar/100))

      rootsystem$suf <- as.vector(hydraulics$suf)
      rootsystem$jr <- as.vector(hydraulics$jr)
      rootsystem$psi <- as.vector(hydraulics$psi)
      rootsystem$suf1 <- as.vector(hydraulics$suf1)
      rootsystem$kx <- hydraulics$kx
      rootsystem$kr <- hydraulics$kr
      rootsystem$jxl <- as.vector(hydraulics$jxl)
      rootsystem$psi_soil <- as.vector(hydraulics$psi_soil)
      
      rs$tact <- hydraulics$tact
      rs$rootsystem <- rootsystem
      rs$conductivities <- conds
      rs$krs <- hydraulics$krs
      rs$evol <- rbind(rs$evol, data.frame(krs = rs$krs, tact = rs$tact))
    })
      
    
    # For the root paramerers
    observe({
      if(is.null(rs$dataset)){return()}
        dataset <- rs$dataset
        params <- rs$params
        
        sel1 <- input$roottype
        sel2 <- input$parameter
        if(grepl("Please", sel1)) sel1 = unique(dataset$name)[1]
        if(grepl("Please", sel2)) sel2 = unique(params$name)[1]
        
        updateSelectInput(session, "roottype", choices = unique(dataset$name), selected = sel1)
        updateSelectInput(session, "roottype1", choices = unique(dataset$name), selected = sel1)
        
        ps <- unique(dataset$param)#[dataset$name == input$roottype]
        remove <- c("color", "successors", "successorP", "gf", "tropism")
        ps <- ps[!ps %in% remove]
        ps <- params$name[params$id %in% ps]
        updateSelectInput(session, "parameter", choices = ps, selected = sel2)
        
        
        current <- round(as.numeric(dataset$val1[dataset$name == input$roottype & dataset$param == params$id[params$name == input$parameter]]), 2)
        if(length(current) == 0) current <- 0
        newMin <- 0
        newMax <- current * 2
        if(newMax == 0) newMax <- 1
        updateSliderInput(session, "value", value = current, min = newMin, max = newMax, step = current/10)

        current2 <- round(as.numeric(dataset$val2[dataset$name == input$roottype & dataset$param == params$id[params$name == input$parameter]]), 2)
        current2 <- (current2/current) * 100
        if(length(current2) == 0) current <- 0
        updateSliderInput(session, "stdev", value = current2, min = 0, max = 50, step = 5)        
    })
    
    
    output$littTitle <- renderUI( {
      if(is.null(rs$litt)){return()}
      strong(rs$litt$title[rs$litt$name == input$dataset])
    }) 
    
    output$littAuth <- renderUI( {
      if(is.null(rs$litt)){return()}
      rs$litt$author[rs$litt$name == input$dataset]
    }) 
    
    output$littRef <- renderUI( {
      if(is.null(rs$litt)){return()}
      litt <- rs$litt[rs$litt$name == input$dataset,]
      paste0(litt$journal, ", ", litt$volume, ", ", litt$pages, ", ", litt$year)
    })     
    
    output$doi <- renderUI( {
      if(is.null(rs$litt)){return()}
      litt <- rs$litt
      link <- paste0("http://dx.doi.org/", litt$doi[litt$name == input$dataset])
      a("View paper", href=link, target="_blank")
    }) 
    
    output$paramTitle <- renderUI( {
      if(is.null(rs$params)){return()}
      params <- rs$params
      params$name[params$name == input$parameter]
    })     
    output$paramText <- renderUI( {
      if(is.null(rs$params)){return()}
      params <- rs$params
      params$text[params$name == input$parameter]
    })  
    output$plantText <- renderUI( {
      if(is.null(rs$params)){return()}
      params <- rs$params
      params$text[params$name == input$parameter2]
    })  
    output$plantTitle <- renderUI( {
      if(is.null(rs$params)){return()}
      params <- rs$params
      params$name[params$name == input$parameter2]
    })      
    
    # For the plant paramerers
    observe({
      if(is.null(rs$plant)){return()}
      dataset <- rs$plant
      params <- rs$params
      params <- params[params$id %in% unique(dataset$param),]
      sel <- input$parameter2
      if(grepl("Please", sel)) sel = unique(params$param)[1]
      
      ps <- unique(dataset$param)
      ps <- params$name[params$id %in% ps]
      
      updateSelectInput(session, "parameter2", choices = ps, selected = sel)
      current <- round(as.numeric(dataset$val1[dataset$param == params$id[params$name == input$parameter2]]), 2)
      if(length(current) == 0) current <- 0
      newMin <- 0
      newMax <- current * 2
      if(newMax == 0) newMax <- 1
      updateSliderInput(session, "value2", value = current, min = newMin, max = newMax, step = current/10)
    })    

    
    #------------------------------------------------------
    # PROCESS THE DATA
    
    
    observe({
      
      if(is.null(rs$rootsystem)){
        ## READ THE PARAMETER FILE AND STORE THE DATA IN A DATAFRAME
        file.copy(from=paste0("www/modelparameter/Zea_maize.rparam"), to="www/param.rparam", overwrite = T)
        file.copy(from=paste0("www/modelparameter/Zea_maize.pparam"), to="www/param.pparam", overwrite = T)
        fileName <- 'www/param.rparam'
        param <- read_file(fileName)
        
        param <- strsplit(param, "#")
        dataset <- NULL
        for(k in c(2:length(param[[1]]))){
          spl <- strsplit(param[[1]][k], "\n")
          type <- ""
          name <- ""
          for(i in c(1:length(spl[[1]]))){
            temp <- spl[[1]][i]
            pos <- regexpr("//", temp)
            if(pos != -1) temp <- substr(temp, 0, pos-1)
            if(nchar(temp) > 0){
              temp <- strsplit(temp, "\t")
              temp2 <- data.frame("type" = character(0), "name" = character(0), 
                                  "param" = character(0), "val1" = numeric(0), 
                                  "val2" = numeric(0), "val3" = numeric(0), stringsAsFactors = F)
              
              if(temp[[1]][1] == "type"){ type <- temp[[1]][2]
              } else if(temp[[1]][1] == "name"){ name <- temp[[1]][2]
              } else if(grepl("Param", temp[[1]][1])){
              } else if(temp[[1]][1] == "tropism") {
                temp2[[1,3]] <- "n_tropism"
                temp2$val1 <- temp[[1]][3]
                temp2$type <- type
                temp2$name <- name
                dataset <- rbind(dataset, temp2)
                temp2$param <- "sigma_tropism"
                temp2$val1 <- temp[[1]][4]
                temp2$type <- type
                temp2$name <- name
                dataset <- rbind(dataset, temp2)  
                temp2$param <- "tropism"
                temp2$val1 <- temp[[1]][2]
                temp2$type <- type
                temp2$name <- name
                dataset <- rbind(dataset, temp2)  
              } else {
                for(j in c(1:4)){
                  temp2[[1,j+2]] <- temp[[1]][j]
                  temp2$type <- type
                  temp2$name <- name
                }
                dataset <- rbind(dataset, temp2)
              }
            }
          }
        }        
        
  
        ## READ THE PARAMETER FILE AND STORE THE DATA IN A DATAFRAME
        fileName <- 'www/param.pparam'
        data <- read_file(fileName)
        # READ THE PARAMETER FILE AND STORE THE DATA IN A DATAFRAME
        plant <- NULL
        spl <- strsplit(data, "\n")
        for(i in c(1:length(spl[[1]]))){
          temp <- spl[[1]][i]
          if(nchar(temp) > 0){
            temp <- strsplit(temp, "\t")
            temp2 <- data.frame( "param" = character(0), "val1" = numeric(0), stringsAsFactors = F)
            for(j in c(1:2)){
              temp2[[1,j]] <- temp[[1]][j]
            }
            plant <- rbind(plant, temp2)
          }
        }      
        
        colnames(plant) <- c("param", "val1")      
        
        
        fileName <- 'www/params.txt'
        params <- read.table(fileName, sep="\t", stringsAsFactors = F)
        colnames(params) <- c("id", "name", "text")            
  
        # setwd("www/")
        if(Sys.info()['sysname'] == "Darwin"){
          system("chmod 777 www/a-mac.out")
          system("www/a-mac.out")  
        }else{
          system("chmod 777 www/a.out")
          system("www/a.out")  
        }
        rootsystem <- fread("www/rootsystem.txt", header = T)
        # rootsystem2 <- fread("www/rootsystem2.txt", header = T)
        conductivities <- read_csv("www/conductivities.csv")
        
        
        orders <- unique(conductivities$order)
        ids <- unique(conductivities$order_id)
        rootsystem$name <- "root"
        for(o in c(1:length(orders))){
          rootsystem$name[rootsystem$type == ids[o]] <- orders[o]
        }
        
        
        first <- rootsystem[rootsystem$node1ID == 0,]
        nodals_ids <- unique(rootsystem$branchID[rootsystem$type == 4 | rootsystem$type == 5])
        for(no in nodals_ids){
          temp <- rootsystem[rootsystem$branchID == no][1]
          # rootsystem$node1ID[rootsystem$branchID == no][1] <- 0
          #
          connection <- data.frame(node1ID = 0,
                                   node2ID = temp$node1ID,
                                   branchID = temp$branchID,
                                   x1 = first$x1, y1 = first$y1, z1 = first$z1,
                                   x2 = temp$x1, y2 = temp$y1, z2 = temp$z1,
                                   radius = temp$radius,
                                   length = sqrt((first$x1-temp$x1)^2 + (first$y1-temp$y1)^2 + (first$z1-temp$z1)^2 ),
                                   R = 0, G = 0, B = 0,
                                   time = temp$time,
                                   type = temp$type,
                                   name = temp$name)
          rootsystem <- rbind(rootsystem, connection)
        }
        rootsystem <- rootsystem[order(rootsystem$node2ID, decreasing = F),]
  
        
        
        # setwd("../")
        
        soil <- read_csv("www/soil.csv")
        
        hydraulics <- getSUF(rootsystem, conductivities, soil, hetero = F, Psi_collar = psicollar_base * (input$psiCollar/100))
        
  
        rootsystem$suf <- as.vector(hydraulics$suf)
        rootsystem$suf1 <- as.vector(hydraulics$suf1)
        rootsystem$kx <- hydraulics$kx
        rootsystem$kr <- hydraulics$kr
        rootsystem$jr <- as.vector(hydraulics$jr)
        rootsystem$psi <- as.vector(hydraulics$psi)
        rootsystem$jxl <- as.vector(hydraulics$jxl)
        rootsystem$psi_soil <- as.vector(hydraulics$psi_soil)
        
        rs$conductivities <- conductivities
        rs$rootsystem <- rootsystem
        rs$dataset <- dataset
        rs$plant <- plant
        rs$params <- params
        rs$krs <- hydraulics$krs
        rs$krs_first <- hydraulics$krs
        rs$tact <- hydraulics$tact
        rs$tact_first <- hydraulics$tact
        rs$soil <- soil
        rs$evol <- data.frame(krs = rs$krs, tact = rs$tact)
      }
    })
    
    
    
        
    observeEvent(input$updateParams, {
    # observe({
        
        if(is.null(rs$dataset)) return()
      
        ## READ THE PARAMETER FILE AND STORE THE DATA IN A DATAFRAME
        dataset <- rs$dataset
        
        ## WRITE BACK THE PARAMETERSET
        
        params <- rs$params
        ps <- params$id[params$name == input$parameter]
        
        dataset$val1[dataset$name == input$roottype & dataset$param == ps] <- input$value
        dataset$val2[dataset$name == input$roottype & dataset$param == ps] <- (input$stdev/100) * input$value
        
        message((input$stdev/100) * input$value)
        
        types <- unique(dataset$type)
        text <- NULL
        for(t in types){
          if(is.null(text)){text <- "# Parameter set for type"
          }else{
            text <- paste(text, "# Parameter set for type", sep="\n")
          }
          
          temp <- dataset[dataset$type == t,]
          
          str <- paste("type", temp$type[1], sep="\t")
          text <- paste(text, str, sep="\n")
          
          str <- paste("name", temp$name[1], sep="\t")
          text <- paste(text, str, sep="\n")
          
          for(i in c(1:nrow(temp))){
            if(temp[i, 3] == "n_tropism"){
              str <- paste("tropism", temp[i+2, 4], temp[i, 4], temp[i+1, 4], sep="\t")
              text <- paste(text, str, sep="\n")
            }else if(temp[i, 3] == "sigma_tropism" | temp[i, 3] == "tropism"){
            }else if(temp[i, 3] == "dx"){
              str <- paste(temp[i, 3], temp[i, 4], sep="\t")
              text <- paste(text, str, sep="\n")
            }else{
              str <- paste(temp[i, 3], temp[i, 4], temp[i, 5], temp[i, 6], sep="\t")
              text <- paste(text, str, sep="\n")
            }
          }
          
        }
        text <- gsub("\tNA", "", text)
        cat(text, file="www/param.rparam")
        
        
        ## READ THE PARAMETER FILE AND STORE THE DATA IN A DATAFRAME
        plant <- rs$plant
        # WRITE THE NEW PARAMETER FILE
        ps <- params$id[params$name == input$parameter2]
        plant$val1[plant$param == ps] <- input$value2
        text <- NULL
        for(i in c(1:nrow(plant))){
          str <- paste(plant[i, 1], plant[i, 2], sep="\t")
          text <- paste(text, str, sep="\n")
        }
        
        text <- gsub("\tNA", "", text)

        cat(text, file="www/param.pparam")

        # setwd("www/")
        if(Sys.info()['sysname'] == "Darwin"){
          system("www/a-mac.out")  
        }else{
          system("chmod 777 www/a.out")
          system("www/a.out")  
        }        
        rootsystem <- fread("www/rootsystem.txt", header = T)
        
        orders <- unique(rs$conductivities$order)
        ids <- unique(rs$conductivities$order_id)
        rootsystem$name <- "root"
        for(o in c(1:length(orders))){
          rootsystem$name[rootsystem$type == ids[o]] <- orders[o]
        }
        
        
        first <- rootsystem[rootsystem$node1ID == 0,]
        nodals_ids <- unique(rootsystem$branchID[rootsystem$type == 4 | rootsystem$type == 5])
        for(no in nodals_ids){
          temp <- rootsystem[rootsystem$branchID == no][1]
          # rootsystem$node1ID[rootsystem$branchID == no][1] <- 0
          #
          connection <- data.frame(node1ID = 0,
                                   node2ID = temp$node1ID,
                                   branchID = temp$branchID,
                                   x1 = first$x1, y1 = first$y1, z1 = first$z1,
                                   x2 = temp$x1, y2 = temp$y1, z2 = temp$z1,
                                   radius = temp$radius,
                                   length = sqrt((first$x1-temp$x1)^2 + (first$y1-temp$y1)^2 + (first$z1-temp$z1)^2 ),
                                   R = 0, G = 0, B = 0,
                                   time = temp$time,
                                   type = temp$type,
                                   name = temp$name)
          rootsystem <- rbind(rootsystem, connection)
        }
        rootsystem <- rootsystem[order(rootsystem$node2ID, decreasing = F),]
        

        hydraulics <- getSUF(rootsystem, rs$conductivities, rs$soil, Psi_collar = psicollar_base * (input$psiCollar/100))
        
        rootsystem$suf <- as.vector(hydraulics$suf)
        rootsystem$suf1 <- as.vector(hydraulics$suf1)
        rootsystem$kx <- hydraulics$kx
        rootsystem$kr <- hydraulics$kr
        rootsystem$jr <- as.vector(hydraulics$jr)
        rootsystem$psi <- as.vector(hydraulics$psi)
        rootsystem$jxl <- as.vector(hydraulics$jxl)
        rootsystem$psi_soil <- as.vector(hydraulics$psi_soil)
        
        
        # Read the conductivity file
        rs$rootsystem <- rootsystem
        rs$dataset <- dataset
        rs$plant <- plant
        rs$krs <- hydraulics$krs
        rs$tact <- hydraulics$tact
        evol <- rs$evol
        rs$evol <- rbind(evol, data.frame(krs = rs$krs, tact = rs$tact))
    })
    
    
    

    
    
    # ----------------------------------------------------------------
    # PLOT THE ROOT SYSTEM
    # ----------------------------------------------------------------

    output$rootConductivities <- renderPlot({
      
      plot <- ggplot() +  theme_classic()
      if(is.null(rs$conductivities)){return(plot)}
      
      temp <- filter(rs$conductivities, order == input$roottype1) 
      temp$x[temp$x > 50] <- 50
      
      pl <- ggplot(temp, aes(x, y, colour=type)) + 
        geom_line(size=2) + 
        geom_point(size = 4) + 
        geom_point(colour="white") +
        # geom_hline(data=cond_range, aes(yintercept = value)) +
        theme_classic() + 
        xlab("Distance from the tip (cm)") + 
        ylab("Conductivity / conductance") + 
        facet_grid(type~., scales = "free") +
        theme(text = element_text(size=14),
              panel.background = element_rect(fill = "transparent"), # or theme_blank()
              plot.background = element_rect(fill = "transparent")
        )
      pl
    }, bg="transparent")
    
    
    
    

    # Plot the evolution between simulations
    
    output$evolPlot <- renderPlot({

      plot <- ggplot() +  theme_classic()
      if(is.null(rs$evol)){return(plot)}

      temp <- rs$evol
      temp$id <- c(1:nrow(temp))
      if(input$chooseEvol == "krs"){
        temp$var <- temp[[input$chooseEvol]] / rs$krs_first
      }else{
        temp$var <- temp[[input$chooseEvol]] / rs$tact_first
      }

      pl <- ggplot(temp, aes(id, var, colour=id)) +
        geom_line(size=2) +
        geom_point(size = 4) +
        geom_point(colour="white") +
        theme_classic() +
        ylab("Value") +
        xlab("Simualution") +
        theme(text = element_text(size=14),
              panel.background = element_rect(fill = "transparent"), # or theme_blank()
              plot.background = element_rect(fill = "transparent"),
              axis.text.x = element_text(angle = 45, hjust = 1)
        )
      pl
    }, bg="transparent")
    
    
    #Plot the soil profile    
    output$soilPlot <- renderPlot({
      
      plot <- ggplot() +  theme_classic()
      if(is.null(rs$soil)){return(plot)}
      
      pl <- ggplot(rs$soil, aes(z, psi, colour=psi)) + 
        geom_line(size=2) + 
        geom_point(size = 4) + 
        geom_point(colour="white") +
        theme_classic() + 
        ylab("Soil water potential") + 
        xlab("Depth [cm]") + 
        coord_flip()+
        theme(text = element_text(size=14),
              panel.background = element_rect(fill = "transparent"), # or theme_blank()
              plot.background = element_rect(fill = "transparent"),
              axis.text.x = element_text(angle = 45, hjust = 1)
        )
      pl
    }, bg="transparent")    
      
    
    # Plot the root system
    
    output$rootPlot <- renderPlot({
      
      plot <- ggplot() +  theme_classic()
      if(is.null(rs$rootsystem)){return(plot)}
      
      mydata <- rs$rootsystem

      mydata <- mydata[mydata$name %in% input$choosetype,]
      
      soil <- ddply(mydata, .(round(z2)), summarise, psi = mean(psi_soil))
      soil$z <- soil[,1]
      soil$x <- min(mydata$x1) - 5
      
      plot <- plot +
        geom_point(data = soil, aes(x, z, fill=psi), shape=22, size=4, colour="white") + 
        scale_fill_gradientn(colours = cscale3, 
                               name = "Soil water potential [hPa]",
                               limits = range(soil))
        
      if(input$plotroottype == 1){
        plot <- plot + 
        geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, colour=name), alpha=0.9, size=1.2)
      
      }else if(input$plotroottype == 2){
        plot <- plot + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, 
                                          colour=suf), alpha=0.9, size=1.2) +
          scale_colour_gradientn(colours=rev(heat.colors(10)), 
                                 name = "Standart uptake fraction [log]",
                                 limits = input$sufrange) 
      
      }else if(input$plotroottype == 3){
        plot <- plot + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, 
                                          colour=psi), alpha=0.9, size=1.2) +
          scale_colour_gradientn(colours=cscale3, 
                                 name = "Water potential",
                                 limits = input$psirange) 
      
      }else if(input$plotroottype == 4){
        plot <- plot + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, 
                                          colour=jxl), alpha=0.9, size=1.2) +
          scale_colour_gradientn(colours=cscale3, 
                                 name = "Axial fluxes",
                                 limits = input$jxlrange) 
      
      }else if(input$plotroottype == 5){
        plot <- plot + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, 
                                          colour=jr), alpha=0.9, size=1.2) +
          scale_colour_gradientn(colours=cscale3, 
                                 name = "Radial fluxes",
                                 limits = input$jrrange)         
      
      }else if(input$plotroottype == 6){
        plot <- plot + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, 
                                          colour=kr), alpha=0.9, size=1.2) +
          scale_colour_gradientn(colours=cscale3, 
                                 name = "Radial conductivity") 
      
      }else if(input$plotroottype == 7){
        plot <- plot + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, 
                                          colour=kx), alpha=0.9, size=1.2) +
          scale_colour_gradientn(colours=cscale3, 
                                 name = "Axial conductance") 
      }
      plot <- plot + coord_fixed() +
        ylab("Depth (cm)") 
        
      rs$plot <- plot
      
      plot
    })
    
    
    
    
    # ----------------------------------------------------------------
    # PLOT THE DENSITY
    # ----------------------------------------------------------------
    
    
    output$densityPlot <- renderPlot({
      
      plot <- ggplot() +  theme_classic()
      if(is.null(rs$rootsystem)){return(plot)}
      
      mydata <- rs$rootsystem
      #mydata$length = sqrt((mydata$x1-mydata$x2)^2 + (mydata$y1-mydata$y2)^2 + (mydata$z1-mydata$z2)^2 )
      mydata$z1 <- round(mydata$z1, 0)
      
      if(input$plotdensitytype == 1){
        dens <- ddply(mydata, .(z1, name), summarise, root = sum(length))  
        yl <- "total root length (cm)" 
      }else if(input$plotdensitytype == 2){
        dens <- ddply(mydata, .(z1, name), summarise, root = sum(suf1))
        yl <- "standart uptake fraction"
      }else if(input$plotdensitytype == 3){
        dens <- ddply(mydata, .(z1, name), summarise, root = sum(jr))
        yl <- "Radial flow"
      }else if(input$plotdensitytype == 4){
        dens <- ddply(mydata, .(z1, name), summarise, root = sum(jxl))
        yl <- "Axial flow"
      }else if(input$plotdensitytype == 5){
        dens <- ddply(mydata, .(z1, name), summarise, root = mean(psi))
        yl <- "Mean water potential"
      }
      
      
      
      plot1 <- ggplot(data = dens, aes(x = z1, y = root, colour=name)) +  
        theme_classic() + 
        geom_line(data = dens, aes(x = z1, y = root, colour=name), alpha=0.5) + 
        stat_smooth(se=F) + 
        coord_flip() +
        xlab("depth (cm)") +
        ylab(yl)
      
      plot1
    })    
    
    
    
    # ----------------------------------------------------------------
    # Downlaod the parameters
    # ----------------------------------------------------------------
    
    # downloadHandler() takes two arguments, both functions.
    # The content function is passed a filename as an argument, and
    #   it should write out data to that filename.
    output$downloadParams <- downloadHandler(
      
      # if(is.null(rs$dataset)){return()}
      # This function returns a string which tells the client
      # browser what name to use when saving the file.
      filename = function() {
        # paste(input$dataset, input$filetype, sep = ".")
        "param.rparams"
      },
      
      # This function should write data to a file given to it by
      # the argument 'file'.
      content = function(file) {

        dataset <- rs$dataset
        
        ## WRITE BACK THE PARAMETERSET
        
        dataset$val1[dataset$name == input$roottype & dataset$param == input$parameter] <- input$value
        
        types <- unique(dataset$type)
        
        text <- NULL
        for(t in types){
          if(is.null(text)){text <- "# Parameter set for type"
          }else{
            text <- paste(text, "# Parameter set for type", sep="\n")
          }
          temp <- dataset[dataset$type == t,]
          
          str <- paste("type", temp$type[1], sep="\t")
          text <- paste(text, str, sep="\n")
          
          str <- paste("name", temp$name[1], sep="\t")
          text <- paste(text, str, sep="\n")
          
          for(i in c(1:nrow(temp))){
            str <- paste(temp[i, 3], temp[i, 4], temp[i, 5], temp[i, 6], sep="\t")
            text <- paste(text, str, sep="\n")
          }
          
        }
        text <- gsub("\tNA", "", text)
        cat(text, file=file)        
        
      }
    )
    

    
    # ----------------------------------------------------------------
    # Downlaod the plot
    # ----------------------------------------------------------------
    
    # downloadHandler() takes two arguments, both functions.
    # The content function is passed a filename as an argument, and
    #   it should write out data to that filename.
    output$downloadPlot <- downloadHandler(
      
      # if(is.null(rs$dataset)){return()}
      # This function returns a string which tells the client
      # browser what name to use when saving the file.
      filename = function() {
        # paste(input$dataset, input$filetype, sep = ".")
        paste0(input$dataset, ".png")
      },
      
      # This function should write data to a file given to it by
      # the argument 'file'.
      content = function(file) {
        mydata <- rs$rootsystem
        
        # mydata <- rootsystem
        
        plot <- ggplot() +  theme_classic() + 
          geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2, colour=factor(type)), alpha=0.9) +
          # geom_segment(data = mydata, aes(x = x1, y = z1, xend = x2, yend = z2)) + 
          coord_fixed() +

          ylab("Depth (cm)")
        # ylab("") 
        
        if(input$bwfig) plot <- plot + scale_colour_grey()
        
        plot + ggsave(file, height = 10, width = 10, bg="transparent")
      }
    )      
        
    # ----------------------------------------------------------------
    # Downlaod the data
    # ----------------------------------------------------------------
    
    # downloadHandler() takes two arguments, both functions.
    # The content function is passed a filename as an argument, and
    #   it should write out data to that filename.
    output$downloadRSML <- downloadHandler(
      
      # if(is.null(rs$dataset)){return()}
      # This function returns a string which tells the client
      # browser what name to use when saving the file.
      filename = function() {
        # paste(input$dataset, input$filetype, sep = ".")
        paste0(input$dataset, ".rsml")
      },
      
      # This function should write data to a file given to it by
      # the argument 'file'.
      content = function(file) {
        
        rsml <- read_file("www/rootsystem.rsml")
        cat(rsml, file=file)
        
      }
    )  
    
    # ----------------------------------------------------------------
    # Downlaod the data
    # ----------------------------------------------------------------
    
    # downloadHandler() takes two arguments, both functions.
    # The content function is passed a filename as an argument, and
    #   it should write out data to that filename.
    output$downloadCSV <- downloadHandler(
      
      # if(is.null(rs$dataset)){return()}
      # This function returns a string which tells the client
      # browser what name to use when saving the file.
      filename = function() {
        # paste(input$dataset, input$filetype, sep = ".")
        paste0(input$dataset, ".txt")
      },
      
      # This function should write data to a file given to it by
      # the argument 'file'.
      content = function(file) {
        
        rsml <- read_file("www/rootsystem.txt")
        cat(rsml, file=file)
        
      }
    )  
    
    # ----------------------------------------------------------------
    # Downlaod the data
    # ----------------------------------------------------------------
    
    # downloadHandler() takes two arguments, both functions.
    # The content function is passed a filename as an argument, and
    #   it should write out data to that filename.
    output$downloadVTP <- downloadHandler(
      
      # if(is.null(rs$dataset)){return()}
      # This function returns a string which tells the client
      # browser what name to use when saving the file.
      filename = function() {
        # paste(input$dataset, input$filetype, sep = ".")
        paste0(input$dataset, ".vtp")
      },
      
      # This function should write data to a file given to it by
      # the argument 'file'.
      content = function(file) {
        
        rsml <- read_file("www/rootsystem.vtp")
        cat(rsml, file=file)
        
      }
    )
    
    
    output$table_results <- renderTable({
      if (is.null(rs$rootsystem)) { return()}
      mydata <- rs$rootsystem
      mydata$length = sqrt((mydata$x1-mydata$x2)^2 + (mydata$y1-mydata$y2)^2 + (mydata$z1-mydata$z2)^2 )
      
      temp <- data.frame("Metric" = character(), "Value"=numeric(),"Unit" = character(), stringsAsFactors = F)
      temp[1,] <- c("Total root length", round(sum(mydata$length)), "[cm]")
      temp[2,] <- c("Number of roots segments", length(mydata$length), "[-]")
      temp[3,] <- c("Maximal depth", round(-min(mydata$z1)), "[cm]")
      
      
      p1 <- as.numeric(as.character(rs$krs))
      p1 <- round(p1, regexpr('[1-9]', p1)[[1]]) 
      temp[4,] <- c("Krs", p1, "[-]")
      
      p1 <- as.numeric(as.character(rs$tact))
      p1 <- round(p1, regexpr('[1-9]', p1)[[1]]) 
      temp[5,] <- c("T_act", p1, "[-]")
      
      temp
    })  
    
    
    
    
  }
)