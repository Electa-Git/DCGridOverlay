using JSON
using JSON3
using CbaOPF
using Plots
using LaTeXStrings

include("create_grid_and_opf_functions.jl")
include("processing_results_function.jl")

#########################################################################################################################
# One can choose the Pmax of the conv_power among 2.0, 4.0 and 8.0 GW
conv_power = 6.0
########################################################################
# Uploading test case
########################################################################
test_case_file = "DC_overlay_grid_$(conv_power)_GW_convdc.json"
test_case = _PM.parse_file("./test_cases/$test_case_file")

z_base = (380*10^3)^2/(10^6*10^2)

########################################################################
# Uploading results
########################################################################
results_file_ac = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/results/result_one_year_AC_grid.json"
results_file_ac_corrected = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/results/result_one_year_AC_grid_corrected.json"
results_file_ac_dc = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/results/result_one_year_AC_DC_grid.json"

#results_AC = Dict()
#open(results_file_ac, "r") do f
#    global results_AC
#    dicttxt = read(f,String)  # file information to string
#    results_AC=JSON.parse(dicttxt)  # parse and transform data
#end

results_AC_corrected = Dict()
open(results_file_ac_corrected, "r") do f
    global results_AC_corrected
    dicttxt = read(f,String)  # file information to string
    results_AC_corrected=JSON.parse(dicttxt)  # parse and transform data
end


results_AC_DC = Dict()
open(results_file_ac_dc, "r") do f
    global results_AC_DC
    dicttxt_ = read(f,String)  # file information to string
    results_AC_DC=JSON.parse(dicttxt_)  # parse and transform data
end

########################################################################
# Computing the total generation costs
########################################################################
obj_ac = sum(r["objective"]*100 for (r_id,r) in results_AC)

obj_ac_corrected = sum(r["objective"]*100 for (r_id,r) in results_AC_corrected)

obj_ac_dc = sum(r["objective"]*100 for (r_id,r) in results_AC_DC)

benefit = (obj_ac - obj_ac_dc)/10^9

print("The total generation costs for the selected year for the AC/DC grid are $(obj_ac_dc/10^9) billions","\n")
print("The total generation costs for the selected year for the AC grid are $(obj_ac/10^9) billions","\n")
print("The total benefits for the selected year are $(benefit) billions","\n")

########################################################################
# Computing VOLL for each hour
########################################################################
hourly_voll_ac = []
hourly_voll_ac_dc = []

compute_VOLL(test_case,8760,results_AC_corrected,hourly_voll_ac)
compute_VOLL(test_case,8760,results_AC_DC,hourly_voll_ac_dc)

print("The total load curtailment for the selected year for the AC/DC grid is $(sum(hourly_voll_ac_dc)) MWh","\n")
print("The total load curtailment for the selected year for the AC grid is $(sum(hourly_voll_ac)) MWh","\n")


########################################################################
# Computing CO2 emissions for each hour
########################################################################
# Adding and assigning generator values
gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx = gen_values()
assigning_gen_values(test_case)

hourly_CO2_ac = []
hourly_CO2_ac_dc = []

compute_CO2_emissions(test_case,8760,results_AC_corrected,hourly_CO2_ac)
compute_CO2_emissions(test_case,8760,results_AC_DC,hourly_CO2_ac_dc)

CO2_reduction = (sum(hourly_CO2_ac)-sum(hourly_CO2_ac_dc))/10^6 # Mton

print("The total CO2 emissions for the selected year for the AC/DC grid are $(sum(hourly_CO2_ac_dc)/10^6) Mton","\n")
print("The total CO2 emissions for the selected year for the AC grid are $(sum(hourly_CO2_ac)/10^6) Mton","\n")
print("The reduction of the CO2 emissions for the selected year are $(CO2_reduction) Mton","\n")
########################################################################
# Computing RES generation for each hour
########################################################################
hourly_RES_ac = []
hourly_RES_ac_dc = []

compute_RES_generation(test_case,8760,results_AC_corrected,hourly_RES_ac) # MWh
compute_RES_generation(test_case,8760,results_AC_DC,hourly_RES_ac_dc) # MWh

hourly_RES_ac_GWh = hourly_RES_ac/10^3
hourly_RES_ac_dc_GWh = hourly_RES_ac_dc/10^3
hours = collect(1:8760)

p2 = Plots.plot(hours, hourly_RES_ac_GWh, legend=:outertopright, label = "RES AC",xlabel = "Hours",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "RES Generation [GW]",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, hourly_RES_ac_dc_GWh, legend=:bottomleft, label = "RES AC/DC",xlabel = "Hours",xguidefontsize=10,seriesalpha = 0.7,xtickfont = "Computer Modern",ylabel = "RES Generation [GW]",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))

plot_filename = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/Report/Figures/RES_generation_hour.pdf"

Plots.savefig(p2, plot_filename)

diff = hourly_RES_ac_dc_GWh - hourly_RES_ac_GWh

p3 = Plots.plot(hours, diff, legend=:outertopright, label = "RES AC",xlabel = "Hours",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "RES Generation [GW]",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))

sum(hourly_RES_ac_dc_GWh)/10^3 #TWh
sum(hourly_RES_ac_GWh)/10^3 #TWh
sum(diff)/8760

findmax(diff)
diff[600]


RES_curtailment = (sum(hourly_RES_ac_dc)-sum(hourly_RES_ac)) # MWh
RES_curtailment_GWh = RES_curtailment/10^3


RES_curtailment_GWh/(sum(hourly_RES_ac)/10^3)

print("The total RES generation for the selected year for the AC/DC grid are $(sum(hourly_RES_ac_dc)/10^9) TWh","\n")
print("The total RES generation for the selected year for the AC grid are $(sum(hourly_RES_ac)/10^9) TWh","\n")
print("The curtailment of the RES generation for the selected year are $(RES_curtailment/10^6) TWh","\n")

### Computing RES integration in the asynchronous zones
## The asynchronous zones are:
# Zone 1: UK
hourly_RES_ac_1 = []
hourly_RES_ac_dc_1 = []
hourly_non_RES_ac_1 = []
hourly_non_RES_ac_dc_1 = []
compute_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_RES_ac_1,1)
compute_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_RES_ac_dc_1,1)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_non_RES_ac_1,1)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_non_RES_ac_dc_1,1)

hourly_RES_ac_1_GWh = hourly_RES_ac_1/10^3 # GWh
hourly_RES_ac_dc_1_GWh = hourly_RES_ac_dc_1/10^3 #GWh

diff_1 = hourly_RES_ac_dc_1_GWh - hourly_RES_ac_1_GWh
sum(diff_1)
sum(hourly_RES_ac_1_GWh)
sum(hourly_RES_ac_dc_1_GWh)


#=
sum(hourly_RES_ac_1)/10^6
sum(hourly_RES_ac_dc_1)/10^6
sum(hourly_non_RES_ac_1)/10^6
sum(hourly_non_RES_ac_dc_1)/10^6
sum(load_time_series["Bus_1"])*100
sum(hourly_RES_ac_1) + sum(hourly_non_RES_ac_1)
sum(hourly_RES_ac_dc_1) + sum(hourly_non_RES_ac_dc_1)
sum(load_time_series["Bus_1"])*100
sum(hourly_RES_ac_1)/(sum(load_time_series["Bus_1"])*100)
sum(hourly_RES_ac_dc_1)/(sum(load_time_series["Bus_1"])*100)
=#

# Zone 2: Scandinavia
hourly_RES_ac_2 = []
hourly_RES_ac_dc_2 = []
hourly_non_RES_ac_2 = []
hourly_non_RES_ac_dc_2 = []
compute_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_RES_ac_2,2)
compute_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_RES_ac_dc_2,2)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_non_RES_ac_2,2)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_non_RES_ac_dc_2,2)


hourly_RES_ac_2_GWh = hourly_RES_ac_2/10^3 # GWh
hourly_RES_ac_dc_2_GWh = hourly_RES_ac_dc_2/10^3 #GWh

diff_2 = hourly_RES_ac_dc_2_GWh - hourly_RES_ac_2_GWh
sum(diff_2)
sum(hourly_RES_ac_1_GWh)
sum(hourly_RES_ac_dc_1_GWh)


#=
sum(hourly_RES_ac_2)/10^6
sum(hourly_RES_ac_dc_2)/10^6

sum(hourly_non_RES_ac_2)/10^6
sum(hourly_non_RES_ac_dc_2)/10^6

sum(load_time_series["Bus_2"])*100
sum(hourly_RES_ac_2) + sum(hourly_non_RES_ac_2)
sum(hourly_RES_ac_dc_2) + sum(hourly_non_RES_ac_dc_2)
sum(load_time_series["Bus_2"])*100
sum(hourly_RES_ac_2)/(sum(load_time_series["Bus_2"])*100)
sum(hourly_RES_ac_dc_2)/(sum(load_time_series["Bus_2"])*100)

sum(hourly_RES_ac_2)/(sum(hourly_RES_ac_2) + sum(hourly_non_RES_ac_2))
sum(hourly_RES_ac_dc_2)/(sum(hourly_RES_ac_dc_2) + sum(hourly_non_RES_ac_dc_2))
=#

# Zones 3-4-5-6: Rest of Europe
hourly_RES_ac_3 = []
hourly_RES_ac_dc_3 = []
hourly_non_RES_ac_3 = []
hourly_non_RES_ac_dc_3 = []
compute_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_RES_ac_3,3)
compute_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_RES_ac_dc_3,3)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_non_RES_ac_3,3)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_non_RES_ac_dc_3,3)

sum(hourly_RES_ac_3)
sum(hourly_RES_ac_dc_3)

sum(hourly_non_RES_ac_3)
sum(hourly_non_RES_ac_dc_3)

sum(load_time_series["Bus_3"])*100
sum(hourly_RES_ac_3) + sum(hourly_non_RES_ac_3)
sum(hourly_RES_ac_dc_3) + sum(hourly_non_RES_ac_dc_3)
sum(load_time_series["Bus_3"])*100
sum(hourly_RES_ac_3)/(sum(load_time_series["Bus_3"])*100)
sum(hourly_RES_ac_dc_3)/(sum(load_time_series["Bus_3"])*100)

#sum(hourly_RES_ac_3)/(sum(hourly_RES_ac_3) + sum(hourly_non_RES_ac_3))
#sum(hourly_RES_ac_dc_3)/(sum(hourly_RES_ac_dc_3) + sum(hourly_non_RES_ac_dc_3))



hourly_RES_ac_4 = []
hourly_RES_ac_dc_4 = []
hourly_non_RES_ac_4 = []
hourly_non_RES_ac_dc_4 = []
compute_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_RES_ac_4,4)
compute_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_RES_ac_dc_4,4)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_non_RES_ac_4,4)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_non_RES_ac_dc_4,4)

sum(hourly_RES_ac_4)
sum(hourly_RES_ac_dc_4)

sum(hourly_non_RES_ac_4)
sum(hourly_non_RES_ac_dc_4)

sum(load_time_series["Bus_4"])*100
sum(hourly_RES_ac_4) + sum(hourly_non_RES_ac_4)
sum(hourly_RES_ac_dc_4) + sum(hourly_non_RES_ac_dc_4)
sum(load_time_series["Bus_4"])*100
sum(hourly_RES_ac_4)/(sum(load_time_series["Bus_4"])*100)
sum(hourly_RES_ac_dc_4)/(sum(load_time_series["Bus_4"])*100)

#sum(hourly_RES_ac_4)/(sum(hourly_RES_ac_4) + sum(hourly_non_RES_ac_4))
#sum(hourly_RES_ac_dc_4)/(sum(hourly_RES_ac_dc_4) + sum(hourly_non_RES_ac_dc_4))



hourly_RES_ac_5 = []
hourly_RES_ac_dc_5 = []
hourly_non_RES_ac_5 = []
hourly_non_RES_ac_dc_5 = []
compute_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_RES_ac_5,5)
compute_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_RES_ac_dc_5,5)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_non_RES_ac_5,5)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_non_RES_ac_dc_5,5)

sum(hourly_RES_ac_5)
sum(hourly_RES_ac_dc_5)

sum(hourly_non_RES_ac_5)
sum(hourly_non_RES_ac_dc_5)

sum(load_time_series["Bus_5"])*100
sum(hourly_RES_ac_5) + sum(hourly_non_RES_ac_5)
sum(hourly_RES_ac_dc_5) + sum(hourly_non_RES_ac_dc_5)
sum(load_time_series["Bus_5"])*100
sum(hourly_RES_ac_5)/(sum(load_time_series["Bus_5"])*100)
sum(hourly_RES_ac_dc_5)/(sum(load_time_series["Bus_5"])*100)

sum(hourly_RES_ac_5)/(sum(hourly_RES_ac_5) + sum(hourly_non_RES_ac_5))
sum(hourly_RES_ac_dc_5)/(sum(hourly_RES_ac_dc_5) + sum(hourly_non_RES_ac_dc_5))



hourly_RES_ac_6 = []
hourly_RES_ac_dc_6 = []
hourly_non_RES_ac_6 = []
hourly_non_RES_ac_dc_6 = []
compute_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_RES_ac_6,6)
compute_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_RES_ac_dc_6,6)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_corrected,hourly_non_RES_ac_6,6)
compute_non_RES_generation_per_zone(test_case,8760,results_AC_DC,hourly_non_RES_ac_dc_6,6)

sum(hourly_RES_ac_6)
sum(hourly_RES_ac_dc_6)
sum(hourly_non_RES_ac_6)
sum(hourly_non_RES_ac_dc_6)

sum(load_time_series["Bus_6"])*100
sum(hourly_RES_ac_6) + sum(hourly_non_RES_ac_6)
sum(hourly_RES_ac_dc_6) + sum(hourly_non_RES_ac_dc_6)
sum(load_time_series["Bus_6"])*100
sum(hourly_RES_ac_6)/(sum(load_time_series["Bus_6"])*100)
sum(hourly_RES_ac_dc_6)/(sum(load_time_series["Bus_6"])*100)

sum(hourly_RES_ac_6)/(sum(hourly_RES_ac_6) + sum(hourly_non_RES_ac_6))
sum(hourly_RES_ac_dc_6)/(sum(hourly_RES_ac_dc_6) + sum(hourly_non_RES_ac_dc_6))


# Summing up 3,4,5,6
(sum(hourly_RES_ac_3) + sum(hourly_RES_ac_4) + sum(hourly_RES_ac_5) + sum(hourly_RES_ac_6))/10^3
(sum(hourly_RES_ac_dc_3) + sum(hourly_RES_ac_dc_4) + sum(hourly_RES_ac_dc_5) + sum(hourly_RES_ac_dc_6))/10^3


diff_3_4_5_6 = (hourly_RES_ac_dc_3 + hourly_RES_ac_dc_4 + hourly_RES_ac_dc_5 + hourly_RES_ac_dc_6)/10^3 - (hourly_RES_ac_3 + hourly_RES_ac_4 + hourly_RES_ac_5 + hourly_RES_ac_6)/10^3 

#=
p5 = Plots.plot(hours, diff_1, legend=:outertopright, label = "\$Diff~RES~Zone~1\$",xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$RES~Generation~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, diff_2, legend=:outertopright, label = "\$Diff~RES~Zone~2\$",xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$RES~Generation~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, diff_3_4_5_6, legend=:outertopright, label = "\$Diff~RES~Zones~3,4,5,6\$",seriesalpha = 0.2,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$RES~Generation~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
=#




(sum(hourly_RES_ac_3) + sum(hourly_RES_ac_4) + sum(hourly_RES_ac_5) + sum(hourly_RES_ac_6))/(sum(load_time_series["Bus_3"])*100 + sum(load_time_series["Bus_4"])*100 + sum(load_time_series["Bus_5"])*100 + sum(load_time_series["Bus_6"])*100)
(sum(hourly_RES_ac_dc_3) + sum(hourly_RES_ac_dc_4) + sum(hourly_RES_ac_dc_5) + sum(hourly_RES_ac_dc_6))/(sum(load_time_series["Bus_3"])*100 + sum(load_time_series["Bus_4"])*100 + sum(load_time_series["Bus_5"])*100 + sum(load_time_series["Bus_6"])*100)

(sum(hourly_RES_ac_3) + sum(hourly_RES_ac_4) + sum(hourly_RES_ac_5) + sum(hourly_RES_ac_6))/10^6
(sum(hourly_RES_ac_dc_3) + sum(hourly_RES_ac_dc_4) + sum(hourly_RES_ac_dc_5) + sum(hourly_RES_ac_dc_6))/10^6
(sum(hourly_non_RES_ac_3) + sum(hourly_non_RES_ac_4) + sum(hourly_non_RES_ac_5) + sum(hourly_non_RES_ac_6))/10^6
(sum(hourly_non_RES_ac_dc_3) + sum(hourly_non_RES_ac_dc_4) + sum(hourly_non_RES_ac_dc_5) + sum(hourly_non_RES_ac_dc_6))/10^6

## For each zone then
sum(hourly_RES_ac_1)/(sum(load_time_series["Bus_1"])*100)
sum(hourly_RES_ac_dc_1)/(sum(load_time_series["Bus_1"])*100)

sum(hourly_RES_ac_2)/(sum(load_time_series["Bus_2"])*100)
sum(hourly_RES_ac_dc_2)/(sum(load_time_series["Bus_2"])*100)

(sum(hourly_RES_ac_3) + sum(hourly_RES_ac_4) + sum(hourly_RES_ac_5) + sum(hourly_RES_ac_6))/(sum(load_time_series["Bus_3"])*100 + sum(load_time_series["Bus_4"])*100 + sum(load_time_series["Bus_5"])*100 + sum(load_time_series["Bus_6"])*100)
(sum(hourly_RES_ac_dc_3) + sum(hourly_RES_ac_dc_4) + sum(hourly_RES_ac_dc_5) + sum(hourly_RES_ac_dc_6))/(sum(load_time_series["Bus_3"])*100 + sum(load_time_series["Bus_4"])*100 + sum(load_time_series["Bus_5"])*100 + sum(load_time_series["Bus_6"])*100)

########################################################################
# Computing NOx emissions for each hour
########################################################################
hourly_NOx_ac = []
hourly_NOx_ac_dc = []

compute_NOx_emissions(test_case,8760,results_AC_corrected,hourly_NOx_ac)
compute_NOx_emissions(test_case,8760,results_AC_DC,hourly_NOx_ac_dc)

NOx_reduction = (sum(hourly_NOx_ac)-sum(hourly_NOx_ac_dc))/10^6 # Mton

print("The total NOx emissions for the selected year for the AC/DC grid are $(sum(hourly_NOx_ac_dc)/10^6) Mton","\n")
print("The total NOx emissions for the selected year for the AC grid are $(sum(hourly_NOx_ac)/10^6) Mton","\n")
print("The reduction of the NOx emissions for the selected year are $(NOx_reduction) Mton","\n")

########################################################################
# Computing SOx emissions for each hour
########################################################################
hourly_SOx_ac = []
hourly_SOx_ac_dc = []

compute_SOx_emissions(test_case,8760,results_AC_corrected,hourly_SOx_ac)
compute_SOx_emissions(test_case,8760,results_AC_DC,hourly_SOx_ac_dc)

SOx_reduction = (sum(hourly_SOx_ac)-sum(hourly_SOx_ac_dc)) # Mton

print("The total SOx emissions for the selected year for the AC/DC grid are $(sum(hourly_SOx_ac_dc)/10^6) Mton","\n")
print("The total SOx emissions for the selected year for the AC grid are $(sum(hourly_SOx_ac)/10^6) Mton","\n")
print("The reduction of the SOx emissions for the selected year are $(SOx_reduction/10^6) Mton","\n")

########################################################################
# Computing congestions for each hour
########################################################################
congested_lines_ac = []
congested_lines_ac_dc = []
branches_ac = Dict{String,Any}()
branches_ac_dc = Dict{String,Any}()

compute_congestions_no_abs(test_case,8760,results_AC_corrected,congested_lines_ac,branches_ac)
compute_congestions_no_abs(test_case,8760,results_AC_DC,congested_lines_ac_dc,branches_ac_dc)

compute_congestions_utilization_no_abs(test_case,8760,results_AC_corrected,congested_lines_ac,branches_ac)
compute_congestions_utilization_no_abs(test_case,8760,results_AC_DC,congested_lines_ac_dc,branches_ac_dc)

ac_line_1 = []
ac_line_2 = []
ac_line_3 = []
for i in 1:8760
    push!(ac_line_1,branches_ac["$i"][1][2])
    push!(ac_line_2,branches_ac["$i"][2][2])
    push!(ac_line_3,branches_ac["$i"][3][2])
end

ac_dc_line_1 = []
ac_dc_line_2 = []
ac_dc_line_3 = []
for i in 1:8760
    push!(ac_dc_line_1,branches_ac_dc["$i"][1][2])
    push!(ac_dc_line_2,branches_ac_dc["$i"][2][2])
    push!(ac_dc_line_3,branches_ac_dc["$i"][3][2])
end

hours = collect(1:8760)


p2 = Plots.scatter(hours, ac_line_1, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.scatter!(hours, ac_line_2, legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.scatter!(hours, ac_line_3, legend=:none, mc=:green, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))

maximum(hourly_RES_ac_GWh)

p3 = Plots.scatter(hourly_RES_ac_GWh, ac_line_1, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.scatter!(hourly_RES_ac_GWh, ac_line_2, legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.scatter!(hourly_RES_ac_GWh, ac_line_3, legend=:none, mc=:green, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))

p4 = Plots.scatter(hourly_RES_ac_GWh, ac_line_1, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.scatter!(hourly_RES_ac_GWh, ac_dc_line_1, legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-60,60],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))


p5 = Plots.plot(hours, hourly_RES_ac_GWh, legend=:none, mc=:blue,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[300,660],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, hourly_RES_ac_dc_GWh, legend=:none, mc=:red,seriesalpha = 0.5,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[300,660],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))



congested_line_ac = Dict{String,Any}()
congested_line_ac_dc = Dict{String,Any}()

for i in 1:8760
    congested_line_ac["$i"] = Dict{String,Any}()
    congested_line_ac_dc["$i"] = Dict{String,Any}()
    congested_line_ac["$i"]["line"] = deepcopy(congested_lines_ac[i][1][1])
    congested_line_ac_dc["$i"]["line"] = deepcopy(congested_lines_ac_dc[i][1][1])
    congested_line_ac["$i"]["congestion"] = deepcopy(congested_lines_ac[i][1][2])
    congested_line_ac_dc["$i"]["congestion"] = deepcopy(congested_lines_ac_dc[i][1][2])
end

lines = []
for i in 1:8760
    push!(lines,parse(Int64,congested_line_ac["$i"]["line"]))
end

line_7_ac = Dict{String,Any}()
line_7_ac_dc = Dict{String,Any}()

compute_congestions_line_AC(test_case,8760,results_AC_corrected,line_7_ac,7)
compute_congestions_line_AC(test_case,8760,results_AC_DC,line_7_ac_dc,7)

congestion_ac_7 = []
congestion_ac_dc_7 = []

for i in 1:8760
    push!(congestion_ac_7,line_7_ac["$i"])
    push!(congestion_ac_dc_7,line_7_ac_dc["$i"])
end

hourly_RES_ac_TWh = hourly_RES_ac/10^3 # TWh
hourly_RES_ac_dc_TWh =  hourly_RES_ac_dc/10^3 # TWh


# Line 7 is the most congested in this case
p1 = Plots.scatter(hourly_RES_ac_TWh, congestion_ac_7, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "RES generation [TWh]",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "Branch utilization",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p2 = Plots.scatter(hourly_RES_ac_dc_TWh, congestion_ac_dc_7, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "RES generation [TWh]",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = " Branch utilization",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

# Computing congested lines
congested_lines_hvdc = []
branches_hvdc = Dict{String,Any}()
compute_congestions_HVDC(test_case,8760,results_AC_DC,congested_lines_hvdc,branches_hvdc)

line_6_hvdc = Dict{String,Any}()
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_6_hvdc,6)

congestion_6_hvdc = []
for i in 1:8760
    push!(congestion_6_hvdc,line_6_hvdc["$i"])
end

p3 = Plots.scatter(hourly_RES_ac_dc_TWh, congestion_6_hvdc, label="data", legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "RES generation [TWh]",xguidefontsize=10,xtickfont = "Computer Modern",ytickfont = font(8,"Computer Modern"),ylabel = "Branch utilization",ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through DC branch 6 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

p4 = Plots.plot(p2,p3,layout = (2,1))

type = "AC_AC_DC"
number = "ac_7_(3)+DC_6"
plot_filename = "$(dirname(@__DIR__))/results/figures/$(type)_branch_$(number).svg"
Plots.savefig(p4, plot_filename)

# Computing energy through lines
for (g_id,g) in test_case["gen"]
    if length(g["cost"]) > 0
        print(g["type"],"  ",g_id,"  ",g["cost"][1],"\n")
    else
        print(g["type"],"  ",g_id,"  0.0","\n")
    end
end

tot_ac = compute_energy_through_a_line(8760,results_AC_corrected,6,0)

TWh_ac = tot_ac*100/10^(3) # GWh

tot_ac_ac_dc = compute_energy_through_a_line(8760,results_AC_DC,6,0)
tot_dc_ac_dc = compute_energy_through_a_dc_line(8760,results_AC_DC,6,0)

TWh_ac_ac_dc = tot_ac_ac_dc*100/10^(3) # GWh
TWh_dc_ac_dc = tot_dc_ac_dc*100/10^(3) # GWh

#=
# Checking the parameters values of the test case
test_case["branchdc"]["9"]["length"] = 500
test_case["branchdc"]["10"]["length"] = 1500
test_case["branchdc"]["11"]["length"] = 950
test_case["branchdc"]["12"]["length"] = 850

for i in 9:12#(length(test_case["branchdc"]))
    print(test_case["branchdc"]["$i"]["r"]*z_base/test_case["branchdc"]["$i"]["length"],"\n")
end

test_case["branchdc"]["1"]["length"] = 950
test_case["branchdc"]["2"]["length"] = 500
test_case["branchdc"]["3"]["length"] = 850
test_case["branchdc"]["4"]["length"] = 775
test_case["branchdc"]["5"]["length"] = 900
test_case["branchdc"]["6"]["length"] = 625
test_case["branchdc"]["7"]["length"] = 875
test_case["branchdc"]["8"]["length"] = 975
for i in 1:8#(length(test_case["branchdc"]))
    print(test_case["branchdc"]["$i"]["r"]*z_base/test_case["branchdc"]["$i"]["length"],"\n")
end
=#

# Doing the same analysis for the connections to zone 2
line_10_dc = Dict{String,Any}()
line_10_ac_dc = Dict{String,Any}()
line_12_dc = Dict{String,Any}()
line_12_ac_dc = Dict{String,Any}()
line_1_ac_dc = Dict{String,Any}()
line_2_ac_dc = Dict{String,Any}()
line_3_ac_dc = Dict{String,Any}()

compute_congestions_line_HVDC(test_case,8760,results_AC_corrected,line_10_dc,10)
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_10_ac_dc,10)
compute_congestions_line_HVDC(test_case,8760,results_AC_corrected,line_12_dc,10)
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_12_ac_dc,10)
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_3_ac_dc,1)
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_1_ac_dc,2)
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_2_ac_dc,3)

congestion_dc_10 = []
congestion_ac_dc_10 = []
congestion_dc_12 = []
congestion_ac_dc_12 = []
congestion_ac_dc_1 = []
congestion_ac_dc_2 = []
congestion_ac_dc_3 = []

for i in 1:8760
    push!(congestion_dc_10,line_10_dc["$i"])
    push!(congestion_ac_dc_10,line_10_ac_dc["$i"])
    push!(congestion_dc_12,line_12_dc["$i"])
    push!(congestion_ac_dc_12,line_12_ac_dc["$i"])
    if line_3_ac_dc["$i"] < 0.977 && line_3_ac_dc["$i"] > - 0.967 
        push!(congestion_ac_dc_3,line_3_ac_dc["$i"])
    elseif line_3_ac_dc["$i"] > 0.977
        push!(congestion_ac_dc_3,1.0)
    elseif line_3_ac_dc["$i"] < - 0.967
        push!(congestion_ac_dc_3,-1.0)
    end
    push!(congestion_ac_dc_1,line_1_ac_dc["$i"])
    push!(congestion_ac_dc_2,line_2_ac_dc["$i"])
end

count(<=(-0.90),congestion_ac_dc_3)

hourly_RES_dc_TWh = hourly_RES_ac/10^3 # TWh
hourly_RES_ac_dc_TWh =  hourly_RES_ac_dc/10^3 # TWh


hourly_RES_ac_zone_2_TWh = hourly_RES_ac_2/10^3 
hourly_RES_ac_dc_zone_2_TWh = hourly_RES_ac_dc_2/10^3 

hours = collect(1:8760)

# Line 6 is the most congested in this case
#p5 = Plots.scatter(hourly_RES_dc_TWh, congestion_dc_10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p5_10 = Plots.scatter(hours, congestion_dc_10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Timesteps\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p5_12 = Plots.scatter(hours, congestion_dc_10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Timesteps\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))

#p6 = Plots.scatter(hourly_RES_ac_dc_TWh, congestion_ac_dc_10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))
p6_10 = Plots.scatter(hours, congestion_ac_dc_10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Timesteps\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))
p6_12 = Plots.scatter(hours, congestion_ac_dc_10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Timesteps\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

p7_3 = Plots.scatter(hours, congestion_ac_dc_3, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))
p7_1 = Plots.scatter(hours, congestion_ac_dc_1, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))
p7_2 = Plots.scatter(hours, congestion_ac_dc_2, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[1,9000])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))


# Computing congested lines
congested_lines_hvdc = []
branches_hvdc = Dict{String,Any}()
compute_congestions_HVDC(test_case,8760,results_AC_DC,congested_lines_hvdc,branches_hvdc)

line_6_hvdc = Dict{String,Any}()
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_6_hvdc,6)

congestion_6_hvdc = []
for i in 1:8760
    push!(congestion_6_hvdc,line_6_hvdc["$i"])
end

p3 = Plots.scatter(hourly_RES_ac_dc_TWh, congestion_6_hvdc, label="data", legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps\$",xguidefontsize=10,xtickfont = "Computer Modern",ytickfont = font(8,"Computer Modern"),ylabel = "\$Branch~utilization\$",ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through DC branch 6 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

p4 = Plots.plot(p2,p3,layout = (2,1))

type = "AC_DC"
number = "3"
plot_filename = "$(dirname(@__DIR__))/results/figures/$(type)_branch_dc_$(number).pdf"
Plots.savefig(p7_3, plot_filename)



# Trying to plot hour 600 and its congestions
congestion_branches = Dict{String,Any}()
congestion_branches["branch"] = Dict{String,Any}()
congestion_branches["branchdc"] = Dict{String,Any}()
for (br_id,br) in test_case["branch"]
    congestion_branches["branch"][br_id] = Dict{String,Any}()
    congestion_branches["branch"][br_id]["rate_a"] = deepcopy(br["rate_a"])
end
for (br_id,br) in test_case["branchdc"]
    congestion_branches["branchdc"][br_id] = Dict{String,Any}()
    congestion_branches["branchdc"][br_id]["rate_a"] = deepcopy(br["rateA"])
end

for (br_id,br) in test_case["branch"]
    congestion_branches["branch"][br_id]["pt_ac"] = deepcopy(results_AC_corrected["600"]["solution"]["branch"][br_id]["pt"])
    congestion_branches["branch"][br_id]["pt_ac_dc"] = deepcopy(results_AC_DC["600"]["solution"]["branch"][br_id]["pt"])
    congestion_branches["branch"][br_id]["congestion_ac"] = deepcopy(congestion_branches["branch"][br_id]["pt_ac"]/congestion_branches["branch"][br_id]["rate_a"])
    congestion_branches["branch"][br_id]["congestion_ac_dc"] = deepcopy(congestion_branches["branch"][br_id]["pt_ac_dc"]/congestion_branches["branch"][br_id]["rate_a"])
end
for (br_id,br) in test_case["branchdc"]
    congestion_branches["branchdc"][br_id]["pt_ac_dc"] = deepcopy(results_AC_DC["600"]["solution"]["branchdc"][br_id]["pt"])
    congestion_branches["branchdc"][br_id]["congestion_ac_dc"] = deepcopy(congestion_branches["branchdc"][br_id]["pt_ac_dc"]/congestion_branches["branchdc"][br_id]["rate_a"])
end
for (br_id,br) in results_AC_corrected["600"]["solution"]["branchdc"]
    congestion_branches["branchdc"][br_id]["pt_ac"] = deepcopy(results_AC_corrected["600"]["solution"]["branchdc"][br_id]["pt"])
    congestion_branches["branchdc"][br_id]["congestion_ac"] = deepcopy(congestion_branches["branchdc"][br_id]["pt_ac"]/congestion_branches["branchdc"][br_id]["rate_a"])
end

for (br_id,br) in congestion_branches["branch"]
    print("AC BRANCH $(br_id)","\n")
    print("Congestion ac $(br["congestion_ac"])","\n")
    print("Congestion ac_dc $(br["congestion_ac_dc"])","\n")
end

for (br_id,br) in congestion_branches["branchdc"]
    if length(br) == 5
        print("DC PtP BRANCH $(br_id)","\n")
        print("Congestion ac $(br["congestion_ac"])","\n")
        print("Power ac $(br["pt_ac"])","\n")
        print("Congestion ac_dc $(br["congestion_ac_dc"])","\n")
        print("Power ac_dc $(br["pt_ac_dc"])","\n")
    end
end

for (br_id,br) in congestion_branches["branchdc"]
    if length(br) != 5
        print("DC BRANCH OVERLAY GRID $(br_id)","\n")
        #print("Congestion ac $(br["congestion_ac"])","\n")
        print("Congestion ac_dc $(br["congestion_ac_dc"])","\n")
        print("Power ac_dc $(br["pt_ac_dc"])","\n")
    end
end


congestion_branches = Dict{String,Any}()
congestion_branches["branch"] = Dict{String,Any}()
congestion_branches["branchdc"] = Dict{String,Any}()
for (br_id,br) in test_case["branch"]
    congestion_branches["branch"][br_id] = Dict{String,Any}()
    congestion_branches["branch"][br_id]["rate_a"] = deepcopy(br["rate_a"])
end
for (br_id,br) in test_case["branchdc"]
    congestion_branches["branchdc"][br_id] = Dict{String,Any}()
    congestion_branches["branchdc"][br_id]["rate_a"] = deepcopy(br["rateA"])
end

for (br_id,br) in test_case["branch"]
    congestion_branches["branch"][br_id]["pt_ac"] = deepcopy(results_AC_corrected["475"]["solution"]["branch"][br_id]["pt"])
    congestion_branches["branch"][br_id]["pt_ac_dc"] = deepcopy(results_AC_DC["475"]["solution"]["branch"][br_id]["pt"])
    congestion_branches["branch"][br_id]["congestion_ac"] = deepcopy(congestion_branches["branch"][br_id]["pt_ac"]/congestion_branches["branch"][br_id]["rate_a"])
    congestion_branches["branch"][br_id]["congestion_ac_dc"] = deepcopy(congestion_branches["branch"][br_id]["pt_ac_dc"]/congestion_branches["branch"][br_id]["rate_a"])
end
for (br_id,br) in test_case["branchdc"]
    congestion_branches["branchdc"][br_id]["pt_ac_dc"] = deepcopy(results_AC_DC["475"]["solution"]["branchdc"][br_id]["pt"])
    congestion_branches["branchdc"][br_id]["congestion_ac_dc"] = deepcopy(congestion_branches["branchdc"][br_id]["pt_ac_dc"]/congestion_branches["branchdc"][br_id]["rate_a"])
end
for (br_id,br) in results_AC_corrected["475"]["solution"]["branchdc"]
    congestion_branches["branchdc"][br_id]["pt_ac"] = deepcopy(results_AC_corrected["475"]["solution"]["branchdc"][br_id]["pt"])
    congestion_branches["branchdc"][br_id]["congestion_ac"] = deepcopy(congestion_branches["branchdc"][br_id]["pt_ac_dc"]/congestion_branches["branchdc"][br_id]["rate_a"])
end

