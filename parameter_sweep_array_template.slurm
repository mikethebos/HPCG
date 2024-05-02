#!/bin/bash

# Inspired from work by Fricke, Jencka, and Adams

#SBATCH --job-name HPCG_ParamSweep
#SBATCH --partition condo
#SBATCH --time 00:10:00
#SBATCH --nodes <PARAM_NNODES>
#SBATCH --ntasks-per-node <PARAM_NTASKSPERNODE>
#SBATCH --cpus-per-task <PARAM_CPUSPERTASK>
#SBATCH --gpus-per-node <PARAM_GPUSPERNODE>
#SBATCH --mem 88GB
#SBATCH --array <SWEEP>

# Load the required packages (gcc 11 and HPL)
if [ "$SLURM_GPUS_PER_NODE" -gt "0" ]; then
    module load singularity
else
    module load intel/20.0.4 hpcg
fi

export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores

# Set a place to record the results
RESULTS_FILE=$SLURM_SUBMIT_DIR/results.csv

PARAMS_FILE=$SLURM_SUBMIT_DIR/params.csv
TEMPLATE_FILE=$SLURM_SUBMIT_DIR/hpcg_template.dat

# Check for errors
if test -f $PARAMS_FILE; then
    echo Using parameter file $PARAMS_FILE
else
    echo Error $PARAMS_FILE not found
    exit 1
fi

if test -f $TEMPLATE_FILE; then
    echo Using template file $TEMPLATE_FILE
else
    echo Error $TEMPLATE_FILE not found
    exit 2
fi
    
# Get the Nth line from our parameter file - where N is the array ID
PARAMS=$(head -n $SLURM_ARRAY_TASK_ID $PARAMS_FILE | tail -n 1 | tr ',' ' ')
echo Read param line $SLURM_ARRAY_TASK_ID: $PARAMS

read -r X Y Z TIME <<<$(echo $PARAMS)

# Create a new working directory for each instance of hpcg since it needs it expects it's own hpcg.dat
SCRATCH_DIR=/carc/scratch/users/$USER

# Make a temporary directory for our work - we will delete this at the end
TMP_DIR=$(mktemp --directory -p $SCRATCH_DIR)
echo Temp directory: $TMP_DIR

# Make a subdirectory with the SLURM array task id to make debugging easier
TMP_WORKING_DIR=$TMP_DIR/$SLURM_ARRAY_TASK_ID
mkdir -p $TMP_WORKING_DIR
echo Created temporary working directory: $TMP_WORKING_DIR

# Make the new working directory the current directory so hpcg runs in there
cd $TMP_WORKING_DIR
echo Now running in $PWD

# Fill out template file
echo "HPCG benchmark input file
Sandia National Laboratories; University of Tennessee, Knoxville
$X $Y $Z
$TIME" > hpcg.dat

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

echo Running hpcg in $TMP_WORKING_DIR...
if [ "$SLURM_GPUS_PER_NODE" -gt "0" ]; then
    srun --nodes $SLURM_NNODES --ntasks-per-node $SLURM_NTASKS_PER_NODE --cpus-per-task $OMP_NUM_THREADS --gpus-per-node $SLURM_GPUS_PER_NODE --mpi=pmi2 singularity run --nv --bind .:/my-dat-files,$SLURM_SUBMIT_DIR:/my-scripts $SLURM_SUBMIT_DIR/hpc.sif /my-scripts/hpcg.sh --dat /my-dat-files/hpcg.dat > hpcg.out
else
    srun --nodes $SLURM_NNODES --ntasks-per-node $SLURM_NTASKS_PER_NODE --cpus-per-task $OMP_NUM_THREADS --gpus-per-node $SLURM_GPUS_PER_NODE --mpi=pmi2 xhpcg
    mv HPCG-Benchmark_3.1_*.txt hpcg.out
fi
echo hpcg finished

# The HPL.dat file tells xhpl to write to HPL.out.
# Extract the throughput with grep and awk

# 1. Find the line containing GFLOP/s and print it
RESULT_DATA_LINE=$(grep "HPCG result is VALID with a GFLOP/s rating of=" hpcg.out)
echo Results: $RESULT_DATA_LINE

# 2. Get the last field in the data line, that's the Gigaflops.
# https://unix.stackexchange.com/questions/24140/return-only-the-portion-of-a-line-after-a-matching-pattern
GFLOPS=$(echo $RESULT_DATA_LINE | sed -n -e 's@^.*HPCG result is VALID with a GFLOP/s rating of=@@p')
if [ ! -z "${GFLOPS}" ]; then

    echo Results Gflops: $GFLOPS 

    echo Writing input parameters and gflops to $RESULTS_FILE
    echo $X, $Y, $Z, $TIME, $SLURM_NNODES, $SLURM_NTASKS_PER_NODE, $OMP_NUM_THREADS, $SLURM_GPUS_PER_NODE, $GFLOPS >> $RESULTS_FILE

    # Clean up the temporary working directory
    rm -r $TMP_DIR
    echo Deleted $TMP_DIR

fi
