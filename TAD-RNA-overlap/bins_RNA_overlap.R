
# This script intends to count the number of lincRNAs/protein-coding genes overlapping each bin
# of the merged TADs.
# EDIT: This script is now useless since BEDTools intersect v 2.25 supports the -F parameter.
# Cyril
# 13.10.2016
##################################

# Loading data:
setwd("/home/cyril/Documents/First_step/data/")
#setwd("/home/cyril/Documents/Master/sem_1/First_step/data/")
#setwd("/Users/cmatthe5/Documents/First_step/data/")
TADbins <- read.table("TAD/merged/merged_TADbins1.txt")
lincRNA <- read.table("linc_RNA/LCL.expressed.lincRNA.bed")
colnames(lincRNA) <- c("chr","start","end","ID","strand")
colnames(TADbins) <- c("ID","chr","pos","start","end")
# Note: those files do not contain IDs but, the columns on the right correspond to bins, while the columns on the
# left correspond to RNAs.
over_pc <- read.table("TAD/merged/overlaps/bin-pcgenes_overlap5_local.bed")
over_lincRNA <- read.table("TAD/merged/overlaps/bin-lincRNA_overlap5_local.bed")
#================================
#just putting both informations together
TADbins <- data.frame(over_lincRNA,over_pc[,6])
options(scipen=999)
write.table(TADbins,file = "TAD/merged/RNAcount_TADbins5.txt",quote = F,sep = "\t",row.names = F,col.names = F)


#=================================
# Counting overlaps:
# Not using this anymore
TADbins <- data.frame(TADbins, lincRNA=rep(0,length(TADbins$ID)),pcgene=rep(0,length(TADbins$ID)))
# Careful: Takes ages to run:
for(r in row(TADbins)){
  TADbins[r,"lincRNA"]<-length(over_lincRNA[over_lincRNA[,7]==TADbins[r,"start"] &
                                            over_lincRNA[,8]==TADbins[r,"end"] &
                                            over_lincRNA[,6]==TADbins[r,"chr"],7])
  TADbins[r,"pcgene"]<-length(over_pc[over_pc[,7]==TADbins[r,"start"] &
                                      over_pc[,8]==TADbins[r,"end"] &
                                      over_pc[,6]==TADbins[r,"chr"],7])
}



options(scipen=999)
write.table(TADbins,file = "TAD/merged/RNAcount_TADbins.txt",quote = F,sep = "\t",row.names = F,col.names = F)
options(scipen=0)


