# mapper-soilCondition
 
Pilot project for mapping indicators for soil health in Norway using the myrselskapet dataset. 

Project status: in progress

## Getting started

________________
insert tekst here

## File structure
________________

```
├── data
│   ├── interim                           <- Intermediate data that has been transformed.
│   ├── processed                         <- The final, canonical data sets for modeling.
│   └── raw                               <- The original, immutable data dump.
│
├── reports                               <- Generated reports as PDF, LaTeX, etc.
│   └── figures                           <- Generated graphics and figures to be used in 
│
├── src                                   <- Source code for use in this project.
│   │
│   ├── data                              <- Scripts to download, extract and clean data
│   │   ├── prepare_responseVar.R         <- R-script to clean the response dataset (myrselskapet) 
│   │   └── GEE_extractPredictors.ipynb   <- GEE-script to extract terrain, climatic and biological predictors. 
|   |
│   ├── models                            <- Scripts to train models and then use trained models to make predictions
│   │   │                 
│   │   ├── predict_model.R
│   │   └── train_model.R
│   │
│   └── visualization                     <- Scripts to create exploratory and results oriented visualizations
│       └── visualize.R
|
├── requirements_R.txt                    <- The requirements file for reproducing the R analysis env
├── requirements_Py.txt                   <- The requirements file for reproducing the GEE python analysis env
├── README.md                             <- The top-level README for developers using this project.
├── LICENSE

```

________________

## Contributors

willeke acampo (NINA), jenny hanssen (NINA) willeke.acampo@nina.no, jenny.hansen@nina.no
