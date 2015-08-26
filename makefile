# This is a convenience thing, on ARCHER it will default to GNU whereas locally to local (different mpi wrappers are used)
ifdef CRAYOS_VERSION
.DEFAULT_GOAL :=GNU
else
.DEFAULT_GOAL :=local
endif

CORE_DIR=model_core
COMPONENTS_DIR=components
TESTCASE_DIR=testcases
IO_SERVER_DIR=io
BUILD_DIR=build

export NETCDF_DIR=$(NETCDF_ROOT)
export HDF5_DIR=$(HDF5_ROOT)
export FFTW_DIR=$(FFTW_ROOT)
FTN=ftn

COMPILERFFLAGS=-O3
COMPILERRECURSIVE=
ACTIVE=-DU_ACTIVE -DV_ACTIVE -DW_ACTIVE -DUSE_MAKE
IO_SERVER_DEPENDENCY=
DEBUG_FLAGS=-g -fcheck=all -ffpe-trap=invalid,zero,overflow -fbacktrace -DDEBUG_MODE

FFLAGS=-I $(CORE_DIR)/$(BUILD_DIR) -I $(COMPONENTS_DIR)/$(BUILD_DIR) -I $(TESTCASE_DIR)/$(BUILD_DIR)

ifeq ($(USE_MONC_IO),1)
	IO_LIBRARY=-lmonc_io -lpthread
	ACTIVE+=-DIO_SERVER
	IO_SERVER_DEPENDENCY=compile-ioserver
	FFLAGS+=-I $(IO_SERVER_DIR)/$(BUILD_DIR)
	DEBUG_FLAGS=-g -fcheck=do,array-temps,bounds,mem,pointer -DDEBUG_MODE
endif

LFLAGS=-L$(NETCDF_DIR)/lib -L./io -L misc/forthreads -L$(FFTW_DIR)/lib -L$(HDF5_DIR)/lib -lnetcdff -lnetcdf -lhdf5 -lhdf5_hl -lz -lfftw3 $(IO_LIBRARY)
FFLAGS+=$(COMPILERFFLAGS)
EXEC_NAME=monc

local: FTN=mpif90
local: GNU

debug: COMPILERFFLAGS = $(DEBUG_FLAGS)
debug: OPT=$(ACTIVE)
debug: local

GNU: COMPILERFFLAGS += $(ACTIVE) -cpp -J $(BUILD_DIR) -c
GNU: COMPILERRECURSIVE= -frecursive
GNU: buildmonc

Cray: COMPILERFFLAGS += $(ACTIVE) -e m -J $(BUILD_DIR) -c
Cray: COMPILERRECURSIVE= -e R
Cray: buildmonc

Intel: COMPILERFFLAGS += $(ACTIVE) -fpp -free -c -std03 -module $(BUILD_DIR) -Tf
Intel: COMPILERRECURSIVE= -recursive
Intel: buildmonc

IBM: FTN=mpxlf2003_r
IBM: ACTIVE:= $(foreach option,$(ACTIVE),-WF,$(option))
IBM: COMPILERFFLAGS = $(ACTIVE) -cpp -qmoddir=$(BUILD_DIR) -c
IBM: COMPILERRECURSIVE= -qrecur
IBM: buildmonc

export COMPILERFFLAGS
export COMPILERRECURSIVE
export FTN

clean: clean-model_core clean-components clean-testcases clean-ioserver
	rm -Rf build/*


clean-build: clean-build-model_core clean-build-components clean-build-testcases clean-build-ioserver
	rm -Rf build

buildmonc: check-vars create-build-dirs compile-model_core compile-components compile-testcases $(IO_SERVER_DEPENDENCY) compile-bootstrapper
	$(FTN) -o $(EXEC_NAME) $(BUILD_DIR)/*.o $(CORE_DIR)/$(BUILD_DIR)/*.o $(COMPONENTS_DIR)/$(BUILD_DIR)/*.o $(TESTCASE_DIR)/$(BUILD_DIR)/*.o $(LFLAGS)

check-vars:
	$(call check_defined, NETCDF_DIR, Need the path to the NetCDF installation directory as an environment variable - export this before running make)
	$(call check_defined, HDF5_DIR, Need the path to the HDF5 installation directory as an environment variable - export this before running make)
	$(call check_defined, FFTW_DIR, Need the path to the FFTW installation directory as an environment variable - export this before running make)

create-build-dirs:
	mkdir -p $(BUILD_DIR)

compile-model_core:	
	cd $(CORE_DIR) ; $(MAKE)

clean-model_core:
	cd $(CORE_DIR); $(MAKE) clean 

clean-build-model_core:
	cd $(CORE_DIR); $(MAKE) clean-build

compile-components:
	cd $(COMPONENTS_DIR) ; $(MAKE)

clean-components:
	cd $(COMPONENTS_DIR); $(MAKE) clean 

clean-build-components:
	cd $(COMPONENTS_DIR); $(MAKE) clean-build

compile-testcases:
	cd $(TESTCASE_DIR) ; $(MAKE)

clean-testcases:
	cd $(TESTCASE_DIR); $(MAKE) clean 

clean-build-testcases:
	cd $(TESTCASE_DIR); $(MAKE) clean-build

compile-ioserver:
	cd $(IO_SERVER_DIR) ; $(MAKE)

clean-ioserver:
	cd $(IO_SERVER_DIR) ; $(MAKE) clean

clean-build-ioserver:
	cd $(IO_SERVER_DIR) ; $(MAKE) clean-build

compile-bootstrapper:
	$(FTN) $(FFLAGS) monc_driver.F90 -o $(BUILD_DIR)/monc_driver.o

# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
#
# Params:
#   1. Variable name(s) to test.
#   2. (optional) Error message to print.
check_defined = \
    $(foreach 1,$1,$(__check_defined))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $(value 2), ($(strip $2)))))
