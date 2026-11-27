IVERILOG ?= iverilog
VVP ?= vvp
CLK_MHZ ?= 1

.PHONY: sim
sim:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s tb_obstacle_warning -Ptb_obstacle_warning.CLK_MHZ=$(CLK_MHZ) -o build/sim.vvp rtl/obstacle_warning.v sim/tb_obstacle_warning.v
	$(VVP) build/sim.vvp

SWIFTC ?= swiftc
GUI_DIR = build/CanhBaoVatCan.app/Contents
GUI_APP = $(GUI_DIR)/MacOS/CanhBaoVatCan
GUI_SIM = build/gui.vvp

.PHONY: gui gui-build
gui: gui-build
	./$(GUI_APP) "$(VVP)" "$(GUI_SIM)"

gui-build: $(GUI_APP) $(GUI_DIR)/Info.plist $(GUI_DIR)/Resources/gui.vvp

$(GUI_APP): gui/CanhBaoVatCan.swift gui/Simulation.swift Makefile
	mkdir -p $(@D)
	$(SWIFTC) -parse-as-library -module-cache-path build/swift-cache -o $@ gui/CanhBaoVatCan.swift gui/Simulation.swift

$(GUI_DIR)/Info.plist: gui/Info.plist
	mkdir -p $(@D)
	cp $< $@

$(GUI_DIR)/Resources/gui.vvp: $(GUI_SIM)
	mkdir -p $(@D)
	cp $< $@

$(GUI_SIM): rtl/obstacle_warning.v sim/tb_obstacle_gui.v Makefile
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s tb_obstacle_gui -o $@ rtl/obstacle_warning.v sim/tb_obstacle_gui.v
