#!/bin/bash
########################################################################
## Copyright (C) 2010 Jean-Baptiste Carré (speredenn)
##                   <jean-baptiste.carre@gadz.org>
## Time-stamp: <2010-08-02 11:33:29 (speredenn)>
##
## Pleiades-archive_simulations.sh
##
## Description: This script has been written to finish the job started
##              by the launching script "Pleiades-launch_simulation.sh"
##              It looks for the qsub files that Pleiades produces at
##              the end of a batch job, save then in the simulation
##              folder created by the launching script, and archive the
##              whole folder to the backup directory.
##              This script do the archiving job for every simulation
##              that is eligible (aka: finished).
## Keywords: backup; formatting results; simulation; Pleiades; EPFL
## Commentary: Pleiades is the name of one of the EPFL super-computers
##             used for heavy computational operations.
##             <http://pleiades.epfl.ch/>
##
########################################################################
## This file is free software licensed under the terms of the
## GNU General Public License, version 3 or later.
## More information on:
## http://www.gnu.org/licenses/gpl-3.0.txt
########################################################################
## Code:

# Backup and simulation paths (absolute path needed, without ending /):
# TODO: Add a test for this last / question...
BACKUP_PATH="$HOME/backups"
SIMULATIONS_PATH="$HOME/simulations"
TRASH_PATH="$HOME/trash"
#########################################################################

echo -e "\nYou are using Bash version ${BASH_VERSION}...\n"

# Check the directories

if [ -d $BACKUP_PATH ]; then
    echo "Backup directory... OK ($BACKUP_PATH)"
else
    echo "Backup directory do not exist at path $BACKUP_PATH."
    echo "Check you BACKUP_PATH variable or launch your simulation before using this script."
    exit
fi

if [ -d $SIMULATIONS_PATH ]; then
    echo "Simulation directory... OK ($SIMULATIONS_PATH)"
else
    echo "Simulation directory do not exist at path $SIMULATIONS_PATH"
    echo "Check you BACKUP_PATH variable or launch your simulation before using this script."
    exit
fi

if [ -d $TRASH_PATH ]; then
    echo -e "Trash directory... OK ($TRASH_PATH)\n"
else
    mkdir -p $TRASH_PATH
    echo -e "Trash directory created at path $TRASH_PATH.\n"
fi

#########################################################################

# Find the qsub files that have to be moved
find -P $HOME -path '.*' -prune -o -path "$SIMULATIONS_PATH" -prune -o -path "$TRASH_PATH" -prune -o -name "*.qsub.*" -fprint $HOME/test.log
NUMBER_FILES=`wc -l $HOME/test.log | cut -d ' ' -f 1`

# Move the qsub files
VAR1=1
while [ $VAR1 -ne $(( NUMBER_FILES + 1)) ];do
   FILE=`sed -n "$VAR1","$VAR1"p "$HOME"/test.log`
   BASE=`basename $FILE`
   BASENAME=${BASE%%.*}
   if [ -d $SIMULATIONS_PATH/$BASENAME ]; then
      mv -q $FILE $SIMULATIONS_PATH/$BASENAME
   else
      mv $FILE $TRASH_PATH
   fi
   VAR1=$(( VAR1 + 1 ))
done

# Get the information needed to prepare the archiving operations
cd $SIMULATIONS_PATH
rm -f $HOME/test2.log
for i in $(ls -d */); do echo ${i%%/}; done >> $HOME/test2.log
NUMBER_DIR=`wc -l $HOME/test2.log | cut -d ' ' -f 1`

# Archive what needs to be archived
VAR2=1
while [ $VAR2 -ne $(( NUMBER_DIR + 1)) ];do
   DIR=`sed -n "$VAR2","$VAR2"p "$HOME"/test2.log`
   if [ -s $BACKUP_PATH/$DIR.tar.gz ]; then
      echo "$DIR has already been archived... Skipping!"
   else
      if [ -s $SIMULATIONS_PATH/$DIR/$DIR.qsub.o* ]; then
         cd $SIMULATIONS_PATH
         tar -cpf $BACKUP_PATH/$DIR.tar $DIR
         gzip -9 $BACKUP_PATH/$DIR.tar
         echo "$DIR has been archived in the backup directory."
      else
         echo "$DIR is not a complete folder yet and has not been archived (the output file is missing)."
      fi
   fi
   VAR2=$(( VAR2 + 1 ))
done

# Delete temporary files
rm -f $HOME/test.log $HOME/test2.log

# The end
echo -e "\nThe archiving operations have been executed successfully."
