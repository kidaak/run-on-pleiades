#!/bin/bash
########################################################################
## Copyright (C) 2010 Jean-Baptiste Carré (speredenn)
##                   <jean-baptiste.carre@gadz.org>
## Time-stamp: <2010-08-02 11:36:07 (speredenn)>
##
## Description: This script creates a specific folder for each simulation
##              launched. It copies the simulation files in it, start the
##              simulation on Pleiades, according to the chosen
##              parameters, and collect the result files. The only files
##              it can not collect are the qsub.e and qsub.o files, as
##              they are created after the end of the job. So, in order
##              to complete the job started by this script, one should
##              launch the script "Pleiades-archive_simulations.sh"
##              before exploiting the results.
## Keywords: Pleiades; launch simulation; format results; save files
## Commentary: Pleiades is the name of one of the EPFL super-computers
##             used for heavy computational operations.
##             <http://pleiades.epfl.ch/>
##             NOTE: the QSUB_TMP trick belongs to R. Bolliger, from
##                   LENI <http://people.epfl.ch/raffaele.bolliger>.
##
########################################################################
## This file is free software licensed under the terms of the
## GNU General Public License, version 3 or later.
## More information on:
## http://www.gnu.org/licenses/gpl-3.0.txt
########################################################################
## Code:

# Home directory of the simulation which is going to be executed
# WARNING: Absolute path needed, no endding /.
ORG_SIM_FILES_PATH="/home/carre/DynSimTestPleiades"

# Name of the MATLAB file that has to be launched:
SIM_MAIN="main_onestageheatpump.m"

# Number of nodes:
NODES_NB=1

# Number of processors:
PROC_NB=4

# Time:
TIME="01:00:00"

# Backup and simulation paths (absolute path needed, no endding /):
BACKUP_PATH="$HOME/backups"
SIMULATIONS_PATH="$HOME/simulations"
#########################################################################

if [ -d $BACKUP_PATH ]; then
    echo -e "\nBackup directory... OK ($BACKUP_PATH)."
else
    mkdir -p $BACKUP_PATH
    echo -e "\nBackup directory created at path $BACKUP_PATH."
fi

if [ -d $SIMULATIONS_PATH ]; then
    echo "Simulation directory... OK ($SIMULATIONS_PATH)."
else
    mkdir -p $SIMULATIONS_PATH
    echo "Simulation directory created at path $SIMULATIONS_PATH."
fi

#########################################################################

# Generation of the timestamp and the identifier
TIMESTAMP=`date +%Y%m%dT%H%M%S`
RANDOM_ID=$RANDOM

# Basename for this run
BASE_NAME=${SIM_MAIN%%.*}-run$TIMESTAMP-$RANDOM_ID 

SCRIPT_NAME=`basename $0`
SCRIPT_PATH=`dirname $(readlink -f $0)`

#########################################################################

# Create the directory for the simulation files and the results
mkdir -p $SIMULATIONS_PATH/$BASE_NAME
echo "Simulation directory $BASE_NAME created."

# Duplicate the script file, as it is when the simulation is launched
cp $SCRIPT_PATH/$SCRIPT_NAME $SIMULATIONS_PATH/$BASE_NAME/$BASE_NAME-$SCRIPT_NAME

# Duplicate the simulation files, as they are when the simulation is launched
cp -R $ORG_SIM_FILES_PATH $SIMULATIONS_PATH/$BASE_NAME
ORG_SIM_FILES_DIR=`basename $ORG_SIM_FILES_PATH`
CURRENT_SIM_FILES_PATH=$SIMULATIONS_PATH/$BASE_NAME/$ORG_SIM_FILES_DIR

# Define the simulation command (can be adapted to other softwares)
SIM_COMMAND='matlab -nodesktop -nodisplay -nosplash -r "run('\'$CURRENT_SIM_FILES_PATH/$SIM_MAIN\'')"'


# Set the temporary file for the qsub script (Thanks to R. Bolliger for this trick)
QSUB_TMP=$SIMULATIONS_PATH/$BASE_NAME/$BASE_NAME.qsub

# Prepare the commands to be sent to the node
cat > $QSUB_TMP << END_OF_QSUB_TMP
#!/bin/sh

# Core of the job
$SIM_COMMAND >> $SIMULATIONS_PATH/$BASE_NAME/$BASE_NAME.out

# Cleaning of the simulation files directory
rm -Rf $CURRENT_SIM_FILES_PATH/.* $CURRENT_SIM_FILES_PATH/*~

# Specifically save the results.txt file of JJA simulation
mv $CURRENT_SIM_FILES_PATH/results.txt $SIMULATIONS_PATH/$BASE_NAME/$BASE_NAME-results.txt

END_OF_QSUB_TMP

# Define the command to Pleiades
PLEIADES_COMMAND="qsub -l nodes=$NODES_NB:ppn=$PROC_NB,walltime=$TIME $QSUB_TMP"

# Send of the command to Pleiades
$PLEIADES_COMMAND >> $SIMULATIONS_PATH/$BASE_NAME/$CURRENT_JOB.$HOSTNAME
JOB_LINE=`cat $SIMULATIONS_PATH/$BASE_NAME/$CURRENT_JOB.$HOSTNAME | tail -1`
CURRENT_JOB=`echo $JOB_LINE | cut -d '.' -f 1` 
#########################################################################

# Format the output in the terminal
if [ $NODES_NB -gt 1 ]; then
    NODES_DENOM="nodes"
else 
    NODES_DENOM="node"
fi

if [ $PROC_NB -gt 1 ]; then
    PROC_DENOM="processors"
else
    PROC_DENOM="processor"
fi

echo -e "\nYour job has the number $CURRENT_JOB.
The main file for this simulation is \"$SIM_MAIN\".
It has been queued for execution on $NODES_NB $NODES_DENOM of $PROC_NB $PROC_DENOM.

REMINDER: \"qstat -u $USER\" (to check if your job is alive).
          \"qdel $CURRENT_JOB\" (to delete the job).
          \"bash ~/scripts/Pleiades-archive_simulations.sh\" (to archive the results)."
