// Mapping soil condition | Extract Sentinel-1 predictor variables using Google Earth Engine  
// Author: Jenny Hanssen, Willeke A'Campo, Zander Venter
// Date: 28.10.2023

// Myrselskapet data 
var wetland_path = "path/to/wetland/polygons"
var wetlands = ee.FeatureCollection(path);

// Add unique identifier to wetlands features
var addFeatureIndex = function(feature) {
    var index = feature.get('ID');
    return feature.set('ID', index);
  };
  
  // map unique identifier function over wetlands fc
  wetlands = wetlands.map(addFeatureIndex);
  
  // Define Sentinel 2 collection
  var s2Col = 'S2_SR'; // or 'S2' for TOA
  
  // Define the percentage of cloud cover below which you want to include
  var sceneCloudThreshold = 60;
  
  // Define the pixel cloud mask probability threshold
  var cloudMaskProbability = 40;
  
  // Define time period - year of 2018 to match LUCAS sampling date
  var startDate = '2020-05-01';
  var endDate = '2020-10-01';
  
  // Define S2 band common names
  var S2_BANDS = ['QA60', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B11', 'B12']; // Sentinel bands
  var S2_NAMES = ['QA60', 'cb', 'blue', 'green', 'red', 'R1', 'R2', 'R3', 'nir', 'swir1', 'swir2']; // Common names
  
  /*
    // Sentinel processing functions ///////////////////////////////////////////////////////////////////////////
  */
  
  // Function to add spectral indices to Sentinel images
  var addIndices = function (image) {
    var ndbi = image.expression('(SWIR - NIR) / (SWIR + NIR)', {
      'SWIR': image.select('swir1'),
      'NIR': image.select('nir'),
    }).rename('ndbi');
    // Add vegetation indices
    var ndvi = image.normalizedDifference(['nir', 'red']).rename('ndvi');
    var nbr = image.normalizedDifference(['nir', 'swir2']).rename("nbr");
    var ndsi = image.normalizedDifference(['green', 'swir1']).rename("ndsi");
    return image.addBands(ndvi).addBands(ndbi).addBands(nbr).addBands(ndsi);
  };
  
  //This procedure must be used for proper processing of S2 imagery
  // UTILS FUNCTION: get unique values of a field in an image collection (e.g. unique days within an image collection)
  function uniqueValues(collection, field) {
    var values = ee.Dictionary(collection.reduceColumns(ee.Reducer.frequencyHistogram(), [field]).get('histogram')).keys();
    return values;
  }
  
  // FUNCTION: collect images of each unique day, mosaiq them,  and add them to an ImageCollection 
  function dailyMosaics(imgs) {
    // Simplify date to exclude time of day
    imgs = imgs.map(function (img) {
      var d = ee.Date(img.get('system:time_start'));
      var day = d.get('day');
      var m = d.get('month');
      var y = d.get('year');
      var simpleDate = ee.Date.fromYMD(y, m, day);
      return img.set('simpleTime', simpleDate.millis());
    });
  
    // Find the unique days
    var days = uniqueValues(imgs, 'simpleTime');
  
    imgs = days.map(function (d) {
      // get date and convert to ee.Date object 
      d = ee.Number.parse(d);
      d = ee.Date(d);
      // filter image collection for specific date and the next day 
      var t = imgs.filterDate(d, d.advance(1, 'day'));
      var f = ee.Image(t.first());
      // mosaics the filtered collection 
      t = t.mosaic();
      t = t.set('system:time_start', d.millis());
      // copy properties of first image to the mosaic 
      t = t.copyProperties(f);
      return t;
    });
    // create an ImageCollection from the lists of mosaics
    imgs = ee.ImageCollection.fromImages(imgs);
  
    return imgs;
  }
  
  // FUNCTION: retrieves S2 surface reflectance and masks out clouds based on cloud probability threshold 
  var getS2_SR_CLOUD_PROBABILITY = function (aoi, startDate, endDate) {
    var primary = ee.ImageCollection("COPERNICUS/" + s2Col)
      .filterBounds(aoi)
      .filterDate(startDate, endDate)
      .filterMetadata('CLOUDY_PIXEL_PERCENTAGE', 'less_than', sceneCloudThreshold)
      .select(S2_BANDS, S2_NAMES)
      .map(addIndices);
    var secondary = ee.ImageCollection("COPERNICUS/S2_CLOUD_PROBABILITY")
      .filterBounds(aoi)
      .filterDate(startDate, endDate);
    var innerJoined = ee.Join.inner().apply({
      primary: primary,
      secondary: secondary,
      condition: ee.Filter.equals({
        leftField: 'system:index',
        rightField: 'system:index',
      }),
    });
    var mergeImageBands = function (joinResult) {
      return ee.Image(joinResult.get('primary')).addBands(joinResult.get('secondary'));
    };
    var newCollection = innerJoined.map(mergeImageBands);
    return ee.ImageCollection(newCollection)
      .map(maskClouds(cloudMaskProbability))
      .sort('system:time_start');
  };
  
  var maskClouds = function (cloudProbabilityThreshold) {
    return function (_img) {
      var cloudMask = _img.select('probability').lt(cloudProbabilityThreshold);
      return _img.updateMask(cloudMask);
    };
  };
  
  function getSentStack(aoi, startDate, endDate) {
    // retrieve S2 image collection masked for clouds for the specific aoi and timerange
    var s2Combo = getS2_SR_CLOUD_PROBABILITY(aoi, startDate, endDate);
    
    // create dailyMosaics and retrieve them as image collection 
    var s2Cleaned = s2Combo;
    s2Cleaned = dailyMosaics(s2Cleaned);
  
    // Get median value for image bands 
    var s2Median = s2Cleaned
      .select(['blue', 'green', 'red', 'R1', 'R2', 'R3', 'nir', 'swir1', 'swir2'])
      .reduce('median', 4);
  
    // Get Percentiles for NDVI and NDSI image bands 
    var s2Percs = s2Cleaned
      .select(['ndvi', 'ndsi'])
      .reduce(ee.Reducer.percentile([5, 25, 50, 75, 95]), 4);
      
    // Get Standard Deviation for image bands 
    var stDev = s2Cleaned.select(['nbr']).reduce(ee.Reducer.stdDev(), 4);
    
    // Filter s2Cleand on seasons for NDVI and calc median
    var ndviSummer = s2Cleaned.select('ndvi').filter(ee.Filter.calendarRange(6, 8, 'month')).median().rename('ndvi_summer');
    // ndvi winter not included 
    var ndviWinter = s2Cleaned.select('ndvi').filter(ee.Filter.calendarRange(12, 2, 'month')).median().rename('ndvi_winter');
    var ndviSpring = s2Cleaned.select('ndvi').filter(ee.Filter.calendarRange(9, 11, 'month')).median().rename('ndvi_fall');
    var ndviFall = s2Cleaned.select('ndvi').filter(ee.Filter.calendarRange(3, 5, 'month')).median().rename('ndvi_spring');
  
    // Mediuan NDVI value 
    var ndviFocal = s2Cleaned
      .select('ndvi')
      .reduce('median', 4)
      .reduceNeighborhood(ee.Reducer.stdDev(), ee.Kernel.square(3, 'pixels'))
      .rename('ndvi_texture_sd');
  
    // Create ImageStack for all calculated bands 
    var s2Stack = s2Median
      .addBands(s2Percs)
      .addBands(stDev)
      .addBands(ndviSummer)
      .addBands(ndviWinter)
      .addBands(ndviSpring)
      .addBands(ndviFall)
      .addBands(ndviFocal);
    
    // Multiply by 1000 and convert to integer to reduce file sizes on export
    //s2Stack = s2Stack.multiply(1000).round().int();
    //print(s2Stack, 'sentinel stack');
    
  
    return s2Stack;
  }
  
  /*
    // Exporting backscatter temporal metrics ///////////////////////////////////////////////////////////////////////////
  */
  
  //// Myrselskapet data 
  print(wetlands, 'Wetland Polygons');
  Map.addLayer(wetlands, {}, 'wetlands',0);
  
  // First Feature
  var firstFeature = wetlands.limit(1);
  //print(firstFeature);
  //Map.addLayer(firstFeature, {}, 'testFeature',0);
  
  var batchSize = 50; // Number of features to include in each batch
  var totalFeatures = wetlands.size().getInfo(); // Get the total number of features in the wetlands collection
  var numBatches = Math.ceil(totalFeatures / batchSize); // Calculate the number of batches needed
  
  for (var batch = 1; batch <= numBatches; batch++) {
    var startIdx = (batch - 1) * batchSize; // Calculate the starting index of the current batch
    var endIdx = Math.min(batch * batchSize, totalFeatures); // Calculate the ending index of the current batch
    
    var subsetFeatures = wetlands.toList(batchSize, startIdx); // Get the subset of features for the current batch
    print('Processing Batch:', batch, 'Features:', startIdx, '-', endIdx);
  
    // Create an empty FeatureCollection for the current batch
    var s2_Features = ee.FeatureCollection([]);
    
    for (var i = 0; i < subsetFeatures.size().getInfo(); i++) {
      var subsetFeature = ee.Feature(subsetFeatures.get(i));
      var subsetId = subsetFeature.get('ID');
      var subsetName = subsetFeature.get('name');
      
      // Print information regarding the feature 
      print('Processing Feature:', subsetId, subsetName);
      
      // Processing code for each feature within the batch
      
      // aoi = geometry of subset feature 
      // Define area of interest
      var aoi = subsetFeature.geometry();
      var masterStack = getSentStack(aoi, startDate, endDate);
    
      // Print Image Information 
      print(masterStack, "S2 stack");

      // Create a new FeatureCollection containing the single feature
      var singleFeatureCollection = ee.FeatureCollection([subsetFeature]);
    
      // Calculate Zonal Statistics (average) for the image bands within the wetland polygons
      var s2Feature = masterStack.reduceRegions({
        collection: singleFeatureCollection,
        reducer: ee.Reducer.mean(),
        scale: 10 // Adjust the scale according to your needs
      });
      
      print(s2Feature, 'Feature with extracted S2 values. ');
      s2_Features = s2_Features.merge(s2Feature);
      print(s2_Features, 'Merged Features');
    }
    
    // Export the s2_Features collection for the current batch
    Export.table.toDrive({
      collection: s2_Features,
      description: 'Batch_' + batch + '_s2Stack',
      folder: 'GEE_output',
      fileFormat: 'CSV'
    });
  }
  