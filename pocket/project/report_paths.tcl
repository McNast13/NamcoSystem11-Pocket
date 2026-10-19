# Post-compile path reports (run by the shell workflow): worst setup paths into every clock, whatever the launch clock.
project_open [lindex $quartus(args) 0]
create_timing_netlist -model slow
read_sdc
update_timing_netlist
foreach_in_collection c [get_clocks] {
    set n [get_clock_info -name $c]
    set f [string map {| _ : _ ~ _ [ _ ] _ * _ . _} $n]
    report_timing -setup -to_clock $c -npaths 12 -detail full_path -file output_files/paths.setup.$f.rpt
    report_timing -setup -to_clock $c -npaths 300 -detail summary -file output_files/paths.summary.$f.rpt
}
report_clocks -file output_files/paths.clocks.rpt
delete_timing_netlist
project_close
