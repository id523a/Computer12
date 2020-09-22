create_clock -name clk50 -period 20ns [get_ports {clk50}]

create_generated_clock -name {clk36} -source [get_pins {main_pll_1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 18 -divide_by 25 -master_clock {clk50} [get_pins {main_pll_1|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name state0 -edges {1 3 7} -master_clock {clk36} -source [get_pins {main_pll_1|altpll_component|auto_generated|pll1|clk[0]}] [get_nets {Processor12:CPU|state[0]}]
create_generated_clock -name state1 -edges {3 5 9} -master_clock {clk36} -source [get_pins {main_pll_1|altpll_component|auto_generated|pll1|clk[0]}] [get_nets {Processor12:CPU|state[1]}]
create_generated_clock -name state2 -edges {5 7 11} -master_clock {clk36} -source [get_pins {main_pll_1|altpll_component|auto_generated|pll1|clk[0]}] [get_nets {Processor12:CPU|state[2]}]

derive_clock_uncertainty