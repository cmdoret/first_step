# This script processes a set of TADs to remove the large encompassing ones and keep only those that do not completely overlap.
# Cyril Matthey-Doret
# Fri Oct 28 08:49:55 2016 ------------------------------

# Loading data:
setwd("/home/cyril/Documents/First_step/data/")
setwd("/home/cyril/Documents/Master/sem_1/First_step/data/")
setwd("/Users/cmatthe5/Documents/First_step/data/")
TAD <- read.table("TAD/GM12878_TAD_domains.bed")
TAD <- TAD[,c(1,2,3,5)]
colnames(TAD) <- c("chr","start","end","ID")
library(intervals)

#======================================
# Removing ALL large TADs overlapping

reduce_TAD <- function(TAD){
  blacklist <- list()
  for (c in levels(TAD$chr)){  # Doing operations separately by chromosomes
    blacklist[[c]] <- c()
    TAD_tmp<-Intervals(matrix(c(TAD$start[TAD$chr==c],
                       TAD$end[TAD$chr==c]),ncol=2))
    rownames(TAD_tmp) <- TAD$ID[TAD$chr==c]  # Naming intervals after TADs
    over <-interval_overlap(TAD_tmp,TAD_tmp)  # Calling overlaps between all TADs
    for(k in names(over)){  # Iterating over TAD names
      if(length(over[[k]])>1){  # If the number of overlaps for a TAD is gt 1 (i.e. overlaps not only with itself)
        for(t in over[[k]]){  # Iterating over items overlapping this TAD
          if(k!=names(over[t]) & size(TAD_tmp[k])<=size(TAD_tmp[t])){  # Only counting overlaps that are not the TAD itself
            blacklist[[c]] <- append(blacklist[[c]],rownames(TAD_tmp[t])) # Contains only large TADs that need to be removed
          }
        }
      }
    }
  }
  return(blacklist)
}
large <-reduce_TAD(TAD)  # Storing the IDs of all large TADs

options(scipen=999)  # Preventing R from using scientific notation (other programs such as bedtools and genome browsers do not like it)
short <- TAD[!(TAD$ID %in% unname(unlist(large))),]  # Removing all large TADs from the original list
write.table(short,"TAD/short_TADs.bed",sep="\t",quote = F,col.names=F,row.names=F)
#==============================================
# other method: proceeding at the boundary level
TADb <- data.frame(chr=rep(0,2*length(TAD$ID)),  # Generating empty dataframe for storing all boundaries (2/TAD)
                   start=rep(0,2*length(TAD$ID)),
                   end=rep(0,2*length(TAD$ID)),
                   ID=rep(0,2*length(TAD$ID)))

for(i in 1:length(TAD$ID)){  # Generating boundaries of 5% TAD length and storing them in the dataframe
  start <- TAD$start[i]
  end <- TAD$end[i]
  lb <- c(as.character(TAD$chr[i]),start,start+(end-start)*0.05,paste0(TAD$ID[i],"L"))  # Note the ID of each boudary will be the ID of its TAD followed by the side (R or L)
  rb <- c(as.character(TAD$chr[i]),end-(end-start)*0.05,end,paste0(TAD$ID[i],"R"))
  TADb[2*i-1,] <-lb  # Left boudary
  TADb[2*i,] <- rb  # Right boundary
}
TADb$start <- as.numeric(TADb$start)
TADb$end <- as.numeric(TADb$end)
TADb$chr <- as.factor(TADb$chr)
large_b <- reduce_TAD(TADb) # Storing Large boundaries that need to be removed
short_b <- TADb[!(TADb$ID %in% unname(unlist(large_b))),]  # Removing longer overlapping boundaries
options(scipen=999) 
write.table(short_b, file="TAD/short_in5_boundaries.bed",sep="\t",quote = F,col.names=F,row.names=F)

##############################

# Different version only discarding TADs if a smaller one is entirely inside.
inbig_TAD <- function(TAD){
  blacklist <- list()
  for (c in levels(TAD$chr)){  # Doing operations separately by chromosomes
    blacklist[[c]] <- c()
    TAD_tmp<-Intervals(matrix(c(TAD$start[TAD$chr==c],
                                TAD$end[TAD$chr==c]),ncol=2))
    rownames(TAD_tmp) <- TAD$ID[TAD$chr==c]  # Naming intervals after TADs
    over <-interval_overlap(TAD_tmp,TAD_tmp)  # Calling overlaps between all TADs
    for(k in names(over)){  # Iterating over TAD names
      if(length(over[[k]])>1){  # If the number of overlaps for a TAD is gt 1 (i.e. overlaps not only with itself)
        for(t in over[[k]]){  # Iterating over items overlapping this TAD
          if(k!=names(over[t]) # Only counting overlaps that are not the TAD itself
             & size(TAD_tmp[k])<=size(TAD_tmp[t])   # Removing TAD if larger or same size.
             & size(interval_intersection(TAD_tmp[k],TAD_tmp[t]))>=size(TAD_tmp[k])){  # Removing TAD if it completely encompass smaller one
            blacklist[[c]] <- append(blacklist[[c]],rownames(TAD_tmp[t])) # Contains only large TADs that need to be removed
          }
        }
      }
    }
  }
  return(blacklist)
}
large <-inbig_TAD(TAD)  # Storing the IDs of all large TADs

options(scipen=999)  # Preventing R from using scientific notation (other programs such as bedtools and genome browsers do not like it)
short <- TAD[!(TAD$ID %in% unname(unlist(large))),]  # Removing all large TADs from the original list
write.table(short,"TAD/short_TADs.bed",sep="\t",quote = F,col.names=F,row.names=F)


