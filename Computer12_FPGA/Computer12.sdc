create_clock -name main_clock -period 20ns [get_ports {clk50}]
derive_pll_clocks
derive_clock_uncertainty
