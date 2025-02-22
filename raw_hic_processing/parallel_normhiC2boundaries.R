# In this script, I try to define TAD boundaries from normalized Hi-C data. I use the set of short TADs to find borders 
# and I set the boundaries limits based on the change in interactions.
# Cyril Matthey-Doret
# 20.10.2016

############################
testmat <- list(matrix(rep(0,100),nrow=10),"1")
for(i in 1:10){testmat[[1]][i,i] <- 1}
for(i in 5:7){testmat[[1]][4,i]<-1}
for(i in 6:7){testmat[[1]][5,i]<-1}
testmat[[1]][6,7]<-1
# Loading data
#setwd("/Users/cmatthe5/Documents/First_step/data/")
#setwd("/home/cyril/Documents/Master/sem_1/First_step/data/")
setwd("/home/cyril/Documents/First_step/data/")
if (!exists("n.cores")) { 
  stopifnot(require(parallel)) 
  n.cores <- parallel:::detectCores() # Value depends on number of cores in the CPU
}
stopifnot(require(snow))
stopifnot(require(Matrix))
# Loading all matrices in a list (takes pretty long)
matlist <- list()
for(c in c("22")){
  tmp <- gzfile(paste0("norm_hic_data/GM12878/chr",c,"_5kb_norm.txt.gz"),"rt")  # Files are unzipped before read
  matlist[[c]] <- c(readMM(tmp),c)
  close(tmp)  # Freeing connection for next matrix
}
TAD <- read.table("TAD/short_fullover_TAD.bed")
colnames(TAD) <- c("chr","start","end")

#==========================

clus <- makeSOCKcluster( n.cores  )  # Creating cluster
on.exit( stopCluster(clus) )  

#Defining functions

D2toD1 <- function(I,J,N){
  return(((I-1)*N)+J)
}

vec_sub_square <- function(v,s,e,n,w){  
  # this function allows to get the values inside a square sub matrix in a 1D vector representing a larger square matrix
  # v=vector,s=upper left corner of square, e=bottom right, n= number of cols in matrix,w=width of subsquare
  sub_sq <- c()
  c <- 1
  while(s<=e){
    for(i in s:(s+(w-1))){
      sub_sq <-append(sub_sq,v[i])
    }
    s <- s+n
  }
  return(sub_sq)
}

vec_diam_slide<-function(m,R=5000, D=100000){  #Vectorized version of the slider. MUCH FASTER!
  L <- length(m[1,])
  M <- as.vector(t(m))
  diam <- rep(0,L) # preallocating space for diamond-summed data.
  diam[(D/R):(L-(D/R-1))] <- sapply(X = seq(from=D2toD1(D/R,D/R,L),to=D2toD1((L-(D/R-1)),(L-(D/R-1)),L),by=(L+1)),
                                    simplify = T, FUN= function(d){
                                      sum(vec_sub_square(v=M,s=(d-L*(D/R-1)),e=(d+(D/R-1)),n=L,w=(D/R)))})
  return(diam)
}

find_bound<-function(m,R=5000, D=100000){ # D is diamond size, R is resolution
  sub_TAD <- TAD[as.character(TAD$chr)==paste0("chr",m[[2]]),]  # subsetting TAD dataframe by chromosome (1chr/node)
  sub_TAD$Lbound.start = sub_TAD$Lbound.end = sub_TAD$Rbound.start =
    sub_TAD$Rbound.end = sub_TAD$maxint <- rep(0,length(sub_TAD$start))  # allocating space for max interaction observed in each TAD.
  diam <- vec_diam_slide(m[[1]],R,D)
  for(i in 1:length(sub_TAD$start)){  # Iterating over TADs
    start.ind <- pos_2_index(sub_TAD$start[i])  # transforming TAD start position to row in matrix. (TADs are already at 5kb res, so no need to approximate)
    end.ind <- pos_2_index(sub_TAD$end[i])  # Same for end position
    sub_TAD$maxint[i]<-max(diam[start.ind:end.ind])  # putting max interaction value for each TAD in dataframe.
    sl=el <- c(start.ind, diam[start.ind])  # Initiating left and right limits of left boundary
    while(sl[2]<(diam[start.ind]+sub_TAD$maxint[i]/10)){  # Start of left boundary -> sliding to the left
      sl[1] <- sl[1]-1; sl[2] <-diam[sl[1]]
      if(sl[1]==pos_2_index(D)){break}}
    sub_TAD$Lbound.start[i] <- index_2_pos(sl[1])  # + 1 because position corresponds to left edge of the bin. (don't want to include bin with interactions in boundary) ...forget it
    while(el[2]<(diam[start.ind]+sub_TAD$maxint[i]/10)){  # End of left boundary -> sliding to the right
      el[1] <- el[1]+1; el[2] <-diam[el[1]]
      if(el[1]==(length(m[[1]][1,])-(D/R))){break}}
    sub_TAD$Lbound.end[i] <- index_2_pos(el[1])
    sr=er <-c(end.ind, diam[end.ind])  # Initiating left and right limits of right boundary

    while(sr[2]<(diam[end.ind]+sub_TAD$maxint[i]/10)){  # Start of right boundary -> sliding to the left
      sr[1] <- sr[1]-1; sr[2] <-diam[sr[1]]
      if(sr[1]==pos_2_index(D)){break}}
    sub_TAD$Rbound.start[i] <- index_2_pos(sr[1])

    while(er[2]<(diam[end.ind]+sub_TAD$maxint[i]/10)){  # End of right boundary -> sliding to the right
      er[1] <- er[1]+1; er[2] <-diam[er[1]]
      if(er[1]==(length(m[[1]][1,])-(D/R))){break}}
    sub_TAD$Rbound.end[i] <- index_2_pos(er[1])
  }
  return(sub_TAD)
}

index_2_pos <- function(ind, resolution=5000) { return(resolution * (ind - 1)) }# Finding actual position in genome from bin number.
pos_2_index <- function(pos, resolution=5000) { return(1 + (pos / resolution))  }  # Finding index in vector from entry in matrix
#=========================

# Sending tasks
clusterCall( clus, function() { 
  require(Matrix)       # executed on each node. 
  # Loading required libraries in each instance of R
} )
# Exporting the list of TADs and the required functions to each node in the cluster.
clusterExport(clus, c("TAD", "index_2_pos", "pos_2_index","vec_diam_slide", "vec_sub_square"), envir=environment())
tmp <- clusterApplyLB( clus, matlist, find_bound)
full <- do.call("rbind", tmp)
full
write(full, file="BOUNDARIES_HIC.txt", sep= "\t")
#write.table(full, file = "TAD/merged/hic_bound.txt",quote = F,col.names = F,row.names = F,sep = "\t")
