#!/bin/sh

set -ex

mkdir -p data
mkdir -p build
mkdir -p dist

# This is the value used in the GEBCO data
NODATA=-32767

# wget -c https://www.naturalearthdata.com/download/10m/physical/ne_10m_bathymetry_all.zip
# unzip ne_10m_bathymetry_all.zip

cd data
if [ ! -f gebco_2024_sub_ice_topo_geotiff.zip ]; then
  echo "Download GEBCO data..."
  wget -nv -c -O gebco_2024_sub_ice_topo_geotiff.zip https://www.bodc.ac.uk/data/open_download/gebco/gebco_2024_sub_ice_topo/geotiff/
  echo "Unzipping GEBCO data..."
  unzip -o gebco_2024_sub_ice_topo_geotiff.zip
fi

# if [ ! -f water-polygons-split-4326.zip ]; then
#   # Download the water polygons data
#   wget -nv -c https://osmdata.openstreetmap.de/download/water-polygons-split-4326.zip
#   unzip water-polygons-split-4326.zip
# fi
cd ..

# Split the GEBCO data into 4 quadrants to make processing easier
for filepath in data/gebco_2024*.tif; do
  filename=$(basename "$filepath" .tif)
  base="build/${filename}"

  # Extract bounding coordinates from filename
  north=$(echo "$filename" | sed -r 's/.*_n([0-9.]+).*/\1/')
  south=$(echo "$filename" | sed -r 's/.*_s(-?[0-9.]+).*/\1/')
  west=$(echo "$filename" | sed -r 's/.*_w(-?[0-9.]+).*/\1/')
  east=$(echo "$filename" | sed -r 's/.*_e(-?[0-9.]+).*/\1/')

  # Compute midpoints
  mid_y=$(echo "scale=0; ($north + $south) / 2" | bc)
  mid_x=$(echo "scale=0; ($west + $east) / 2" | bc)

  # Generate tiles if they don't exist
  [[ -f "${base}_NW.tif" ]] || gdalwarp -overwrite -te $west $mid_y $mid_x $north "$filepath" "${base}_NW.tif"
  [[ -f "${base}_NE.tif" ]] || gdalwarp -overwrite -te $mid_x $mid_y $east $north "$filepath" "${base}_NE.tif"
  [[ -f "${base}_SW.tif" ]] || gdalwarp -overwrite -te $west $south $mid_x $mid_y "$filepath" "${base}_SW.tif"
  [[ -f "${base}_SE.tif" ]] || gdalwarp -overwrite -te $mid_x $south $east $mid_y "$filepath" "${base}_SE.tif"
done

# CUTLINE="data/water-polygons-split-4326/water_polygons.shp"
# gdalwarp -overwrite -te -78 24 -75 27 data/gebco_2024_sub_ice_n90.0_s0.0_w-90.0_e0.0.tif build/clipped.tif
# gdalbuildvrt -o build/gebco_2024.vrt data/gebco_2024.tif
# gdalwarp -overwrite -cutline $CUTLINE -crop_to_cutline -of GTiff -dstnodata $NODATA build/gebco_2024.vrt build/cropped.tif

export LEVELS="-11000 -10000 -9000 -8000 -7000 -6000 -5000 -4000 -3000 -2000 -1000 -750 -500 -250 -200 -100 -99 -98 -97 -96 -95 -94 -93 -92 -91 -90 -89 -88 -87 -86 -85 -84 -83 -82 -81 -80 -79 -78 -77 -76 -75 -74 -73 -72 -71 -70 -69 -68 -67 -66 -65 -64 -63 -62 -61 -60 -59 -58 -57 -56 -55 -54 -53 -52 -51 -50 -49 -48 -47 -46 -45 -44 -43 -42 -41 -40 -39 -38 -37 -36 -35 -34 -33 -32 -31 -30 -29 -28 -27 -26 -25 -24 -23 -22 -21 -20 -19 -18 -17 -16 -15 -14 -13 -12 -11 -10 -9 -8 -7 -6 -5 -4 -3 -2 -1"
# LEVELS="-11000 -10000 -9000 -8000 -7000 -6000 -5000 -4000 -3000 -2000 -1000 -500"

INFILES="build/gebco_2024*.tif"
# INFILES="build/clipped.tif"

for infile in $INFILES; do
  basefile=$(basename "$infile" .tif)
  outfile="dist/${basefile}.shp"
  clippedfile="build/${basefile}_water.tif"

  # TODO: crop to water shape
  # echo "Clipping $infile to $clippedfile"
  # gdalwarp -overwrite -cutline $CUTLINE -crop_to_cutline -of GTiff -dstnodata $NODATA $infile $clippedfile
  # rio mask $infile $CUTLINE $clippedfile --crop

  echo "$infile => $outfile"
  gdal_contour -snodata $NODATA -nln bathymetry -p -amax mindepth -fl $LEVELS $infile $outfile

  # for z in "$LEVELS"; do
  #   echo "Generating contours for $infile at $z"
  #   gdal_contour -snodata $NODATA -nln bathymetry -p -amax mindepth -fl $z $infile $outfile
  #   exit 1
  # done
done
