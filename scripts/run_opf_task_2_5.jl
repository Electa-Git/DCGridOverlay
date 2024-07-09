# Script to run the OPF simulations for the DC Grid overlay project using CbaOPF
# Script to create the DC grid overlay project's grid based on the develped function
# Refer to the excel file in the package
# 7th August 2023

using XLSX
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using JSON
using JuMP
using Ipopt 
using Gurobi
using DataFrames, CSV
include("create_grid_and_opf_functions.jl")

#########################################################################################################################
# One can choose the Pmax of the conv_power among 2.0, 4.0 and 8.0 GW
conv_power = 6.0
test_case_file = "DC_overlay_grid_$(conv_power)_GW_convdc.json"
test_case = _PM.parse_file("./test_cases/$test_case_file")


s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

try_ = _PMACDC.run_acdcopf(test_case,ACPPowerModel,ipopt; setting = s)


start_hour = 1
number_of_hours = 8760

RES_time_series_file = "DC_overlay_grid_RES_$(start_hour)_$(number_of_hours).json"
RES_time_series = JSON.parsefile("./test_cases/$RES_time_series_file")

load_time_series_file = "DC_overlay_grid_Demand_$(start_hour)_$(number_of_hours).json"
load_time_series = JSON.parsefile("./test_cases/$load_time_series_file")

##########################################################################
# Define solvers
##########################################################################
ipopt = JuMP.optimizer_with_attributes(Ipopt.Optimizer)
gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer)

##########################################################################
# Creating dictionaries for RES and load time series
##########################################################################
selected_timesteps_RES_time_series = Dict{String,Any}()
selected_timesteps_load_time_series = Dict{String,Any}()
result_timesteps = Dict{String,Any}()

#MAX LOAD/RES: 475
#max LOAD ratio: 1124
#max congestion: 1258
#Min RES: 6363

#timesteps = ["475","1124","1258","6363"]

timesteps = collect(1:8760)

for l in timesteps
    if typeof(l) == String
        selected_timesteps_RES_time_series["$l"] = Dict{String,Any}()
        for i in keys(RES_time_series)
            selected_timesteps_RES_time_series["$l"]["$i"] = Dict{String,Any}()
            selected_timesteps_RES_time_series["$l"]["$i"]["name"] = deepcopy(RES_time_series["$i"]["name"])
            selected_timesteps_RES_time_series["$l"]["$i"]["time_series"] = deepcopy(RES_time_series["$i"]["time_series"][parse(Int64,l)])
        end
    elseif typeof(l) == Int64
        selected_timesteps_RES_time_series["$l"] = Dict{String,Any}()
        for i in keys(RES_time_series)
            selected_timesteps_RES_time_series["$l"]["$i"] = Dict{String,Any}()
            selected_timesteps_RES_time_series["$l"]["$i"]["name"] = deepcopy(RES_time_series["$i"]["name"])
            selected_timesteps_RES_time_series["$l"]["$i"]["time_series"] = deepcopy(RES_time_series["$i"]["time_series"][l])
        end
    end
end

for l in timesteps
    if typeof(l) == String
        selected_timesteps_load_time_series["$l"] = Dict{String,Any}()
        for i in keys(load_time_series)
            selected_timesteps_load_time_series["$l"]["$i"] = Dict{String,Any}()
            selected_timesteps_load_time_series["$l"]["$i"]["time_series"] = deepcopy(load_time_series["$i"][parse(Int64,l)])
        end
    elseif typeof(l) == Int64
        selected_timesteps_load_time_series["$l"] = Dict{String,Any}()
        for i in keys(load_time_series)
            selected_timesteps_load_time_series["$l"]["$i"] = Dict{String,Any}()
            selected_timesteps_load_time_series["$l"]["$i"]["time_series"] = deepcopy(load_time_series["$i"][l])
        end
    end
end

# Losing DC branch 3
#test_case["branchdc"]["3"]["rateA"] = 0.0
#test_case["branchdc"]["4"]["rateA"] = 0.0


#####################################################################
#Losing the entire overlay DC grid (no point-to-point interconnections 24-30) -> cost comparison
#####################################################################
for (conv_id,conv) in test_case["convdc"]
    if conv_id != "24" || conv_id != "25" || conv_id != "26" || conv_id != "27" || conv_id != "28" || conv_id != "29" || conv_id != "30"
        conv["status"] = 0
    end
end

########################################################################
########################################################################
########################################################################

result_ac, demand_series = solve_opf_timestep(test_case,selected_timesteps_RES_time_series,selected_timesteps_load_time_series,timesteps,conv_power)


#result_dc, demand_series = solve_opf_timestep_dc(test_case,selected_timesteps_RES_time_series,selected_timesteps_load_time_series,timesteps,conv_power)

json_string = JSON.json(result_ac)
open("/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/results/result_one_year_AC_grid_corrected.json","w") do f
    JSON.write(f, json_string)
end

json_string_ii = JSON.json(demand_series)
open("./results/demand_one_year_AC_grid.json","w") do f
    JSON.write(f, json_string_ii)
end


#save("C:\\Users\\shardy\\Documents\\julia\\times_series_input_large_files\\supernode\\HVDC_HVAC_AC_powerflows_6GW.jld2",result_ac)

#result_ac=load("C:\\Users\\shardy\\Documents\\julia\\times_series_input_large_files\\supernode\\HVDC_HVAC_AC_powerflows_6GW.jld2")


############################################################################################################
# printing the csv files for strathclyde
############################################################################################################
result_folder = "MaxLoadRESratio"

results_dict = result_dc



#ac
for b in sort(parse.(Int64,keys(last(first(results_dict))["solution"]["branch"])))
    pf=[results_dict[string(ts)]["solution"]["branch"][string(b)]["pf"] for ts in TS]
    pt=[results_dict[string(ts)]["solution"]["branch"][string(b)]["pt"] for ts in TS]
    qf=[results_dict[string(ts)]["solution"]["branch"][string(b)]["qf"] for ts in TS]
    qt=[results_dict[string(ts)]["solution"]["branch"][string(b)]["qt"] for ts in TS]
    cables_df[!,Symbol("pf_ac_"*string(b-4))]=deepcopy(pf)
    cables_df[!,Symbol("pt_ac_"*string(b-4))]=deepcopy(pt)
    cables_df[!,Symbol("qf_ac_"*string(b-4))]=deepcopy(qf)
    cables_df[!,Symbol("qt_ac_"*string(b-4))]=deepcopy(qt)
end

#dc
for b in sort(parse.(Int64,keys(last(first(results_dict))["solution"]["branchdc"])))
    pf=[results_dict[string(ts)]["solution"]["branchdc"][string(b)]["pf"] for ts in TS]
    pt=[results_dict[string(ts)]["solution"]["branchdc"][string(b)]["pt"] for ts in TS]
    cables_df[!,Symbol("pf_dc_"*string(b))]=deepcopy(pf)
    cables_df[!,Symbol("pt_dc_"*string(b))]=deepcopy(pt)
end

CSV.write("results//$(result_folder)//scenarios_tls.csv", cables_df)

#voltage angles per scenario
for b in sort(parse.(Int64,keys(last(first(results_dict))["solution"]["bus"])))
    vm=[results_dict[string(ts)]["solution"]["bus"][string(b)]["vm"] for ts in TS]
    va=[results_dict[string(ts)]["solution"]["bus"][string(b)]["va"] for ts in TS]
    cables_df[!,Symbol("vm_bus_"*string(b))]=deepcopy(vm)
    cables_df[!,Symbol("va_bus_"*string(b))]=deepcopy(va)
end

CSV.write("results//$(result_folder)//scenarios_angles.csv", cables_df)
