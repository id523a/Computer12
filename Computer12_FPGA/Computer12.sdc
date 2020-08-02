create_clock -name main_clock -period 50ns [get_ports {clk}]
derive_pll_clocks
derive_clock_uncertainty
