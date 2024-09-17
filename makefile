#---------------------------------------------------------------------
# Makefile for compile Verilog-Sources for IVerilog and Vivado
# Herzog Cyril
# 30.10.23
#---------------------------------------------------------------------

# IVERILOG
CC         = iverilog
FLAGS      = -g2005
HDL_PATH   = src/hdl
ICARUS_DIR = sim/icarus

# VIVADO
VIVADO_BIN = C:/xilinx/Vivado/2023.1/bin/vivado.bat
BUILD_TCL  = build.tcl
PROG_TCL   = prog.tcl

.PHONY: no_module
no_module:
ifndef MAKECMDGOALS 
	@echo "Specify a module name, e.g., 'mingw32-make uart' or 'mingw32-make wave uart"
	@exit 1
endif

define basic_source
$$(HDL_PATH)/$(1)/$$(ICARUS_DIR)/$(1): \
    $$(wildcard $$(HDL_PATH)/global_functions.vh) \
	$$(wildcard $$(HDL_PATH)/lvds_transceiver/include/xilinx/*.v) \
	$$(wildcard $$(HDL_PATH)/$(1)/include/*.vh) \
	$$(wildcard $$(HDL_PATH)/$(1)/include/xilinx/*.v) \
	$$(wildcard $$(HDL_PATH)/$(1)/sim/*.v) \
	$$(wildcard $$(HDL_PATH)/$(1)/*.v)
	$$(CC) $$(FLAGS) -o $$@ $$^

.PHONY: $(1)
$(1): $$(HDL_PATH)/$(1)/$$(ICARUS_DIR)/$(1)
	$$(eval MODULE = $$($(1)_MODULE))
endef




$(eval $(call basic_source ,uart))
$(eval $(call basic_source ,cdc))
$(eval $(call basic_source ,test_core))
$(eval $(call basic_source ,lvds_transceiver))



wave:
    ifeq ($(filter $(MAKECMDGOALS),$(filter-out wave,$(MAKECMDGOALS))),) 
	@echo "Specify a module for the 'wave' target, e.g., 'mingw32-make wave uart'"
	@exit 1
    endif
	cd $(HDL_PATH)/$(filter-out wave,$(MAKECMDGOALS)) && \
	vvp $(ICARUS_DIR)/$(filter-out wave,$(MAKECMDGOALS))
	cd $(HDL_PATH)/$(filter-out wave,$(MAKECMDGOALS)) && \
	gtkwave $(ICARUS_DIR)/$(filter-out wave,$(MAKECMDGOALS)).vcd


# Vivado 
.PHONY: build prog

build:
	$(VIVADO_BIN) -mode batch -source $(BUILD_TCL)

prog:
	$(VIVADO_BIN) -mode batch -source $(PROG_TCL)


	