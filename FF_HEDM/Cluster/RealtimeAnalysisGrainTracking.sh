#!/bin/bash

#
# Copyright (c) 2014, UChicago Argonne, LLC
# See LICENSE file.
#

source ${HOME}/.MIDAS/paths

cmdname=$(basename $0)

echo "FF analysis code for GrainTracking and Multiple rings:"
echo "DO NOT CALL THIS DIRECTLY, USE TRACKGRAINS instead."
echo "Version: 4, 2017/02/21, in case of problems contact hsharma@anl.gov"

if [[ ${#*} != 5 ]]
then
  echo "Provide ParametersFile StartLayerNr EndLayerNr, the number of NODEs and MachineName to use!"
  echo "EG. ${cmdname} Parameters.txt 1 1 6 orthros( or orthrosextra)"
  echo "the source parameter file should not have ring numbers and layer numbers in it."
  exit 1
fi

if [[ $1 == /* ]]; then TOP_PARAM_FILE=$1; else TOP_PARAM_FILE=$(pwd)/$1; fi
STARTLAYERNR=$2
ENDLAYERNR=$3
NCPUS=$4
MACHINE_NAME=$5
STARTFNRFIRSTLAYER=$( awk '$1 ~ /^StartFileNrFirstLayer/ { print $2 } ' ${TOP_PARAM_FILE} )
RingNrs=$( awk '$1 ~ /^RingThresh/ { print $2 }' ${TOP_PARAM_FILE} )
SGNum=$( awk '$1 ~ /^SpaceGroup/ { print $2 }' ${TOP_PARAM_FILE} )
Thresholds=($( awk '$1 ~ /^RingThresh/ { print $3 }' ${TOP_PARAM_FILE} ))
FinalRingToIndex=$( awk '$1 ~ /^OverAllRingToIndex/ { print $2 }' ${TOP_PARAM_FILE} )
SeedFolder=$( awk '$1 ~ /^SeedFolder/ { print $2 }' ${TOP_PARAM_FILE} )
NrFilesPerLayer=$( awk '$1 ~ /^NrFilesPerSweep/ { print $2 }' ${TOP_PARAM_FILE} )
MargABC=$( awk '$1 ~ /^MargABC/ { print $2 }' ${TOP_PARAM_FILE} )
MargABG=$( awk '$1 ~ /^MargABG/ { print $2 }' ${TOP_PARAM_FILE} )
Twins=$( awk '$1 ~ /^Twins/ { print $2 }' ${TOP_PARAM_FILE} )
SNr=$( awk '$1 ~ /^StartNr/ { print $2 }' ${TOP_PARAM_FILE} )
ENr=$( awk '$1 ~ /^EndNr/ { print $2 }' ${TOP_PARAM_FILE} )
NewType=$( awk '$1 ~ /^NewType/ { print $2 }' ${TOP_PARAM_FILE} )
FLTFN=$( awk '$1 ~ /^FltFN/ { print $2 }' ${TOP_PARAM_FILE} )
MinNrSpots=$( awk '$1 ~ /^MinNrSpots/ { print $2 }' ${TOP_PARAM_FILE} )
echo "Ring to be used for seed points: $FinalRingToIndex"
CHART=/
flr=${TOP_PARAM_FILE%$CHART*}
fstm=$( echo ${TOP_PARAM_FILE} | awk -F"/" '{print $NF}' )
FileStem=$( awk '$1 ~ /^FileStem/ {print $2 }' $TOP_PARAM_FILE)
OldFolder=$( awk '$1 ~ /^OldFolder/ { print $2 }' ${TOP_PARAM_FILE} )
for ((LAYERNR=$STARTLAYERNR; LAYERNR<=$ENDLAYERNR; LAYERNR++))
do
   i=0
   echo "Processing peaks for layer: $LAYERNR"
   StartFileNr=$((${STARTFNRFIRSTLAYER}+$(($NrFilesPerLayer*$((${LAYERNR}-1))))))
   ${BINFOLDER}/GetHKLList ${TOP_PARAM_FILE}
   echo "StartFileNumber $StartFileNr"
   echo "Creating overall parameter file for this Layer:"
   PFName=${flr}/Layer${LAYERNR}_MultiRing_${fstm}
   echo "$PFName"
   cp ${TOP_PARAM_FILE} ${PFName}
   cp hkls.csv ${SeedFolder} 2>/dev/null || :
   echo "LayerNr $LAYERNR" >> ${PFName}
   echo "RingToIndex $FinalRingToIndex" >> $PFName
   echo "Folder $SeedFolder" >> $PFName
   ide=$( date +%Y_%m_%d_%H_%M_%S )
   OutFldr=${SeedFolder}/${FileStem}_Layer${LAYERNR}_Analysis_Time_${ide}
   cd ${SeedFolder}
   LayerDir=${FileStem}_Layer${LAYERNR}_Analysis_Time_${ide}
   RINGNRSFILE=${flr}/Layer${LAYERNR}_RingInfo.txt
   rm -rf $RINGNRSFILE
   ParamFNStem=${flr}/Layer${LAYERNR}_Ring
   mkdir -p ${OutFldr}
   cp hkls.csv ${OutFldr}
   cp ${TOP_PARAM_FILE} ${OutFldr}
   for RINGNR in $RingNrs
   do
		ThisParamFileName=${flr}/Layer${LAYERNR}_Ring${RINGNR}_${fstm}
		echo "ParameterFile used: ${ThisParamFileName}"
		cp ${TOP_PARAM_FILE} ${ThisParamFileName}
		echo "Ring Number: $RINGNR, Threshold: ${Thresholds[$i]}"
		Fldr=${SeedFolder}/Ring${RINGNR}
		mkdir -p $Fldr
		cp hkls.csv $Fldr
		echo "Folder $Fldr" >> ${ThisParamFileName}
		echo "RingToIndex $RINGNR" >> ${ThisParamFileName}
		echo "RingNumbers $RINGNR" >> ${ThisParamFileName}
		echo "LowerBoundThreshold ${Thresholds[$i]}" >> ${ThisParamFileName}
		echo "LayerNr $LAYERNR" >> ${ThisParamFileName}
		echo "StartFileNr $StartFileNr" >> ${ThisParamFileName}
		echo "Output will be saved in $Fldr"
		echo "RingNumbers $RINGNR" >> $PFName
		echo $RINGNR >> ${RINGNRSFILE}
    i=$((i+1))
    echo $i
   done
   ${PFDIR}/RunPeaksMult.sh ${TOP_PARAM_FILE} ${NCPUS} $RINGNRSFILE $ParamFNStem $fstm ${MACHINE_NAME}
   mv $RINGNRSFILE ${OutFldr}
   for RINGNR in $RingNrs
   do
		ThisParamFileName=${flr}/Layer${LAYERNR}_Ring${RINGNR}_${fstm}
		Fldr=${SeedFolder}/Ring${RINGNR}
		cp ${Fldr}/PeakSearch/${FileStem}_${LAYERNR}/paramstest.txt ${OutFldr}/paramstest_RingNr${RINGNR}.txt
		cp ${Fldr}/PeakSearch/${FileStem}_${LAYERNR}/Radius_StartNr_${SNr}_EndNr_${ENr}_RingNr_${RINGNR}.csv ${OutFldr}/.
		RingX=$RINGNR
		mv ${ThisParamFileName} ${OutFldr}
		i=$((i + 1))
    echo $i
   done
   ${BINFOLDER}/MergeMultipleRings ${PFName}
   cd ${SeedFolder}
   mv SpotsToIndex* ${OutFldr}
   mv InputAll* ${OutFldr}
   mv ${PFName} ${OutFldr}
   mv IDsHash.csv ${OutFldr}
   cp hkls.csv ${OutFldr}
   cd ${OutFldr}
   cp paramstest_RingNr${RingX}.txt paramstest.txt
   sed -i '/^OutputFolder/d' paramstest.txt
   sed -i '/^ResultFolder/d' paramstest.txt
   sed -i '/^RingRadii/d' paramstest.txt
   sed -i '/^RingNumbers/d' paramstest.txt
   echo "OutputFolder ${OutFldr}/Output" >> paramstest.txt
   echo "ResultFolder ${OutFldr}/Results" >> paramstest.txt
   echo "MargABC ${MargABC}" >> paramstest.txt
   echo "MargABG ${MargABG}" >> paramstest.txt
   for RINGs in $RingNrs
   do
        echo "RingNumbers ${RINGs}" >> paramstest.txt
        paramstest_this_ring=paramstest_RingNr${RINGs}.txt
        rad=$( awk '$1 ~ /^RingRadii/ {print $2 }' $paramstest_this_ring)
        echo "RingRadii $rad" >> paramstest.txt
   done
   echo "SpaceGroup $SGNum" >> paramstest.txt
   echo "GrainTracking 1" >> paramstest.txt
   echo "OldFolder $OldFolder" >> paramstest.txt
   sed -i 's/^MinNrSpots.*$/MinNrSpots 1/g' ${TOP_PARAM_FILE}
   ${PFDIR}/RefineTracking.sh ${NCPUS} ${TOP_PARAM_FILE} $OldFolder ${MACHINE_NAME}
   rm -rf ${SeedFolder}/output
done
