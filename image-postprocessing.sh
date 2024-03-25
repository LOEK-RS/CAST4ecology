#!/bin/bash

mogrify -format png -trim *.png

convert geodist-1.png geodist-2.png +append geodist.png


convert knndm-map-1.png knndm-plots-1.png +append knndm-cv.png
convert rcv-map-1.png rcv-plots-1.png +append r-cv.png
convert r-cv.png knndm-cv.png -append cross-validation-comparison.png

convert ffs-selected-1.png ffs-prediction-1.png +append ffs-results.png

convert performancemodel-plot-1.png expectedRMSE-map-1.png +append expectedRMSE.png

convert knndm-mapping-1.png knndm-mapping-2.png knndm-mapping-3.png +append knndm-mapping.png




