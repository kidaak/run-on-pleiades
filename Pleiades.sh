#!/bin/bash
########################################################################
## Copyright (C) 2010-2011 Jean-Baptiste Carré (carre)
##                   <jean-baptiste.carre@gadz.org>
## Time-stamp: <2011-09-08 20:45:11 (carre)>
##
## Description: This script set has been created to simplify the users
## workflow with Pleiades, the Engineering Sciences Faculty
## SuperComputer. The Pleiades script creates a specific folder for
## each computations launched. It copies the simulation files, starts
## the simulation on Pleiades, according to the chosen parameters, and
## collects the result files. When the simulation is finished, a mail
## is sent to the user (the email needs to be configured in the
## script) and the simulation files are archived.
##
## Keywords: Pleiades; launch simulation; format results; save files
##
## Commentary: Pleiades is the name of one of the EPFL super-computers
## used for heavy computational operations.
## <http://pleiades.epfl.ch/> NOTE: the QSUB_TMP trick belongs to
## R. Bolliger, from LENI <http://people.epfl.ch/raffaele.bolliger>.
##
########################################################################
## This file is free software licensed under the terms of the
## GNU General Public License, version 3 or later.
## More information on:
## http://www.gnu.org/licenses/gpl-3.0.txt
########################################################################
## Code:

# Example: bash ~/Scripts/Pleiades.sh ~/Test/test.m nodes:1 proc:4 time:00:05:00


########################################################################
# Configuration section
########################################################################

# File to be run
SIM_MAIN="$1"

# It is assumed that the file to be run is at the upper level of the
# folder hierarchy: The folder where is the file to run needs to be
# backed up.

# Node configuration
NODES_NB=${2#"nodes:"}
PROC_NB=${3#"proc:"}

# Time
TIME=${4#"time:"}

# Mail address
MAIL_ADR="jean-baptiste.carre@gadz.org"

# Backup
BKP_PATH="$HOME/Backups"

# Simulation folder
SIMDIR_PATH="$HOME/Simulations"

########################################################################
# Core
########################################################################

# Simulation directory and filename
SIM_DIR="${SIM_MAIN%/*}"
SIM_NAME=`basename ${SIM_MAIN%%.*}`

# Generation of the timestamp and the identifier
TIMESTAMP=`date +%Y%m%dT%H%M%S`

# Basename for this run
BASE_NAME=$SIM_NAME-run$TIMESTAMP
SCRIPT_NAME=`basename $0`
SCRIPT_PATH=`dirname $(readlink -f $0)`

# Working directories exist?
if [ -d $BKP_PATH ]; then
    echo -e "\nBackup directory... OK ($BKP_PATH)."
else
    mkdir -p $BKP_PATH
    echo -e "\nBackup directory created at path $BKP_PATH."
fi
if [ -d $SIMDIR_PATH ]; then
    echo "Simulation directory... OK ($SIMDIR_PATH)."
else
    mkdir -p $SIMDIR_PATH
    echo "Simulation directory created at path $SIMDIR_PATH."
fi

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

# Creation of the backup and simulations folders
mkdir -p $BKP_PATH/$BASE_NAME
mkdir -p $SIMDIR_PATH/$BASE_NAME

# Backup of the initial simulation files
cd $SIM_DIR
tar -cpf $BKP_PATH/$BASE_NAME/$BASE_NAME-initial.tar ./
gzip -9 $BKP_PATH/$BASE_NAME/$BASE_NAME-initial.tar

# Copy the simulation files in the Simulation folder
SIM_DIR_NAME=${SIM_DIR##*/}
cp -R $SIM_DIR $SIMDIR_PATH/$BASE_NAME/$SIM_DIR_NAME

# The simulation directory is now the new directory
SIM_DIR=$SIMDIR_PATH/$BASE_NAME/$SIM_DIR_NAME
cd $SIM_DIR

# New SIM_MAIN
SIM_MAIN_NAME=`basename $SIM_MAIN`
SIM_MAIN=$SIM_DIR/$SIM_MAIN_NAME

# Define the simulation command (can be adapted to other softwares)
case ${SIM_MAIN#*.} in
    "m")
	SIM_CMD='matlab -nodesktop -nodisplay -nosplash -r "run('\'$SIM_MAIN\'')"';
	;;
    "mos")
	SIM_CMD='matlab -nodesktop -nodisplay -nosplash -r "run('\'$SIM_MAIN\'')"';
	;;
    *)
	echo "Error";
	;;
esac

# Set the temporary file for the qsub script
QSUB_TMP=$SIM_DIR/../$BASE_NAME-qsub.sh

# Prepare the commands to be sent to the node
cat > $QSUB_TMP << end_of_QSUB_TMP
#!/bin/sh
# Core of the job
$SIM_CMD > $SIM_DIR/../$BASE_NAME-out.txt
end_of_QSUB_TMP

# Define the command to Pleiades
PLEIADES_TMP="qsub -l nodes=$NODES_NB:ppn=$PROC_NB,walltime=$TIME $QSUB_TMP"

# Send of the command to Pleiades
$PLEIADES_TMP >> /dev/null

# Definition of time limits
TIMEREF=`date +%s`
HOURS=`echo $TIME | cut -d ':' -f 1`
MINUTES=`echo $TIME | cut -d ':' -f 2`
SECONDS=`echo $TIME | cut -d ':' -f 3`
TIME_DURATION=$(( $HOURS * 3600 + $MINUTES * 60 + $SECONDS ))
TIME_LIMIT=$(( $TIMEREF + $TIME_DURATION ))

# Get the job number
CURRENT_JOB="`qstat -u $USER | tail -1 | cut -d '.' -f 1`"

MAIL_FILE=$SIM_DIR/../$BASE_NAME-mail.txt

# Prepare the sending to the screen env.
TIMELIMITSCRIPT=$SIM_DIR/../$BASE_NAME-timelimit.sh

cat > $TIMELIMITSCRIPT << end_of_TIMELIMITSCRIPT
#!/bin/sh
sleep $TIME_DURATION
rm -f $TIMELIMITSCRIPT
end_of_TIMELIMITSCRIPT

bash $TIMELIMITSCRIPT &

# Creation of the screen env.
screen -d -m -S $BASE_NAME
screen -S $BASE_NAME -X zombie qr

# Prepare the sending to the screen env.
SCREEN_SCRIPT=$SIM_DIR/../$BASE_NAME-screen.sh

cat > $SCREEN_SCRIPT << end_of_SCREEN_SCRIPT
#!/bin/sh

until [ -s $SIM_DIR/$BASE_NAME-qsub.sh.o$CURRENT_JOB ]; do
    sleep 15
done

mv $SIM_DIR/$BASE_NAME-qsub.sh.o$CURRENT_JOB $SIM_DIR/../$BASE_NAME-qsub_o$CURRENT_JOB.txt
mv $SIM_DIR/$BASE_NAME-qsub.sh.e$CURRENT_JOB $SIM_DIR/../$BASE_NAME-qsub_e$CURRENT_JOB.txt

if [ -s $TIMELIMITSCRIPT ]; then
    rm -f $TIMELIMITSCRIPT
    
    cd $SIM_DIR
    tar -cpf $BKP_PATH/$BASE_NAME/$BASE_NAME-$CURRENT_JOB.tar ./
    gzip -9 $BKP_PATH/$BASE_NAME/$BASE_NAME-$CURRENT_JOB.tar

    echo "Your job $CURRENT_JOB has been finished successfully on Pleiades." > $MAIL_FILE
    echo -e "You will find the archive of the results in your Pleiades home directory at the following path:\n$BKP_PATH/$BASE_NAME-$CURRENT_JOB.tar.gz" >> $MAIL_FILE
    echo -e "The simulation files are stored in your Pleiades home directory at the following path:\n$SIMDIR_PATH/$BASE_NAME\n" >> $MAIL_FILE
    echo -e "You can have a look at the Pleiades output file below:\n" >> $MAIL_FILE
    cat $SIM_DIR/../$BASE_NAME-qsub_o$CURRENT_JOB.txt >> $MAIL_FILE
    mail -s "[Pleiades] Job $CURRENT_JOB finished properly" -a $SIM_DIR/../$BASE_NAME-qsub_o$CURRENT_JOB.txt "$MAIL_ADR" < $MAIL_FILE
else
    echo "Your job $CURRENT_JOB has failed on Pleiades (time limit reached)." > $MAIL_FILE
    echo -e "You can have a look at the Pleiades output file below:\n" >> $MAIL_FILE
    cat $SIM_DIR/../$BASE_NAME-qsub_o$CURRENT_JOB.txt >> $MAIL_FILE
    mail -s "[Pleiades] Job $CURRENT_JOB failed (time limit reached)" -a $SIM_DIR/../$BASE_NAME-qsub_o$CURRENT_JOB.txt "$MAIL_ADR" < $MAIL_FILE
fi

qdel $CURRENT_JOB >> /dev/null

# kill the screen session
screen -X -S $BASE_NAME quit

end_of_SCREEN_SCRIPT

screen -S $BASE_NAME -X screen bash $SCREEN_SCRIPT

echo -e "\nYour job has the number $CURRENT_JOB.
The main file for this simulation is \"$SIM_MAIN\".
It has been queued for execution on $NODES_NB $NODES_DENOM of $PROC_NB $PROC_DENOM.
Time limit: $TIME.\n
REMINDER: \"qstat -u $USER\" (to check if your job is alive).
          \"qdel $CURRENT_JOB\" (to delete the job).
          \"screen -ls\" (to list the current screen sessions).
          \"screen -X -S $BASE_NAME quit\" (to kill the current simulation screen session).\n"
