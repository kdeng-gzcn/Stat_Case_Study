source("SEM1/Project2/reducewords.R")
source("SEM1/Project2/stylometryfunctions.R")

# 1. load data
# 1.1 M
humanM <- loadCorpus("SEM1/Project2/functionwords/functionwords/humanfunctionwords/", "functionwords")
GPTM <- loadCorpus("SEM1/Project2/functionwords/functionwords/GPTfunctionwords/", "functionwords")
# 1.2 features
humanfeatures <- humanM$features
GPTfeatures <- GPTM$features
rhfeatures<-humanM$features[[1]]
rgfeatures<-GPTM$features[[1]]
numwords <- 2000 #number of words to trim the test set down into
for(i in 2:length(humanM$features)){
  rhfeatures<-rbind(rhfeatures,humanM$features[[i]])
  rgfeatures<-rbind(rgfeatures,GPTM$features[[i]])
}


reducedhumanfeatures <- reducewords(rhfeatures,numwords)
reducedGPTfeatures <- reducewords(rgfeatures,numwords)
reducedhumanfeatures.mat <- reducedhumanfeatures
reducedGPTfeatures.mat <- reducedGPTfeatures
reducedfeatures <- list(reducedhumanfeatures.mat, reducedGPTfeatures.mat)
humanfeatures <- humanM$features#select the essays on this particular topic
GPTfeatures <- GPTM$features
humanfeatures.mat <- do.call(rbind, humanfeatures)
GPTfeatures.mat <- do.call(rbind, GPTfeatures)
# 1.3* sample 5 topics
#humanfeatures.mat <- humanfeatures.mat[1:100, ]
#GPTfeatures.mat <- GPTfeatures.mat[1:100, ]
# 1.4 combine human and GPT to be a list with index 1 (human) and 2 (GPT)
features <- list(humanfeatures.mat, GPTfeatures.mat)

start_time <- proc.time()

traindata <- features
reducedtraindata<-reducedfeatures
dataset <- features
dataset.mat <- rbind(features[[1]], features[[2]])
reduceddataset.mat <- rbind(reducedfeatures[[1]], reducedfeatures[[2]])
num_text <- nrow(features[[1]]) + nrow(features[[2]])

# 2.2 init prediction list

DApredictions <- NULL
KNNpredictions <- NULL
RFpredictions <- NULL
truth <- NULL

# 2.3 start leave-one-out or Cross-Validation

# 2.3.1 try cross-validation, sample idx for each fold

idx_total <- 1:num_text
num_folds <- 5
idx_folds <- vector("list", num_folds)
for (i in 1:num_folds) {
  idx_folds[[i]] <- sample(idx_total, size = as.integer(num_text / num_folds), replace = FALSE)
  idx_total <- setdiff(idx_total, idx_folds[[i]])
}

# 2.3.2 run algorithm

for (idx_fold in 1:num_folds){
  
  # a. get idx
  
  idx <- idx_folds[[idx_fold]]
  idx_human <- idx[idx <= (num_text / 2)]
  idx_GPT <- idx[idx > (num_text / 2)] - (num_text / 2)
  
  # sample testdata
  
  cv_testdata <- reduceddataset.mat[idx, ]
  
  # the rest of data is train data
  
  cv_traindata <- dataset
  
  # human
  
  cv_traindata[[1]] <- cv_traindata[[1]][-idx_human, ]
  
  # GPT
  
  cv_traindata[[2]] <- cv_traindata[[2]][-idx_GPT, ]
  
  # 使用 discriminantCorpus 进行分类
  
  DA_pred <- discriminantCorpus(cv_traindata, cv_testdata)
  DApredictions <- c(DApredictions, DA_pred)  # 将预测结果追加到 predictions
  
  # 使用 KNNCorpus 进行 KNN 分类
  
  KNN_pred <- KNNCorpus(cv_traindata, cv_testdata)
  KNNpredictions <- c(KNNpredictions, KNN_pred)  # 将KNN预测结果追加到 KNNpredictions
  
  # 使用 randomForestCorpus 进行分类
  
  RF_pred <- randomForestCorpus(cv_traindata, cv_testdata)
  RFpredictions <- c(RFpredictions, RF_pred)  # 将 Random Forest 预测结果追加到 RFpredictions
  
  # true label for this fold's testdata
  
  truth_label_fold <- ifelse(idx <= (num_text / 2), 1, 2)
  truth <- c(truth, truth_label_fold)
}



# 3. inference and visualize results

# 3.1 convert numeric -> factor

truth <- factor(truth, levels = sort(unique(truth)))
DApredictions <- factor(DApredictions, levels = levels(truth))
KNNpredictions <- factor(KNNpredictions, levels = levels(truth))
RFpredictions <- factor(RFpredictions, levels = levels(truth))
end_time <- proc.time()
message("Run Time:")
print(end_time - start_time)
# 3.2 sum bool factor

message("Discriminant Analysis (DA) Accuracy: ", sum(DApredictions==truth)/length(truth))
message("KNN Accuracy: ", sum(KNNpredictions==truth)/length(truth))
message("Random Forest (RF) Accuracy: ", sum(RFpredictions==truth)/length(truth))

# 3.3 print 

message("Confusion Matrix for Discriminant Analysis:")
print(confusionMatrix(DApredictions, truth))

message("Confusion Matrix for KNN:")
print(confusionMatrix(KNNpredictions, truth))

message("Confusion Matrix for Random Forest:")
print(confusionMatrix(RFpredictions, truth))



library(ggplot2)

data <- data.frame(
  x = c(0, 50, 200, 500, 1000, 2000, 0, 50, 200, 500, 1000, 2000, 0, 50, 200, 500, 1000,2000),
  y = c(0.9669, 0.8216, 0.9261, 0.957, 0.9646, 0.658, 0.5211, 0.5823, 0.6, 0.6012, 0.9995, 0.4999, 0.5084, 0.702, 0.8937),
  group = rep(c("Discriminant Analysis", "KNN", "Random Forest"), each = 5)
)

data$x <- factor(data$x, levels = c(0, 50, 200, 500, 1000,2000), 
                 labels = c("Base Line", "Fifty", "Two Hundred", "Five Hundred", "Thousand"))

ggplot(data, aes(x = x, y = y, color = group, group = group)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  labs(title = "Accuracies of Reduce Words", x = "Numwords", y = "Accuracy", color = "") +
  theme_minimal() +
  theme(legend.position = "top")

library(ggplot2)

data <- data.frame(
  x = c(0, 50, 200, 500, 1000, 2000, 0, 50, 200, 500, 1000, 2000, 0, 50, 200, 500, 1000,2000),
  y = c(0.21, 0.24, 0.21, 0.25, 0.22, 0.08, 0.08, 0.07, 0.08, 0.11, 26.06, 22.95, 23.02, 22.99, 22.29),
  group = rep(c("Discriminant Analysis", "KNN", "Random Forest"), each = 5)
)

data$x <- factor(data$x, levels = c(0, 50, 200, 500, 1000), 
                 labels = c("Base Line", "Fifty", "Two Hundred", "Five Hundred", "Thousand"))

ggplot(data, aes(x = x, y = y, color = group, group = group)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  labs(title = "Time Consumption of Reduce Words", x = "Numwords", y = "Time", color = "") +
  theme_minimal() +
  theme(legend.position = "top")




