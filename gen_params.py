#!/usr/bin/env python3

# Inspired from work by Fricke, Jencka, and Adams

import os
import sys
from itertools import product

X = range(8, 176, 16)
Y = range(8, 176, 16)
Z = range(8, 176, 24)
TIME = (300,)
SLURM_NNODES = (1, 2, 4, 6, 8, 16)
SLURM_NTASKS_PER_NODE = (1, 2, 4, 8, 16, 32)
OMP_THREADS = (1, 2, 4, 8, 16, 32)
GPUS_PER_NODE = (0, 1, 2)

all_combinations = list(product(X, Y, Z, TIME))

def csv():
    for args in all_combinations:
        print(','.join(str(x) for x in args))
        
def slurm(input_path):
    with open(input_path, 'r') as f:
        input = f.read()
        
    dir = os.path.dirname(os.path.normpath(input_path))
    if dir == "":
        dir = "."
    elif dir == "/":
        dir = "/."
    
    for args in product(SLURM_NNODES, SLURM_NTASKS_PER_NODE, OMP_THREADS, GPUS_PER_NODE):
        # hopper
        if args[1] * args[2] > 32 or args[3] > 2:
            continue
        
        if args[3] > 0 and (args[2] != 1 or args[1] != args[3]):
            continue
        
        SWEEP = ""
        valid = 0
        for ind, params in enumerate(all_combinations):
            x = params[0]
            y = params[1]
            z = params[2]

            if float(min(x, y, z)) / float(max(x, y, z)) < 0.125:
                continue

            if args[3] > 0:
                if ((x * y * z * 8.0) / (10 ** 9)) > 38:
                    continue
            else:
                if ((x * y * z * 8.0) / (10 ** 9)) * args[1] > 85:
                    continue
            SWEEP += str(ind + 1) + ","
            valid = valid + 1

        print("valid: ", valid)

        if len(SWEEP) > 0 and SWEEP[-1] == ",":
            SWEEP = SWEEP[:-1]
            
        if len(SWEEP) == 0:
            continue
        
        new_input = input.replace("<PARAM_NNODES>", str(args[0])) \
                              .replace("<PARAM_NTASKSPERNODE>", str(args[1])) \
                              .replace("<PARAM_CPUSPERTASK>", str(args[2])) \
                              .replace("<PARAM_GPUSPERNODE>", str(args[3])) \
                              .replace("<SWEEP>", SWEEP)

        save_path = dir + "/parameter_sweep_array_nnodes" + str(args[0]) \
                                                   + "_ntaskspernode" + str(args[1]) \
                                                   + "_cpuspertask" + str(args[2]) \
                                                   + "_gpuspernode" + str(args[3]) \
                                                   + ".slurm"
        
        with open(save_path, 'w') as f:
            f.write(new_input)
        
if __name__ == "__main__":
    if sys.argv[1] == "csv":
        csv()
    elif sys.argv[1] == "slurm":
        slurm(sys.argv[2])
    else:
        print("csv will print params.csv to stdout")
        print("slurm <path to parameter_sweep_array_template.slurm> will create slurm scripts for " + 
              "nodes, ntasks per node, omp threads, gpus per node sweep in same dir")

# LOG OF SWEEPS:

# Hopper:

# Sweep 1: Ran:
# 
# ----
# 
