Steps for getting Python environment set up to run PSCAD from Julia (using PyCall) 

- Download Anaconda: https://www.anaconda.com/
- Open an Anaconda prompt for subseuquent commands 
- run 'conda create -n pscad_v5 python=3.7' (note: do not change the name of the environment)
- run 'conda activate pscad_v5'
- run 'pip install numpy'
- run 'pip install pywin32'
- run 'pip install mhi-pscad'
- change PYTHON_PATH constant in file in this repository /PSCAD/constants.jl to point to the python executable in your new conda environment.
- run script run_pscad.jl. After running once you will need to restart your Julia REPL for PyCall to build correctly with the new version of python. 
- Upon restart, run_pscad.jl should run without errors. 

Steps for updating mhi-common and mhi-pscad

- Navigate to your conda environment in the Anaconda prompt
- run 'pip install --upgrade mhi-common'
- run 'pip install --upgrade mhi-pscad'
- use 'pip list' to see the list of currently installed versions.

Usefull conda commands 
'conda info --envs' : list the conda environments 
'conda activate <env_name>' : activate your environment 
'conda list' : list all linked packages in the active environment 
`conda env remove -n <env_name>' : remove (delete) a conda environment

Making a new case in PSCAD 
- Copy the file directory structure from existing case ("pscad_files", "psid_files", "src", "test")
- Make a new workspace file is PSCAD.
- Open libraries in the new workspace from PSID2PSCAD/_pscad_libraries folder.
- To copy and modify an existing case, save case with new name in the new directory. 
- Unload the case in the old workspace and re-load the original case.
- Load the new case in the new workspace. 