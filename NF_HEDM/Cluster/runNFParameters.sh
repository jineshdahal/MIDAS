#!/bin/bash

#
# Copyright (c) 2014, UChicago Argonne, LLC
# See LICENSE file.
#

source ${HOME}/.MIDAS/pathsNF

cmdname=$(basename $0)

if [[ ${#*} != 6 ]];
then
  echo "Usage: ${cmdname} parameterfile processImages FFSeedOrientations MultiGridPoints nNODEs MachineName"
  echo "Eg. ${cmdname} ParametersFile.txt 0 0 0 6 orthros"
  echo "FFSeedOrientations is when either Orientations exist already (0) or when you provide a FF Orientation file (1)."
  echo "MultiGridPoints is 0 when you just want to process one spot, otherwise if it is 1, then provide the multiple points"
  echo "in the parameter file."
  echo "processImages = 1 if you want to reduce raw files, 0 otherwise"
  exit 1
fi

if [[ $1 == /* ]]; then TOP_PARAM_FILE=$1; else TOP_PARAM_FILE=$(pwd)/$1; fi
NCPUS=$5
processImages=$2
FFSeedOrientations=$3
MultiGridPoints=$4
MACHINE_NAME=$6

nNODES=${NCPUS}
export nNODES
if [[ ${MACHINE_NAME} == *"edison"* ]]; then
	echo "We are in NERSC EDISON"
	hn=$( hostname )
	hn=${hn: -2}
	hn=${hn#0}
	hn=$(( hn+20 ))
	intHN=128.55.203.${hn}
	export intHN
	echo "IP address of login node: $intHN"
elif [[ ${MACHINE_NAME} == *"cori"* ]]; then
	echo "We are in NERSC CORI"
	hn=$( hostname )
	hn=${hn: -2}
	hn=${hn#0}
	hn=$(( hn+30 ))
	intHN=128.55.224.${hn}
	export intHN
	echo "IP address of login node: $intHN"
else
	intHN=10.10.10.100
	export intHN
fi
# Go to the right folder
DataDirectory=$( awk '$1 ~ /^DataDirectory/ { print $2 }' ${TOP_PARAM_FILE} )
cd ${DataDirectory}

# Make hkls.csv
${BINFOLDER}/GetHKLList ${TOP_PARAM_FILE}

echo "Making hexgrid."
${BINFOLDER}/MakeHexGrid $TOP_PARAM_FILE
if [[ ${MultiGridPoints} == 0 ]];
then
  echo "Now choose the grid point to process, press enter to continue"
  echo "The grid points numbers are first column, position (x,y) is 4 and 5 column"
  read dummyVar
  cat -n grid.txt
  echo "REMEMBER: Subtract 1 from the line number (first column)."
  read GRIDPOINTNR
  echo "You entered: ${GRIDPOINTNR}"
fi

echo "Making diffraction spots."

GrainsFile=$( awk '$1 ~ /^GrainsFile/ { print $2 }' ${TOP_PARAM_FILE} )
SeedOrientations=$( awk '$1 ~ /^SeedOrientations/ { print $2 }' ${TOP_PARAM_FILE} )

if [[ ${FFSeedOrientations} == 1 ]];
then
    ${BINFOLDER}/GenSeedOrientationsFF2NFHEDM $GrainsFile $SeedOrientations
fi

NrOrientations=$( wc -l ${SeedOrientations} | awk '{print $1}' )

echo "NrOrientations ${NrOrientations}" >> ${TOP_PARAM_FILE}
${BINFOLDER}/MakeDiffrSpots $TOP_PARAM_FILE

if [[ ${processImages} == 1 ]];
then
  echo "Reducing images."
  NDISTANCES=$( awk '$1 ~ /^nDistances/ { print $2 }' ${TOP_PARAM_FILE} )
  NRFILESPERDISTANCE=$( awk '$1 ~ /^NrFilesPerDistance/ { print $2 }' ${TOP_PARAM_FILE} )
  NRPIXELS=$( awk '$1 ~ /^NrPixels/ { print $2 }' ${TOP_PARAM_FILE} )
  tmpfn=${DataDirectory}/fns.txt
  echo "paramfn datadir" > ${tmpfn}
  echo "${TOP_PARAM_FILE} ${DataDirectory}" >> ${tmpfn}
  ${SWIFTDIR}/swift -config ${PFDIR}/sites.conf -sites ${MACHINE_NAME} ${PFDIR}/processLayer.swift \
    -FileData=${tmpfn} -NrDistances=${NDISTANCES} -NrFilesPerDistance=${NRFILESPERDISTANCE} \
    -DoPeakSearch=${processImages} -FFSeedOrientations=${FFSeedOrientations} -DoFullLayer=0
fi

echo "Finding parameters."
if [[ ${MultiGridPoints} == 0 ]];
then
  ${BINFOLDER}/FitOrientationParameters $TOP_PARAM_FILE ${GRIDPOINTNR}
else
  ${BINFOLDER}/FitOrientationParametersMultiPoint $TOP_PARAM_FILE
fi
