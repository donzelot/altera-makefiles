
CUR_FILE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

ifdef MODELSIM_BIN_PATH
	VMAP := $(MODELSIM_BIN_PATH)/vmap
	VLIB := $(MODELSIM_BIN_PATH)/vlib
	VLOG := $(MODELSIM_BIN_PATH)/vlog
	VCOM := $(MODELSIM_BIN_PATH)/vcom
	VSIM := $(MODELSIM_BIN_PATH)/vsim
else
	VMAP := vmap
	VLIB := vlib
	VLOG := vlog
	VCOM := vcom
	VSIM := vsim
endif

VSIM_CMD = $(VSIM) -c -onfinish exit
VSIM_GUI = $(VSIM) -gui -onfinish stop

ifdef QUARTUS_PATH
	QSYS_GEN  := $(QUARTUS_PATH)/sopc_builder/bin/qsys-generate
	QSYS_EDIT := $(QUARTUS_PATH)/sopc_builder/bin/qsys-edit
else
	QSYS_GEN  := qsys-generate
	QSYS_EDIT := qsys-edit
endif

ifndef PYTHON3
PYTHON3 := python
endif

# -----------------------------------------------------------------
# Main target
# -----------------------------------------------------------------
#

all: sim

# -----------------------------------------------------------------
# Compile QSys source files
# -----------------------------------------------------------------
#

ifdef QSYS_LIB_PATH
QSYS_LIB_PATH := $(QSYS_LIB_PATH),$$
else
QSYS_LIB_PATH := $$
endif

QSYS_OUT_DIR = .qsys_out
QSYS_NAMES = $(basename $(notdir $(QSYS_SRC)))
QSYS_MSIMCOM_TCL = $(foreach i, $(QSYS_NAMES), $(QSYS_OUT_DIR)/$i_msim.tcl)
QSYS_MSIMCOM_LOG = $(foreach i, $(QSYS_NAMES), $(QSYS_OUT_DIR)/$i_msim.log)

.SECONDARY: $(QSYS_MSIMCOM_TCL)
$(QSYS_OUT_DIR)/%_msim.tcl : %.qsys
	# Generate simulation files for *.qsys
	$(QSYS_GEN) $^ -sim=VERILOG  \
		-sp=$(QSYS_LIB_PATH)     \
		-od="$(QSYS_OUT_DIR)/$(basename $(notdir $^))"

	# Generate simulation script from *.spd
	$(PYTHON3) $(CUR_FILE_DIR)/spd2msimtcl.py \
		-od=$(QSYS_OUT_DIR)/$(basename $(notdir $^)) \
		-spd=$(QSYS_OUT_DIR)/$(basename $(notdir $^))/$(basename $(notdir $^)).spd \
		-tcl=$@

$(QSYS_OUT_DIR)/%_msim.log: $(QSYS_OUT_DIR)/%_msim.tcl
	$(VSIM_CMD) -do $^
	touch $@

qsyscom: $(QSYS_MSIMCOM_LOG)

.PHONY: qsyscom_force
qsyscom_force: $(QSYS_MSIMCOM_TCL)
	$(VSIM_CMD) -do $^

qsysclean:
	rm -rf $(QSYS_OUT_DIR)
	rm -rf libraries
	rm -rf .qsys_edit
	rm -f  *.sopcinfo

# Run qsys-edit without Quartus
qsysedit:
	$(QSYS_EDIT)

qsystest:
	@echo $(QSYS_NAMES)
	@echo $(QSYS_MSIMCOM_TCL)
	@echo $(QSYS_MSIMCOM_LOG)

.PHONY: qsysclean qsysedit qsystest

ifdef QSYS_SRC
QSYS_PKG_LIBS = $(addprefix -L , $(QSYS_NAMES))
VLOG_OPT += $(QSYS_PKG_LIBS)
VSIM_OPT += $(QSYS_PKG_LIBS)
endif

# -----------------------------------------------------------------
# Compile HDL source files
# -----------------------------------------------------------------
#

RTL_LIBRARY  = work
DEPS_DIR     = .deps

$(DEPS_DIR):
	mkdir -p $(DEPS_DIR)

$(RTL_LIBRARY):
	$(VLIB) $(RTL_LIBRARY)
	$(VMAP) $(RTL_LIBRARY) $(RTL_LIBRARY)


COM_LOG_FILES = $(addprefix $(DEPS_DIR)/, \
					$(addsuffix .log,$(HDL_SRC)))

$(DEPS_DIR)/%.sv.log: %.sv
	$(VLOG) -sv -work $(RTL_LIBRARY) $(VLOG_OPT) $^
	touch $@

$(DEPS_DIR)/%.v.log: %.v
	$(VLOG) -sv -work $(RTL_LIBRARY) $(VLOG_OPT) $^
	touch $@

$(DEPS_DIR)/%.vhd.log: %.vhd
	$(VCOM) -work $(RTL_LIBRARY) $(VCOM_OPT) $^
	touch $@


# -----------------------------------------------------------------
# Compile all design files
# -----------------------------------------------------------------
#

.PHONY: com
com: $(RTL_LIBRARY) $(DEPS_DIR) qsyscom $(COM_LOG_FILES)

# -----------------------------------------------------------------
# Run simulation
# -----------------------------------------------------------------
#

# List of SV DPI dynamyc libraries
ifdef SV_DPI_LD_LIBS
SV_DPI_LD_LIBS_VSIM_OPT = $(foreach i, $(SV_DPI_LD_LIBS), -sv_lib $i)
endif

VSIM_RUN_SCRIPT = .run.tcl

sim: com $(VSIM_RUN_SCRIPT)
	$(VSIM_CMD) -do $(VSIM_RUN_SCRIPT)

gui: com $(VSIM_RUN_SCRIPT)
	$(VSIM_GUI) -do $(VSIM_RUN_SCRIPT)

$(VSIM_RUN_SCRIPT): $(CUR_FILE_DIR)/alias.tcl
	@echo "set MAKE_CMD {$(MAKE)}" > $@
	@echo "source $(CUR_FILE_DIR)/alias.tcl" >> $@
	@echo "vsim -GSEED=[clock seconds] -L $(RTL_LIBRARY) $(VSIM_OPT) $(RTL_LIBRARY).$(TOP_ENTITY) $(SV_DPI_LD_LIBS_VSIM_OPT)" >> $@
ifdef PRE_RUN_SCRIPT
	@echo "source $(PRE_RUN_SCRIPT)" >> $@
endif
	@echo "run -all" >> $@
ifdef POST_RUN_SCRIPT
	@echo "source $(POST_RUN_SCRIPT)" >> $@
endif

# -----------------------------------------------------------------
# Clean work directory
# -----------------------------------------------------------------
#

.PHONY: clean
clean: qsysclean
	rm -rf $(RTL_LIBRARY)
	rm -rf $(DEPS_DIR)
	rm -f  $(VSIM_RUN_SCRIPT)
	rm -f  modelsim.ini
	rm -f  transcript
	rm -f  *.wlf
	rm -f  wlf*
	rm -f  *.vcd