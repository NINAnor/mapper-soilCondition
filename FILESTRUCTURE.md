### The resulting directory structure
------------

The directory structure of your new project looks like this: 

```
├── data
│   ├── interim                           <- Intermediate data that has been transformed.
│   ├── processed                         <- The final, canonical data sets for modeling.
│   └── raw                               <- The original, immutable data dump.
│
├── reports                               <- Generated analysis as HTML, PDF, LaTeX, etc.
│   └── figures                           <- Generated graphics and figures to be used in reporting
│
├── src                                   <- Source code for use in this project.
│   │
│   ├── data                              <- Scripts to download or generate data
│   │   ├── prepare_responseVar.R         <- R-script to clean the response dataset (myrselskapet data)
│   │   └── GEE_extractPredictors.ipynb   <- GEE-script to extract terrain, climatic and biological predictors. 
│   ├── features                          <- Scripts to turn raw data into features for modeling
│   │   └── build_features.R
│   │
│   ├── models                            <- Scripts to train models and then use trained models to make predictions
│   │   │                 
│   │   ├── predict_model.R
│   │   └── train_model.R
│   │
│   └── visualization                     <- Scripts to create exploratory and results oriented visualizations
│       └── visualize.R
|
├── requirements.txt                      <- The requirements file for reproducing the analysis environment, e.g.
├── README.md                             <- The top-level README for developers using this project.
├── LICENSE

```
