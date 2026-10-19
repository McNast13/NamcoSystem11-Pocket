# Post-fit timing report for the probe (run by run.sh when STA=1). Writes output_files/probe.sta.*.rpt
project_open probe
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_clocks -file output_files/probe.sta.clocks.rpt
report_clock_fmax_summary -file output_files/probe.sta.fmax.rpt
report_timing -setup -npaths 40 -detail summary -file output_files/probe.sta.setup.rpt
report_timing -hold  -npaths 20 -detail summary -file output_files/probe.sta.hold.rpt
foreach_in_collection c [get_clocks] {
   set n [get_clock_info -name $c]
   set f [string map {| _ : _ ~ _ [ _ ] _ * _} $n]
   report_timing -setup -from_clock $c -to_clock $c -npaths 8 -detail full_path -file output_files/probe.sta.setup.$f.rpt
}
report_timing -setup -npaths 1 -detail full_path -file output_files/probe.sta.worst.rpt
check_timing -include {no_clock unconstrained_paths} -file output_files/probe.sta.check.rpt
delete_timing_netlist
project_close
