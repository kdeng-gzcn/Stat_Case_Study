source("SEM1/Project2/stylometryfunctions.R")

set.seed(42)

# 1. load data

# 1.1 M

humanM <- loadCorpus("SEM1/Project2/functionwords/functionwords/humanfunctionwords/", "functionwords")
GPTM <- loadCorpus("SEM1/Project2/functionwords/functionwords/GPTfunctionwords/", "functionwords")

# 1.2 features

humanfeatures <- humanM$features
GPTfeatures <- GPTM$features

# 1.3 change list to big matrix

humanfeatures.mat <- do.call(rbind, humanfeatures)
GPTfeatures.mat <- do.call(rbind, GPTfeatures)

# # *1.3.1 set seed

# set.seed(42)

# # *1.3.2 calculate nrow

# ratio = 0.1

# num_data <- as.integer(nrow(humanfeatures.mat) * ratio)

# # *1.3.3 split data

# humanfeatures.mat <- humanfeatures.mat[sample(1:nrow(humanfeatures.mat), num_data), ]

# GPTfeatures.mat <- GPTfeatures.mat[sample(1:nrow(humanfeatures.mat), num_data), ]

# 1.4 combine human and GPT to be a list with index 1 (human) and 2 (GPT)

features <- list(humanfeatures.mat, GPTfeatures.mat)

start_time <- proc.time()

# 2. run classifier

# 2.1 MAKE SURE TO USE CORRECT DATA

dataset <- features
dataset.mat <- rbind(features[[1]], features[[2]])
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
  
  cv_testdata <- dataset.mat[idx, ]
  
  # the rest of data is train data
  
  cv_traindata <- dataset
  
  # human
  
  cv_traindata[[1]] <- cv_traindata[[1]][-idx_human, ]
  
  # GPT
  
  cv_traindata[[2]] <- cv_traindata[[2]][-idx_GPT, ]
  
  # fit da with traindatq, and validate with testdata
  
  DA_pred <- discriminantCorpus(cv_traindata, cv_testdata)
  DApredictions <- c(DApredictions, DA_pred)  # save result
  
  # fit knn with traindatq, and validate with testdata
  
  KNN_pred <- KNNCorpus(cv_traindata, cv_testdata)
  KNNpredictions <- c(KNNpredictions, KNN_pred)  # save result
  
  # fit rf with traindatq, and validate with testdata
  
  RF_pred <- randomForestCorpus(cv_traindata, cv_testdata)
  RFpredictions <- c(RFpredictions, RF_pred)  # save result
  
  # true label for this fold's testdata
  
  truth_label_fold <- ifelse(idx <= (num_text / 2), 1, 2)
  truth <- c(truth, truth_label_fold) # save result
  
}

end_time <- proc.time()
message("Run Time:")
print(end_time - start_time)

# 3. inference and visualize results

# 3.1 convert numeric -> factor

truth <- factor(truth, levels = sort(unique(truth)))
DApredictions <- factor(DApredictions, levels = levels(truth))
KNNpredictions <- factor(KNNpredictions, levels = levels(truth))
RFpredictions <- factor(RFpredictions, levels = levels(truth))

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

baseline_results <- data.frame(
  topic = "Overall_Baseline",
  DA_accuracy = sum(DApredictions == truth) / length(truth),
  KNN_accuracy = sum(KNNpredictions == truth) / length(truth),
  RF_accuracy = sum(RFpredictions == truth) / length(truth)
)

write.csv(baseline_results, file = "baseline_accuracy_results.csv", row.names = FALSE)
