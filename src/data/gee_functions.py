import ee
import geemap

def projectFeature(feature: ee.Feature, crs_dst: str, scale: float) -> ee.Feature:
    reprojected_feature=feature.transform(crs_dst, scale)
    return reprojected_feature

def getScale(image):
    scale = int(image.select(0).projection().nominalScale().getInfo())
    return scale

# Get the number of images in the collection
def get_imageCollection_metadata(image_collection):
    """
    Metadata is extracted from an image stack from Google Earth Engine and returns the max and min scale (spatial resolution) 
    from the images in the stack along with the number images in the collection.

    Args:
        image_collection (ImageCollection): image_collection object 

    Returns:
        tuple(int): A tuple containing the number of images, and the maximum and minimum resolutions
    """    
    # Get the number of images in the collection
    num_images = image_collection.size().getInfo()
    scaleList = []

    # Loop through each image in the collection and compute the spatial resolution.
    for i in range(num_images):
        # Get the i-th image in the collection
        image_i = ee.Image(image_collection.toList(num_images).get(i))
        # Compute and append the spatial resolution(scale) of the ith image to scaleList 
        scaleList.append(getScale(image_i))

    # Compute the maximum and minimum scales from the list of scales
    max_scale = max(scaleList)
    min_scale = min(scaleList) 

    # Return a tuple with the number of images and the computed scales.
    return num_images, max_scale, min_scale

def print_image_metadata(image_list):
    for image in image_list:
    # Get the image information of the image
        object_type = image.getInfo()['type']
        bandNames = image.bandNames().getInfo()
        scale = image.projection().nominalScale().getInfo()
    # Print the scale of the image
        print(f'Object Type: {object_type}')
        print(f'Image Bands: {bandNames}')
        print(f'\tscale: {scale} m/px')

        for i, band in enumerate(bandNames):
        # select and get info of the current band. 
            band_x = image.select(band)
            crs = band_x.projection().crs().getInfo()
            print(f'\tcrs: {crs}')
            print(f'\tBand {i+1}: {band}\n')


def resample(image, method, projection, maxPixels):
    resampled_image = image.reduceResolution(
            # Force the next reprojection to aggregate instead of resampling.
            reducer=method,
            maxPixels=maxPixels
        ).reproject(crs=projection) #Request the data at the scale and projection of the defined proejction image.
    
    return resampled_image




