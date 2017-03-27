#!/bin/bash -x

#
# Copyright (c) 2014, UChicago Argonne, LLC
# See LICENSE file.
#

source ${HOME}/.MIDAS/paths

cmdname=$(basename $0)

echo "FF analysis code for Multiple Layers and Multiple rings:"
echo "Version: 5, 2017/03/14, in case of problems contact hsharma@anl.gov"

if [[ ${#*} != 7 ]]
then
	echo "Provide ParametersFile StartLayerNr EndLayerNr DoPeakSearch Number of NODES to use MachineName EmailAddress!"
	echo "EG. ${cmdname} parameters.txt 1 1 1 (or 0) 6 orthros(orthrosextra,local,rice) hsharma@anl.gov"
	echo "the source parameter file should not have ring numbers and layer numbers in it."
	echo "If DoPeakSearch is 0, the parameter file must have a folder name for each layer (in order) to look into and redo analysis."
	echo "For example FolderName Ruby_scan2_Layer1_Analysis_Time_2016_09_19_17_11_07"
	echo "For example FolderName Ruby_scan2_Layer2_Analysis_Time_2016_09_19_17_13_23"
	echo "If these are not provided, it will check the parent folder and if multiple"
	echo "analyses are present for a layer, will take the latest one."
	echo "If DoPeakSearch is 0, it will overwrite the results in the directory it works."
	echo "Parameter file name should not be full path, analysis should be run from the directory where the parameter file is."
	echo "SeedFolder MUST BE the SAME as the folder from which the code is run AND should have the parameter file in it."
	exit 1
fi

# if [[ $1 == /* ]]; then TOP_PARAM_FILE=$1; else TOP_PARAM_FILE=$(pwd)/$1; fi
ParamsFile=$1
STARTLAYERNR=$2
ENDLAYERNR=$3
NCPUS=$5
DOPEAKSEARCH=$4
MACHINE_NAME=$6
StartNr=$( awk '$1 ~ /^StartNr/ { print $2 }' ${ParamsFile} )
EndNr=$( awk '$1 ~ /^EndNr/ { print $2 }' ${ParamsFile} )
echo "Peaks:"
nNODES=${NCPUS}
export nNODES
echo "MACHINE NAME is ${MACHINE_NAME}"

SeedFolder=$( awk '$1 ~ /^SeedFolder/ { print $2 }' ${ParamsFile} )
rm -rf ${SeedFolder}/FolderNames.txt
rm -rf ${SeedFolder}/PFNames.txt

for (( LAYERNR=$STARTLAYERNR; LAYERNR<=$ENDLAYERNR; LAYERNR++ ))
do
	${PFDIR}/InitialSetup.sh ${TOP_PARAM_FILE} ${LAYERNR} ${DOPEAKSEARCH}
done
NLAYERS=$(( $ENDLAYERNR - $STARTLAYERNR + 1 ))
${SWIFTDIR}/swift -config ${PFDIR}/sites.conf -sites ${MACHINE_NAME} \
	${PFDIR}/processLayers.swift -ringfile=${SeedFolder}/RingInfo.txt \
	-startnr=${StartNr} -endnr=${EndNr} -SeedFolder=${SeedFolder} \
	-DoPeakSearch=${DOPEAKSEARCH} -nLayers=${NLAYERS}
