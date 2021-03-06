##################################################
## Script for xgboost experiments on diagnosis dataset
##################################################
library(RCurl)
library(dplyr)
library(DiagrammeR)
require(xgboost)
library(ggplot2)

#get data and summary
data_URL <- getURL('https://archive.ics.uci.edu/ml/machine-learning-databases/breast-cancer-wisconsin/wdbc.data')
names <- c('id_number', 'diagnosis', 'radius_mean', 
           'texture_mean', 'perimeter_mean', 'area_mean', 
           'smoothness_mean', 'compactness_mean', 
           'concavity_mean','concave_points_mean', 
           'symmetry_mean', 'fractal_dimension_mean',
           'radius_se', 'texture_se', 'perimeter_se', 
           'area_se', 'smoothness_se', 'compactness_se', 
           'concavity_se', 'concave_points_se', 
           'symmetry_se', 'fractal_dimension_se', 
           'radius_worst', 'texture_worst', 
           'perimeter_worst', 'area_worst', 
           'smoothness_worst', 'compactness_worst', 
           'concavity_worst', 'concave_points_worst', 
           'symmetry_worst', 'fractal_dimension_worst')
BC_large <- read.table(textConnection(data_URL), sep = ',', col.names = names)

# we don't need id_numer as input
BC_large$id_number <- NULL

# convert class text into numeric
data<-sapply(BC_large,as.numeric)

# normalization
maxs<-as.numeric(apply(data,2,max))
mins<-as.numeric(apply(data,2,min))
scaled<-as.data.frame(scale(data,center=mins,scale=maxs-mins))

# extract all positive and negative records
scaled_p<-subset(scaled,scaled$diagnosis==0)
scaled_n<-subset(scaled,scaled$diagnosis==1)
scaled_p.shuffle<-scaled_p[sample(nrow(scaled_p)),]
scaled_n.shuffle<-scaled_n[sample(nrow(scaled_n)),]

# split positive records evenly into three parts
row.p <-nrow(scaled_p.shuffle)
index.1<-round(0.33*row.p) 
index.2<-round(0.66*row.p)  
split.1<-scaled_p.shuffle[1:(index.1+1),] 
split.2<-scaled_p.shuffle[(index.1+2):(index.2+3),] 
split.3<-scaled_p.shuffle[(index.2+4):row.p,] 
list.p <- list(split.1, split.2, split.3)

# split negative records evenly into three parts
row.n <-nrow(scaled_n.shuffle)
index.1<-round(0.33*row.n)
index.2<-round(0.66*row.n)
split.1<-scaled_n.shuffle[1:(index.1+1),]
split.2<-scaled_n.shuffle[(index.1+2):(index.2+2),]
split.3<-scaled_n.shuffle[(index.2+3):row.n,]
list.n <- list(split.1, split.2, split.3)

# combine positive and negative records into one group
splitall.1<-rbind(list.p[[1]],list.n[[1]])
splitall.1<-splitall.1[sample(nrow(splitall.1)),]
splitall.2<-rbind(list.p[[2]],list.n[[2]])
splitall.2<-splitall.1[sample(nrow(splitall.2)),]
splitall.2<-splitall.2[complete.cases(splitall.2), ]
splitall.3<-rbind(list.p[[3]],list.n[[3]])
splitall.3<-splitall.1[sample(nrow(splitall.3)),]

# combine three groups 
train.list<-list(rbind(splitall.1,splitall.2),rbind(splitall.1,splitall.3),rbind(splitall.2,splitall.3))
test.list<-list(splitall.3,splitall.2,splitall.1)

# parameter initialization
cv.error <- NULL
miss_classified <- NULL
k <- 3

# cross valiation loops
for(i in 1:k){
  # extract one group of training data
  train.data<-as.matrix(train.list[[i]][,names(train.list[[i]]) != "diagnosis"])
  train.label<-train.list[[i]][,names(train.list[[i]]) == "diagnosis"]
  
  # extract one group of test data
  test.data<-as.matrix(test.list[[i]][,names(test.list[[i]]) != "diagnosis"])
  test.label<-test.list[[i]][,names(test.list[[i]]) == "diagnosis"]
  
  # train xgboost model, you can change the parameter 'max.depth' to adapt the depth of each decision tree
  bst <- xgboost(data = train.data, label = train.label, max.depth = 3, eta=1, nthread = 2, nround = 2, objective = "binary:logistic")
  
  # predict on test data
  pred <- predict(bst, test.data)
  prediction <- as.numeric(pred > 0.5)
  
  # compute cross validation error
  err <- mean(prediction != test.label)
  cat("The error of cross-validation for this round is:", err, "\n")
  cv.error[i] <- err
}

# compute the average error for all cross validations
mean(cv.error)

# importance measurement
importance_matrix <- xgb.importance(model = bst)
im_graph<-xgb.plot.importance(importance_matrix = importance_matrix)

# draw the xgboost model
new_graph<-xgb.plot.tree(model = bst, render =  FALSE)

# make the color more fancy
change_graph<-recode_node_attrs(new_graph, node_attr_from = fillcolor, "Beige -> orange", "Khaki"->"grey")

# render on the plot
render_graph(change_graph)

# you can save the model as you will
# export_graph(change_graph, "~/Desktop/xgb1.png")

