SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v systolic_pe.v

ifeq ($(TOPLEVEL_LANG),verilog)
    VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
    ifneq ($(GATES),yes)
        COMPILE_ARGS += -DSIM
    endif
else
    $(error This testbench only supports Verilog)
endif

TOPLEVEL = tt_um_yourusername_systolic_array
MODULE = test

include $(shell cocotb-config --makefiles)/Makefile.sim
