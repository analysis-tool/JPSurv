#### More functions requested for JPSurv web app new features (discussed in meeting 06/05/2019)


#########################################################################################################
# download.data: a function that returns a merged data set for download including 
# - the selected cohort input data
# - the accompanying data for plot.surv.year/plot.dying.year
# arguments:
# input - input dataset read in by function joinpoint.seerdata.
# fit - joinpoint object containing the model output.
# nJP - the number of joinpoints in the model.
# yearvar - the variable name for year of diagnosis used in argument 'year' of the function joinpoint.
# type - two options for this argument: "graph" for graph data and "full" for full data.
# subset - an optional string specifying a subset of observations used in the fitting process.
# interval - the variable name for year since diagnosis. The default is 'Interval'.
# int.select - the interval values selected for the plot if the downloadtype="graph". The default is NULL.
#########################################################################################################

download.data<-function(input,fit,nJP,yearvar,downloadtype,subset=NULL,interval="Interval",int.select=NULL){
  input.sub<-subset(input,eval(parse(text=subset)))
  if(downloadtype=="graph"){
    output.sub<-fit$FitList[[nJP+1]]$predicted
    if(!is.null(int.select)){
      output.sub<-output.sub[which(output.sub[,interval] %in% int.select),]
    }
  }else if(downloadtype=="full"){
    output.sub<-fit$FitList[[nJP+1]]$fullpredicted
  }else{
    print("There is no such type of data for download. Please define the type using either 'graph' or 'full'.")
  }
  yearint.input<-paste(input.sub[,yearvar],input.sub[,interval],sep="_")
  yearint.output<-paste(output.sub[,yearvar],output.sub[,interval],sep="_")
  rows.match<-match(yearint.output,yearint.input)
  cols.input<-colnames(input.sub)
  del.cols<-c("Page_type","Observed_SE_Interval","Observed_SE_Cum")
  cols.input<-cols.input[-which(cols.input %in% del.cols)]
  cols.output<-colnames(output.sub)
  merge.sub<-output.sub
  merge.sub[,cols.input]<-input.sub[rows.match,cols.input]
  colnames(merge.sub)[which(colnames(merge.sub)=="pred_int")]<-"Predicted_Survival_Int"
  colnames(merge.sub)[which(colnames(merge.sub)=="pred_cum")]<-"Predicted_Survival_Cum"
  colnames(merge.sub)[which(colnames(merge.sub)=="pred_int_se")]<-"Predicted_Survival_Int_SE"
  colnames(merge.sub)[which(colnames(merge.sub)=="pred_cum_se")]<-"Predicted_Survival_Cum_SE"
  merge.sub[,"Predicted_ProbDeath_Int"]<-1-merge.sub$Predicted_Survival_Int
  merge.sub[,"Predicted_ProbDeath_Int_SE"]<-merge.sub$Predicted_Survival_Int_SE
  cols.pred<-c("Predicted_Survival_Int","Predicted_ProbDeath_Int","Predicted_Survival_Cum",
              "Predicted_Survival_Int_SE","Predicted_Survival_Cum_SE","Predicted_ProbDeath_Int_SE")
  merge.data<-merge.sub[,c(cols.input,cols.pred)]
  if(downloadtype=="full"){
    merge.data[,yearvar]<-output.sub[,yearvar]
    merge.data[,interval]<-output.sub[,interval]
    subset.list<-strsplit(subset, " & ")
    subset.list[[1]]<-subset.list[[1]][which(grepl("==", subset.list[[1]])==T)]
    cohort.list<-strsplit(subset.list[[1]], "==")
    cohort.vars<-sapply(cohort.list, "[", 1)
    cohort.vars<-gsub(" ","",cohort.vars)
    cohort.values<-sapply(cohort.list, "[", 2)
    cohort.values<-gsub(" ","",cohort.values)
    cohort.vars<-cohort.vars[which(!cohort.vars %in% c(yearvar,interval))]
    cohort.values<-cohort.values[which(!cohort.vars %in% c(yearvar,interval))]
    merge.data[,cohort.vars]<-t(replicate(dim(merge.data)[1],cohort.values))
  }
  merge.data[,yearvar]<-as.numeric(merge.data[,yearvar])
  return(merge.data)
}

#########################################################################################################
# plot.dying.year.annotate: a function that returns a plot for Percent Change in the Annual Probability of
# Dying of Cancer by Diagnosis year using ggplot
# The annotation feature is available for nJP<=3 and the number of multiple intervals selected <=3
# arguments:
# plotdata - the graph data returned by function download.data with downloadtype="graph".
# fit - joinpoint object containing the model output.
# nJP - the number of joinpoints in the model.
# yearvar - the variable name for year of diagnosis used in argument 'year' of the function joinpoint.
# obsintvar - the variable name for observed interval survival. The default is "Relative_Survival_Interval"
#             for relative survival data. For cause-specific data, it needs to be changed accordingly.
# predintvar - the variable name for predicted interval survival. The default is "Predicted_ProbDeath_Int".
# interval - the variable name for year since diagnosis. The default is 'Interval'.
# annotation - the indicator for the annotation feature. The default is 0 (no annotation on the plot).Two plots
#              with and without annotation will be returned in a list when annotation=1.
# topanno - the indicator for showing the top curve annotation. The default is 1 (annotation for the top curve).
# trend - the indicator for returning the trend measure tables. The default is 0 (no trend tables returned).
#########################################################################################################

### define a plot function for Percent Change in the Annual Probability of Dying of Cancer by Diagnosis year with annotations
plot.dying.year.annotate<-function(plotdata,fit,nJP,yearvar,obsintvar="Relative_Survival_Interval",predintvar="Predicted_ProbDeath_Int",interval="Interval",annotation=0,topanno=1,trend=0){
  title.rch<-"Percent Change in the Annual Probability of Dying of Cancer \n by Diagnosis Year"
  interval.values<-as.numeric(unique(plotdata[,"Interval"]))
  interval.labels<-paste((interval.values-1)," to ",interval.values," years since diagnosis",sep="")
  if(interval.values[1]==1){
    interval.labels[1]<-"0 to 1 year since diagnosis"
  }
  trends.out<-list()
  
  if(trend==1 | annotation==1){ 
    trends.out <- aapc.multiints(fit$FitList[[nJP+1]], type="RelChgHaz", int.select=interval.values)
    if(length(interval.values)<=3 & nJP<=3){
      ### haz results are the same for all interval values
      jp.loc<-fit$FitList[[nJP+1]]$jp
      annot.strs<-paste(sprintf("%.1f",100*trends.out[[1]]$estimate),"%",sep="")
      x.values<-list()
      plotdata[,"trend.label"]<-""
      for(i in 1:length(interval.values)){
        int.i<-interval.values[i]
        haz.apc<-trends.out[[i]]
        plotdata.i<-plotdata[which(plotdata[,interval]==int.i),]
        if(max(plotdata.i[,yearvar])==max(haz.apc$end.year) | nJP==0){
          end.year<-haz.apc$end.year
          end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
          x.values.i<-1/2*(haz.apc$start.year+end.year)
        }
        if(max(plotdata.i[,yearvar])<max(haz.apc$end.year)){
          if(nJP==1){
            if(max(plotdata.i[,yearvar])>jp.loc){
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            }else{
              haz.apc<-haz.apc[1:nJP,]
              x.values.i<-1/2*(haz.apc$start.year+haz.apc$end.year)
            }
          } ## nJP=1 end
          if(nJP==2){
            if(max(plotdata.i[,yearvar])>max(jp.loc)){
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            } else if(max(plotdata.i[,yearvar])<=max(jp.loc) & max(plotdata.i[,yearvar])>min(jp.loc)){
              haz.apc<-haz.apc[1:nJP,]
              x.values.i<-1/2*(haz.apc$start.year+haz.apc$end.year)
            } else{
              haz.apc<-haz.apc[1:(nJP-1),]
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            }
          } ## nJP=2 end
          if(nJP==3){
            if(max(plotdata.i[,yearvar])>max(jp.loc)){
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            } else if(max(plotdata.i[,yearvar])<=max(jp.loc) & max(plotdata.i[,yearvar])>jp.loc[2]){
              haz.apc<-haz.apc[1:nJP,]
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            } else if(max(plotdata.i[,yearvar])<=jp.loc[2] & max(plotdata.i[,yearvar])>=jp.loc[1]){
              haz.apc<-haz.apc[1:(nJP-1),]
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            } else {
              haz.apc<-haz.apc[1:(nJP-2),]
              end.year<-haz.apc$end.year
              end.year[length(haz.apc$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(haz.apc$start.year+end.year)
            }
          } ## nJP=3 end
        } 
        x.values[[i]]<-round(x.values.i)
        plotdata$trend.label[which((plotdata[,yearvar] %in% x.values[[i]]) & plotdata[,interval]==interval.values[[i]])]<-annot.strs
      }## interval.values iteration end
      if(annotation==1){
        hues=seq(15,375,length=length(interval.values)+1)
        gg_color_hue<-hcl(h=hues,l=65,c=100)[1:length(interval.values)]
        if(topanno==1){
          ymeans.byint<-aggregate(plotdata[,"Predicted_ProbDeath_Int"], list(plotdata[,interval]), mean)
          topint<-which(ymeans.byint[,2]==max(ymeans.byint[,2]))
          plotdata$trend.label[which(plotdata[,interval]!=interval.values[topint])]<-""
          plot<-ggplot(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predintvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval]))) + 
            geom_line(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predintvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])),linetype="solid")+
            geom_point(data=plotdata, aes(x=plotdata[,yearvar], y=1-plotdata[,obsintvar], group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])))+
            xlab('Year at diagnosis') + ylab('Annual Probability of Cancer Death (%)')+
            theme_bw()+
            ggtitle(title.rch) +
            coord_cartesian(ylim=c(0,1))+
            scale_y_continuous(breaks=seq(0,1,0.1),labels = scales::percent)+
            scale_x_continuous(breaks=seq(min(plotdata[,yearvar],na.rm=T),max(plotdata[,yearvar],na.rm=T),5))+
            scale_color_hue(labels = interval.labels)+
            theme(legend.position="bottom")+
            theme(legend.title=element_blank())+
            theme(plot.title = element_text(hjust = 0.5))+
            geom_text_repel(aes(label = trend.label),nudge_x=0.01,nudge_y=0.01,show.legend = FALSE)
        }else{
          plot<-ggplot(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predintvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval]))) + 
            geom_line(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predintvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])),linetype="solid")+
            geom_point(data=plotdata, aes(x=plotdata[,yearvar], y=1-plotdata[,obsintvar], group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])))+
            xlab('Year at diagnosis') + ylab('Annual Probability of Cancer Death (%)')+
            theme_bw()+
            ggtitle(title.rch) +
            coord_cartesian(ylim=c(0,1))+
            scale_y_continuous(breaks=seq(0,1,0.1),labels = scales::percent)+
            scale_x_continuous(breaks=seq(min(plotdata[,yearvar],na.rm=T),max(plotdata[,yearvar],na.rm=T),5))+
            scale_color_hue(labels = interval.labels)+
            theme(legend.position="bottom")+
            theme(legend.title=element_blank())+
            theme(plot.title = element_text(hjust = 0.5))+
            geom_text_repel(aes(label = trend.label),nudge_x=0.01,show.legend = FALSE)
        }
      }
    }
    if(length(interval.values)>3 | nJP>3){
      print("This annotation feature is not available when the number of joinpoints>3 or the number of multiple intervals selected>3.")
    }
  }
  plot0<-ggplot(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predintvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval]))) + 
    geom_line(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predintvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])),linetype="solid")+
    geom_point(data=plotdata, aes(x=plotdata[,yearvar], y=1-plotdata[,obsintvar], group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])))+
    xlab('Year at diagnosis') + ylab('Annual Probability of Cancer Death (%)')+
    ggtitle(title.rch) +
    coord_cartesian(ylim=c(0,1))+
    scale_y_continuous(breaks=seq(0,1,0.1),labels = scales::percent)+
    scale_x_continuous(breaks=seq(min(plotdata[,yearvar],na.rm=T),max(plotdata[,yearvar],na.rm=T),5))+
    scale_color_hue(labels = interval.labels)+
    theme(legend.position="bottom")+
    theme(legend.title=element_blank())+
    theme(plot.title = element_text(hjust = 0.5))
  
  if(!annotation %in% c(0,1)){
    print("The annontation indicator should be either 0 or 1.")
  }
  if(!topanno %in% c(0,1)){
    print("The annontation indicator for the top curve only should be either 0 or 1.")
  }
  
  if(trend==0){
    if(annotation==0 | length(interval.values)>3 | nJP>3){
      out<-plot0
    }else{
      out<-list(plot,plot0)  
    }
  }else if(trend==1){
    if(annotation==0 | length(interval.values)>3 | nJP>3){
      out<-list(trends.out,plot0)
    }else{
      out<-list(trends.out,plot,plot0)
    }
  }else{
    print("The trend indicator should be either 0 or 1.")
  }
  return(out)
}

#########################################################################################################
# plot.surv.year.annotate: a function that returns a plot for Average Change in Cumulative Survival by diagnosis year
# using ggplot
# The annotation feature is available for nJP<=3 and the number of multiple intervals selected <=3
# arguments:
# plotdata - the graph data returned by function download.data with downloadtype="graph".
# fit - joinpoint object containing the model output.
# nJP - the number of joinpoints in the model.
# yearvar - the variable name for year of diagnosis used in argument 'year' of the function joinpoint.
# obscumvar - the variable name for observed relative cumulative survival. The default is "Relative_Survival_Cum"
#             for relative survival data. For cause-specific data, it needs to be changed accordingly.
# predcumvar - the variable name for predicted cumulative survival. The default is "Predicted_Survival_Cum".
# interval - the variable name for year since diagnosis. The default is 'Interval'.
# annotation - the indicator for the annotation feature. The default is 0 (no annotation on the plot).Two plots
#              with and without annotation will be returned in a list when annotation=1.
# trend - the indicator for returning the trend measure tables. The default is 0 (no trend tables returned).
#########################################################################################################

### define a plot function for Average Change in Cumulative Survival by diagnosis year with annotations
plot.surv.year.annotate<-function(plotdata,fit,nJP,yearvar,obscumvar="Relative_Survival_Cum",predcumvar="Predicted_Survival_Cum",interval="Interval",annotation=0,trend=0){
  title.acs<-"Average Change in Cumulative Survival by Diagnosis Year"
  interval.values<-as.numeric(unique(plotdata[,interval]))
  interval.labels<-paste(interval.values,"-year Cum. Survival",sep="")
  trends.out<-list()

  if(trend==1 | annotation==1){
    trends.out <- aapc.multiints(fit$FitList[[nJP+1]], type="AbsChgSur", int.select=interval.values)
    if(length(interval.values)<=3 & nJP<=3){
      ### haz results are the same for all interval values
      jp.loc<-fit$FitList[[nJP+1]]$jp
      x.values<-list()
      annot.strs<-list()
      plotdata[,"trend.label"]<-""
      for(i in 1:length(interval.values)){
        int.i<-interval.values[i]
        cs.aaac<-trends.out[[i]]
        annot.strs[[i]]<-paste(sprintf("%.1f",100*cs.aaac$estimate),sep="")
        plotdata.i<-plotdata[which(plotdata[,interval]==int.i),]
        if(max(plotdata.i[,yearvar])==max(cs.aaac$end.year) | nJP==0){
          end.year<-cs.aaac$end.year
          end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
          x.values.i<-1/2*(cs.aaac$start.year+end.year)
        }
        if(max(plotdata.i[,yearvar])<max(cs.aaac$end.year)){
          if(nJP==1){
            if(max(plotdata.i[,yearvar])>jp.loc){
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            }else{
              cs.aaac<-cs.aaac[1:nJP,]
              x.values.i<-1/2*(cs.aaac$start.year+cs.aaac$end.year)
            }
          } ## nJP=1 end
          if(nJP==2){
            if(max(plotdata.i[,yearvar])>max(jp.loc)){
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            } else if(max(plotdata.i[,yearvar])<=max(jp.loc) & max(plotdata.i[,yearvar])>min(jp.loc)){
              cs.aaac<-cs.aaac[1:nJP,]
              x.values.i<-1/2*(cs.aaac$start.year+cs.aaac$end.year)
            } else{
              cs.aaac<-cs.aaac[1:(nJP-1),]
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            }
          } ## nJP=2 end
          if(nJP==3){
            if(max(plotdata.i[,yearvar])>max(jp.loc)){
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            } else if(max(plotdata.i[,yearvar])<=max(jp.loc) & max(plotdata.i[,yearvar])>jp.loc[2]){
              cs.aaac<-cs.aaac[1:nJP,]
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            } else if(max(plotdata.i[,yearvar])<=jp.loc[2] & max(plotdata.i[,yearvar])>=jp.loc[1]){
              cs.aaac<-cs.aaac[1:(nJP-1),]
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            } else {
              cs.aaac<-cs.aaac[1:(nJP-2),]
              end.year<-cs.aaac$end.year
              end.year[length(cs.aaac$end.year)]<-max(plotdata.i[,yearvar])
              x.values.i<-1/2*(cs.aaac$start.year+end.year)
            }
          } ## nJP=3 end
        } 
        x.values[[i]]<-round(x.values.i)
        plotdata$trend.label[which((plotdata[,yearvar] %in% x.values[[i]]) & plotdata[,interval]==interval.values[[i]])]<-annot.strs[[i]]
      }## interval.values iteration end
      if(annotation==1){
        hues=seq(15,375,length=length(interval.values)+1)
        gg_color_hue<-hcl(h=hues,l=65,c=100)[1:length(interval.values)]
        plot<-ggplot(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predcumvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval]))) + 
          geom_line(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predcumvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])),linetype="solid")+
          geom_point(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,obscumvar], group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])))+
          xlab('Year at diagnosis') + ylab('Cumulative Survival (%)')+
          theme_bw()+
          ggtitle(title.acs) +
          coord_cartesian(ylim=c(0,1))+
          scale_y_continuous(breaks=seq(0,1,0.1),labels = scales::percent)+
          scale_x_continuous(breaks=seq(min(plotdata[,yearvar],na.rm=T),max(plotdata[,yearvar],na.rm=T),5))+
          scale_color_hue(labels = interval.labels)+
          theme(legend.position="bottom")+
          theme(legend.title=element_blank())+
          theme(plot.title = element_text(hjust = 0.5))+
          geom_text_repel(aes(label = trend.label),nudge_x=0.02,nudge_y=0.01,show.legend = FALSE)
      }
    }
    if(length(interval.values)>3 | nJP>3){
      print("This annotation feature is not available when the number of joinpoints>3 or the number of multiple intervals selected>3.")
    }
  }
  plot0<-ggplot(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predcumvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval]))) + 
    geom_line(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,predcumvar],group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])),linetype="solid")+
    geom_point(data=plotdata, aes(x=plotdata[,yearvar], y=plotdata[,obscumvar], group=as.factor(plotdata[,interval]), colour=as.factor(plotdata[,interval])))+
    xlab('Year at diagnosis') + ylab('Cumulative Survival (%)')+
    theme_bw()+
    ggtitle(title.acs) +
    coord_cartesian(ylim=c(0,1))+
    scale_y_continuous(breaks=seq(0,1,0.1),labels = scales::percent)+
    scale_x_continuous(breaks=seq(min(plotdata[,yearvar],na.rm=T),max(plotdata[,yearvar],na.rm=T),5))+
    scale_color_hue(labels = interval.labels)+
    theme(legend.position="bottom")+
    theme(legend.title=element_blank())+
    theme(plot.title = element_text(hjust = 0.5))
  if(!annotation %in% c(0,1)){
    print("The annontation indicator should be either 0 or 1.")
  }
  if(trend==0){
    if(annotation==0 | length(interval.values)>3 | nJP>3){
      out<-plot0
    }else{
      out<-list(plot,plot0)  
    }
  }else if(trend==1){
    if(annotation==0 | length(interval.values)>3 | nJP>3){
      out<-list(trends.out,plot0)
    }else{
      out<-list(trends.out,plot,plot0)
    }
  }else{
    print("The trend indicator should be either 0 or 1.")
  }
  return(out)
}


#########################################################################################################
# plot.surv.int.multiyears: a function that returns a plot for Cumulative Survival by Interval supporting
# multiple selected years
# arguments:
# plotdata - 1. the graph data returned by function download.data with downloadtype="graph" and all intervals needed for int.select.
#            2. the full data returned by function download.data with downloadtype="full".
#            Either of the above would work.
# fit - joinpoint object containing the model output.
# nJP - the number of joinpoints in the model.
# yearvar - the variable name for year of diagnosis used in argument 'year' of the function joinpoint.
# obscumvar - the variable name for observed relative cumulative survival. The default is "Relative_Survival_Cum"
#             for relative survival data. For cause-specific data, it needs to be changed accordingly.
# predcumvar - the variable name for predicted cumulative survival. The default is "Predicted_Survival_Cum".
# interval - the variable name for year since diagnosis. The default is 'Interval'.
# year.select - the year values selected for the plot. The default is NULL.
#########################################################################################################

### define a plot function for Cumulative Survival by Interval
plot.surv.int.multiyears<-function(plotdata,fit,nJP,yearvar,obscumvar="Relative_Survival_Cum",predcumvar="Predicted_Survival_Cum",interval="Interval",year.select=NULL){
  year.select.str<- paste(year.select,collapse=", ",sep="")
  if(length(year.select)<=3){
    title.survint<-paste("Cumulative Survival by Interval for ",year.select.str,sep="")
  }else{
    title.survint<-"Cumulative Survival by Interval"
  }
  x.combo<-function(x){
    paste(x,collapse="_",sep="")
  }
  cohort.combo <- rep(NA,dim(plotdata)[1])
  cohort.combo <- apply(data.frame(plotdata[,1:(which(colnames(plotdata)==interval)-1)]), 1, x.combo)
  cohort.combo.int0<-(paste(unique(cohort.combo),"_00",sep=""))
  int.2d<-sprintf("%02d",plotdata[,interval])
  cohort.combo.int<-paste(cohort.combo,"_",int.2d,sep="")
  plotdata.add<-plotdata[which(plotdata[,interval]==1),]
  plotdata.add[,interval]<-0
  plotdata.add[,c(obscumvar,predcumvar)]<-1
  cols.keep<-c(colnames(plotdata)[1:which(colnames(plotdata)==interval)],obscumvar,predcumvar)
  plotdata.add[,colnames(plotdata)[which(!colnames(plotdata) %in% cols.keep)]]<-NA
  plotdata[,"cohort.combo.int"]<-cohort.combo.int
  plotdata.add[,"cohort.combo.int"]<-cohort.combo.int0
  plotdata.merge<-rbind(plotdata,plotdata.add)
  plotdata.sort<-plotdata.merge[order(plotdata.merge$cohort.combo.int),]
  
  plotdata.sub<-plotdata.sort[which((plotdata.sort[,yearvar] %in% year.select) & !is.na(plotdata.sort[,obscumvar])),]
  int.max<-max(plotdata.sub[,interval],na.rm=T)
  if(int.max<=12){
    xbreaks.by<-1
  }else{
    xbreaks.by<-2
  }
  plot<-ggplot(data=plotdata.sub, aes(x=plotdata.sub[,interval], y=plotdata.sub[,predcumvar],group=as.factor(plotdata.sub[,yearvar]), colour=as.factor(plotdata.sub[,yearvar]))) + 
    geom_line(data=plotdata.sub, aes(x=plotdata.sub[,interval], y=plotdata.sub[,predcumvar],group=as.factor(plotdata.sub[,yearvar]), colour=as.factor(plotdata.sub[,yearvar])),linetype="solid")+
    geom_point(data=plotdata.sub, aes(x=plotdata.sub[,interval], y=plotdata.sub[,obscumvar], group=as.factor(plotdata.sub[,yearvar]), colour=as.factor(plotdata.sub[,yearvar])))+
    xlab('Interval') + ylab('Cumulative Survival (%)')+
    theme_bw()+
    ggtitle(title.survint) +
    coord_cartesian(ylim=c(0,1))+
    scale_y_continuous(breaks=seq(0,1,0.1),labels = scales::percent)+
    scale_x_continuous(breaks=seq(min(plotdata.sub[,interval],na.rm=T),max(plotdata.sub[,interval],na.rm=T),xbreaks.by))+
    scale_color_hue(labels = year.select)+
    theme(legend.position="bottom")+
    theme(legend.title=element_blank())+
    theme(plot.title = element_text(hjust = 0.5))
}


##################################################################################################################################################
### test using example data sets
library(JPSurv)
library(ggrepel)
setwd("P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/")

# example1 relative survival data
DICsample <- dictionary.overview("SEER9_Survival_6CancerSitesByStage_1975_2007.dic")
head(DICsample)

input <- joinpoint.seerdata(seerfilename="SEER9_Survival_6CancerSitesByStage_1975_2007", 
                            newvarnames=c("Site", "Year_of_diagnosis_7507_individual"), NoFit=T,
                            UseVarLabelsInData=c("Sites: CR LB B O P T","Year_of_diagnosis_7507_individual"))
head(input)
colnames(input)[2]<-"Site"
colnames(input)[3]<-"Sex"
colnames(input)[4]<-"Stage"
head(input)

subsetStr<-"Site==0 & Sex==0 & Stage==0"
fit <- joinpoint(input, subsetStr,
                 year="Year_of_diagnosis_7507_individual", observedrelsurv="Relative_Survival_Cum",
                 model.form = NULL, maxnum.jp = 3, proj.year.num = 5)
trend.rch<-aapc.multiints(fit, type="RelChgHaz",int.select=c(1,3,5)) 
trend.rch0<-aapc(fit, type="RelChgHaz") 
trend.acs<-aapc.multiints(fit, type="AbsChgSur",int.select=c(1,3,5)) 
trend.acs0<-aapc(fit, type="AbsChgSur") 


yearvar<-"Year_of_diagnosis_7507_individual"
obsintvar<-"Relative_Survival_Interval"
predintvar<-"Predicted_ProbDeath_Int"
obscumvar<-"Relative_Survival_Cum"
predcumvar<-"Predicted_Survival_Cum"
interval<-"Interval"

#nJP<-1
nJP<-3

# test download.data
data.graph5<-download.data(input,fit,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(5))
data.graph15<-download.data(input,fit,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1,5))
data.graph135<-download.data(input,fit,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1,3,5))
data.graph1to20<-download.data(input,fit,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1:20))
data.graph1tomax<-download.data(input,fit,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1:max(input$Interval,na.rm=T)))
data.full<-download.data(input,fit,nJP,yearvar,"full",subsetStr,interval="Interval")

# test plot.dying.year.annotate
out5.anno<-plot.dying.year.annotate(data.graph5,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=1,topanno=1,trend=1)
out5<-plot.dying.year.annotate(data.graph5,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=0,topanno=0,trend=1)
out15.anno<-plot.dying.year.annotate(data.graph15,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=1,topanno=1,trend=1)
out15<-plot.dying.year.annotate(data.graph15,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=0,topanno=0,trend=1)
out135.anno<-plot.dying.year.annotate(data.graph135,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=1,topanno=1,trend=1)
out135<-plot.dying.year.annotate(data.graph135,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=0,topanno=1,trend=1)
#out.1to20<-plot.dying.year.annotate(data.graph1to20,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=1,topanno=1,trend=1)
#out.1to20<-plot.dying.year.annotate(data.graph1to20,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=0,topanno=0,trend=1)
out135.anno.notrend<-plot.dying.year.annotate(data.graph135,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=1,topanno=1,trend=0)
out135.notrend<-plot.dying.year.annotate(data.graph135,fit,nJP,yearvar,obsintvar,predintvar,interval,annotation=0,topanno=1,trend=0)


trend5<-out5.anno[[1]]
pp5.anno<-out5.anno[[2]]
pp5<-out5.anno[[3]]
trend15<-out15.anno[[1]]
pp15.anno<-out15.anno[[2]]
pp15<-out15[[2]]
trend135<-out135.anno[[1]]
pp135.anno<-out135.anno[[2]]
pp135<-out135[[2]]

pp135.anno.notrend<-out135.anno.notrend
pp135.notrend<-out135.notrend

# test plot.surv.year.annotate
out5.anno<-plot.surv.year.annotate(data.graph5,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=1,trend=1)
out5<-plot.surv.year.annotate(data.graph5,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=0,trend=1)
out15.anno<-plot.surv.year.annotate(data.graph15,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=1,trend=1)
out15<-plot.surv.year.annotate(data.graph15,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=0,trend=1)
out135.anno<-plot.surv.year.annotate(data.graph135,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=1,trend=1)
out135<-plot.surv.year.annotate(data.graph135,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=0,trend=1)
#out.1to20<-plot.surv.year.annotate(data.graph1to20,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=1,trend=1)
#out.1to20<-plot.surv.year.annotate(data.graph1to20,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=0,trend=0)

out135.anno.notrend<-plot.surv.year.annotate(data.graph135,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=1,trend=0)
out135.notrend<-plot.surv.year.annotate(data.graph135,fit,nJP,yearvar,obscumvar,predcumvar,interval,annotation=0,trend=0)

trend5<-out5.anno[[1]]
pp5.anno<-out5.anno[[2]]
pp5<-out5.anno[[3]]
trend15<-out15.anno[[1]]
pp15.anno<-out15.anno[[2]]
pp15<-out15[[2]]
trend135<-out135.anno[[1]]
pp135.anno<-out135.anno[[2]]
pp135<-out135.anno[[3]]
pp135<-out135[[2]]

pp135.anno.notrend<-out135.anno.notrend
pp135.notrend<-out135.notrend
# test plot.surv.int.multiyears
pp.int.test1<-plot.surv.int.multiyears(data.full,fit,nJP,yearvar,obscumvar,predcumvar,interval,year.select=c(1985,1990))
pp.int.test2<-plot.surv.int.multiyears(data.graph1tomax,fit,nJP,yearvar,obscumvar,predcumvar,interval,year.select=seq(1975,1990,5))
pp.int.test3<-plot.surv.int.multiyears(data.graph1tomax,fit,nJP,yearvar,obscumvar,predcumvar,interval,year.select=seq(1998,2008,4))


#save.f<-"P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/test_download_graph135_example1.csv"
#write.csv(data.graph135,save.f,row.names=F,quote=F)
#save.f<-"P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/test_download_full_example1.csv"
#write.csv(data.full,save.f,row.names=F,quote=F)
#save.f<-"P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/test_example1_pp.jpg"
#ggsave(save.f,pp15.anno)

# example2  cause-specific data
DICsample = dictionary.overview("Breast_causespecific.dic")
head(DICsample)
seerdata_cause = joinpoint.seerdata(seerfilename="Breast_causespecific", 
                                    newvarnames=c("Year_of_diagnosis_1975"),NoFit=T,
                                    UseVarLabelsInData=c("Year_of_diagnosis_1975"))
subsetStr="Year_of_diagnosis_1975 >= 1975 & Breast_stage==1 & Age_groups == 2"
fit.cs <- joinpoint(seerdata_cause, 
                    subsetStr,
                    year="Year_of_diagnosis_1975",observedrelsurv="CauseSpecific_Survival_Cum",
                    model.form = NULL,
                    maxnum.jp = 3,proj.year.num=0)


nJP<-2
yearvar<-"Year_of_diagnosis_1975"
obsintvar<-"CauseSpecific_Survival_Interval"
predintvar<-"Predicted_ProbDeath_Int"
obscumvar<-"CauseSpecific_Survival_Cum"
predcumvar<-"Predicted_Survival_Cum"
interval<-"Interval"
annotation<-1

# test download.data
data.graph5<-download.data(seerdata_cause,fit.cs,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(5))
data.graph15<-download.data(seerdata_cause,fit.cs,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1,5))
data.graph135<-download.data(seerdata_cause,fit.cs,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1,3,5))
data.graph1to20<-download.data(seerdata_cause,fit.cs,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1:20))
data.graph1tomax<-download.data(seerdata_cause,fit.cs,nJP,yearvar,"graph",subsetStr,interval="Interval",int.select=c(1:max(input$Interval,na.rm=T)))
data.full<-download.data(seerdata_cause,fit.cs,nJP,yearvar,"full",subsetStr)

# test plot.dying.year.annotate
pp5.anno<-plot.dying.year.annotate(data.graph5,fit.cs,nJP,yearvar,obsintvar,predintvar,interval,annotation)
pp5<-plot.dying.year.annotate(data.graph5,fit.cs,nJP,yearvar,obsintvar,predintvar,interval)
pp15.anno<-plot.dying.year.annotate(data.graph15,fit.cs,nJP,yearvar,obsintvar,predintvar,interval,annotation)
pp15<-plot.dying.year.annotate(data.graph15,fit.cs,nJP,yearvar,obsintvar,predintvar,interval)
pp135.anno<-plot.dying.year.annotate(data.graph135,fit.cs,nJP,yearvar,obsintvar,predintvar,interval,annotation)
pp135<-plot.dying.year.annotate(data.graph135,fit.cs,nJP,yearvar,obsintvar,predintvar,interval)
#pp.1to20.anno<-plot.dying.year.annotate(data.graph1to20,fit.cs,nJP,yearvar,obsintvar,predintvar,interval,annotation)
#pp.1to20<-plot.dying.year.annotate(data.graph1to20,fit.cs,nJP,yearvar,obsintvar,predintvar,interval)

# test plot.surv.year.annotate
pp5.anno<-plot.surv.year.annotate(data.graph5,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval,annotation)
pp5<-plot.surv.year.annotate(data.graph5,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval)
pp15.anno<-plot.surv.year.annotate(data.graph15,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval,annotation)
pp15<-plot.surv.year.annotate(data.graph15,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval)
pp135.anno<-plot.surv.year.annotate(data.graph135,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval,annotation)
pp135<-plot.surv.year.annotate(data.graph135,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval)
pp.1to20<-plot.surv.year.annotate(data.graph1to20,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval,annotation)
pp.1to20<-plot.surv.year.annotate(data.graph1to20,fit.cs,nJP,yearvar,obscumvar,predcumvar,interval)

# test plot.surv.int.multiyears
pp.int.test1<-plot.surv.int.multiyears(data.full,fit,nJP,yearvar,obscumvar,predcumvar,interval,year.select=c(1985,1990))
pp.int.test2<-plot.surv.int.multiyears(data.graph1tomax,fit,nJP,yearvar,obscumvar,predcumvar,interval,year.select=seq(1975,1990,3))
pp.int.test3<-plot.surv.int.multiyears(data.graph1tomax,fit,nJP,yearvar,obscumvar,predcumvar,interval,year.select=seq(1998,2008,4))

#save.f<-"P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/test_example2_pp.jpg"
#ggsave(save.f,pp135)
#save.f<-"P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/test_download_graph135_example2.csv"
#write.csv(data.graph15,save.f,row.names=F,quote=F)
#save.f<-"P:/srab/surv/JPSurvival/Fanni_work/06052019.Rpackage/test_download_full_example2.csv"
#write.csv(data.full,save.f,row.names=F,quote=F)


