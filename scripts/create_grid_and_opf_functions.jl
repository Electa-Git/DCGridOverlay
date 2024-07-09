# Script to create the DC grid overlay project's grid
# Refer to the excel file in the package
# 7th August 2023
using XLSX
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using JSON
using JuMP
#using CbaOPF


function create_grid(start_hour,number_of_hours,conv_power;output_filename::String = "./test_cases/DC_overlay_grid")
    # Uploading an example test system
    test_case_5_acdc = "case5_acdc.m"
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
    data_file_5_acdc = "./test_cases/$test_case_5_acdc"
    test_grid = _PM.parse_file(joinpath("./$(data_file_5_acdc)"))
    _PMACDC.process_additional_data!(test_grid)
   
    test_file = "./test_cases/DC_overlay_grid.xlsx"
    #test_grid = _PM.parse_file(test_file)

    # Calling the Excel file
    xf = XLSX.readxlsx(joinpath("./$(test_file)"))
    XLSX.sheetnames(xf)
    number_of_buses = 6

    # Creating a European grid dictionary in PowerModels format
    DC_overlay_grid = Dict{String,Any}()
    DC_overlay_grid["dcpol"] = 2
    DC_overlay_grid["name"] = "DC_overlay_grid"
    DC_overlay_grid["baseMVA"] = 100
    DC_overlay_grid["base_kv_AC"] = 380
    DC_overlay_grid["base_kv_DC"] = 525
    DC_overlay_grid["per_unit"] = true #adapt values from Excel file
    DC_overlay_grid["Z_base"] = (DC_overlay_grid["base_kv_AC"])^2/(DC_overlay_grid["baseMVA"])
    z_base_dc=(DC_overlay_grid["base_kv_DC"])^2/(DC_overlay_grid["baseMVA"])

    # Buses
    DC_overlay_grid["bus"] = Dict{String,Any}()
    for idx in 1:number_of_buses
        DC_overlay_grid["bus"]["$idx"] = Dict{String,Any}()
        DC_overlay_grid["bus"]["$idx"]["name"] = "Bus_$(idx)"
        DC_overlay_grid["bus"]["$idx"]["index"] = idx 
        DC_overlay_grid["bus"]["$idx"]["bus_i"] = idx 
        if idx == 3
            DC_overlay_grid["bus"]["$idx"]["bus_type"] = 3 #slack bus
        else
            DC_overlay_grid["bus"]["$idx"]["bus_type"] = 1 
        end
        DC_overlay_grid["bus"]["$idx"]["pd"] = 0.0 
        DC_overlay_grid["bus"]["$idx"]["qd"] = 0.0 
        DC_overlay_grid["bus"]["$idx"]["gs"] = 0.0 
        DC_overlay_grid["bus"]["$idx"]["bs"] = 0.0 
        DC_overlay_grid["bus"]["$idx"]["area"] = 1 
        DC_overlay_grid["bus"]["$idx"]["vm"] = 1.0
        DC_overlay_grid["bus"]["$idx"]["va"] = 1.0
        DC_overlay_grid["bus"]["$idx"]["base_kv"] = 380 #kV
        DC_overlay_grid["bus"]["$idx"]["vmax"] = 1.1
        DC_overlay_grid["bus"]["$idx"]["vmin"] = 0.9
        DC_overlay_grid["bus"]["$idx"]["source_id"] = []
        push!(DC_overlay_grid["bus"]["$idx"]["source_id"],"bus")
        push!(DC_overlay_grid["bus"]["$idx"]["source_id"],idx)
    end

    # Bus dc -> it can be commented out if you want to keep only the AC system
    DC_overlay_grid["busdc"] = Dict{String,Any}()
    for idx in 1:number_of_buses
        DC_overlay_grid["busdc"]["$idx"] = Dict{String,Any}()
        DC_overlay_grid["busdc"]["$idx"]["name"] = "Bus_dc_$(idx)"
        DC_overlay_grid["busdc"]["$idx"]["index"] = idx
        DC_overlay_grid["busdc"]["$idx"]["busdc_i"] = idx
        DC_overlay_grid["busdc"]["$idx"]["bus_type"] = 1
        DC_overlay_grid["busdc"]["$idx"]["pd"] = 0.0
        DC_overlay_grid["busdc"]["$idx"]["qd"] = 0.0
        DC_overlay_grid["busdc"]["$idx"]["gs"] = 0.0
        DC_overlay_grid["busdc"]["$idx"]["bs"] = 0.0
        DC_overlay_grid["busdc"]["$idx"]["area"] = 2
        DC_overlay_grid["busdc"]["$idx"]["vm"] = 1.0
        DC_overlay_grid["busdc"]["$idx"]["Vdcmax"] = 1.1
        DC_overlay_grid["busdc"]["$idx"]["Vdcmin"] = 0.9
        DC_overlay_grid["busdc"]["$idx"]["Vdc"] = 1
        DC_overlay_grid["busdc"]["$idx"]["Pdc"] = 0
        DC_overlay_grid["busdc"]["$idx"]["Cdc"] = 0
        DC_overlay_grid["busdc"]["$idx"]["source_id"] = []
        push!(DC_overlay_grid["busdc"]["$idx"]["source_id"],"busdc")
        push!(DC_overlay_grid["busdc"]["$idx"]["source_id"],idx)
    end

    # Bus dc for point-to-point links
    n_busdc = length(DC_overlay_grid["busdc"])
    for i in 1:8
        DC_overlay_grid["busdc"]["$(n_busdc+i)"] = deepcopy(DC_overlay_grid["busdc"]["1"])
        DC_overlay_grid["busdc"]["$(n_busdc+i)"]["name"] = "Bus_dc_$(n_busdc+i)"
        DC_overlay_grid["busdc"]["$(n_busdc+i)"]["index"] = n_busdc+i
        DC_overlay_grid["busdc"]["$(n_busdc+i)"]["busdc_i"] = n_busdc+i
        DC_overlay_grid["busdc"]["$(n_busdc+i)"]["source_id"][2] = n_busdc+i
    end
    
    # Branches
    DC_overlay_grid["branch"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["AC_grid_build"])
        i = XLSX.row_number(r)
        if i > 5 && i <= 8 
            # compensate for header and limit the number of rows to the existing branches
            idx = i - 1
            DC_overlay_grid["branch"]["$idx"] = Dict{String,Any}()
            DC_overlay_grid["branch"]["$idx"]["type"] = "AC_line"
            DC_overlay_grid["branch"]["$idx"]["index"] = idx
            DC_overlay_grid["branch"]["$idx"]["f_bus"] = parse(Int64,r[1][3])
            DC_overlay_grid["branch"]["$idx"]["t_bus"] = parse(Int64,r[1][4])
            DC_overlay_grid["branch"]["$idx"]["br_r"] = r[7]/DC_overlay_grid["Z_base"]   
            DC_overlay_grid["branch"]["$idx"]["br_x"] = r[8]/DC_overlay_grid["Z_base"]   
            DC_overlay_grid["branch"]["$idx"]["b_fr"] = ((r[9])*DC_overlay_grid["Z_base"])/2 #1/sqrt((DC_overlay_grid["branch"]["$idx"]["br_r"])^2+(DC_overlay_grid["branch"]["$idx"]["br_x"])^2) 
            DC_overlay_grid["branch"]["$idx"]["b_to"] = DC_overlay_grid["branch"]["$idx"]["b_fr"] #1/sqrt((DC_overlay_grid["branch"]["$idx"]["br_r"])^2+(DC_overlay_grid["branch"]["$idx"]["br_x"])^2)
            DC_overlay_grid["branch"]["$idx"]["g_fr"] = 0.0
            DC_overlay_grid["branch"]["$idx"]["g_to"] = 0.0
            DC_overlay_grid["branch"]["$idx"]["rate_a"] = r[2]/DC_overlay_grid["baseMVA"]
            DC_overlay_grid["branch"]["$idx"]["rate_b"] = r[2]/DC_overlay_grid["baseMVA"] 
            DC_overlay_grid["branch"]["$idx"]["rate_c"] = r[2]/DC_overlay_grid["baseMVA"]
            DC_overlay_grid["branch"]["$idx"]["ratio"] = 1 
            DC_overlay_grid["branch"]["$idx"]["angmin"] = -pi
            DC_overlay_grid["branch"]["$idx"]["angmax"] = pi 
            DC_overlay_grid["branch"]["$idx"]["br_status"] = 1
            DC_overlay_grid["branch"]["$idx"]["tap"] = 1.0
            DC_overlay_grid["branch"]["$idx"]["transformer"] = false
            DC_overlay_grid["branch"]["$idx"]["shift"] = 0.0
            DC_overlay_grid["branch"]["$idx"]["source_id"] = []
            push!(DC_overlay_grid["branch"]["$idx"]["source_id"],"branch")
            push!(DC_overlay_grid["branch"]["$idx"]["source_id"], idx)
        end
    end
    # DC Branches
    DC_overlay_grid["branchdc"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["DC_grid_build"])
        i = XLSX.row_number(r)
        if i > 1 && i <= 9 # compensate for header and limit the number of rows to the existing branches
            idx = i - 1
            DC_overlay_grid["branchdc"]["$idx"] = Dict{String,Any}()
            DC_overlay_grid["branchdc"]["$idx"]["type"] = "DC_grid" #branches_dc_dict[:,2][i]
            DC_overlay_grid["branchdc"]["$idx"]["index"] = idx
            DC_overlay_grid["branchdc"]["$idx"]["fbusdc"] = parse(Int64,r[1][3])
            DC_overlay_grid["branchdc"]["$idx"]["tbusdc"] = parse(Int64,r[1][4])
            DC_overlay_grid["branchdc"]["$idx"]["r"] = r[6]/z_base_dc
            DC_overlay_grid["branchdc"]["$idx"]["c"] = 0.0
            DC_overlay_grid["branchdc"]["$idx"]["l"] = 0.0
            DC_overlay_grid["branchdc"]["$idx"]["status"] = 1
            DC_overlay_grid["branchdc"]["$idx"]["rateA"] = r[2]/DC_overlay_grid["baseMVA"] # Total [MVA] (+/-)
            DC_overlay_grid["branchdc"]["$idx"]["rateB"] = r[2]/DC_overlay_grid["baseMVA"] # Total [MVA] (+/-)
            DC_overlay_grid["branchdc"]["$idx"]["rateC"] = r[2]/DC_overlay_grid["baseMVA"] # Total [MVA] (+/-)
            DC_overlay_grid["branchdc"]["$idx"]["ratio"] = 1
            DC_overlay_grid["branchdc"]["$idx"]["source_id"] = []
            push!(DC_overlay_grid["branchdc"]["$idx"]["source_id"],"branchdc")
            push!(DC_overlay_grid["branchdc"]["$idx"]["source_id"], idx)
        end
    end
    # Point-to-point links
    n_branches = length(DC_overlay_grid["branchdc"])
    println("n_branches ", n_branches)
    #DC_overlay_grid["branch"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["AC_grid_build"])
        i = XLSX.row_number(r)-1
        if i >= 1 && i < 5
    #for i in 1:4
            DC_overlay_grid["branchdc"]["$(n_branches+i)"] = deepcopy(DC_overlay_grid["branchdc"]["1"])
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["type"] = "PtP_link" 
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["index"] = n_branches+i
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["source_id"][2] = n_branches+i
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["r"] = (r[7])/z_base_dc
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["c"] = 0.0
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["l"] = 0.0
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["status"] = 1
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["rateA"] = r[13]/DC_overlay_grid["baseMVA"] # Total [MVA] (+/-)
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["rateB"] = r[13]/DC_overlay_grid["baseMVA"] # Total [MVA] (+/-)
            DC_overlay_grid["branchdc"]["$(n_branches+i)"]["rateC"] = r[13]/DC_overlay_grid["baseMVA"] # Total [MVA] (+/-)
        end
    end
    DC_overlay_grid["branchdc"]["9"]["fbusdc"]  = 7
    DC_overlay_grid["branchdc"]["9"]["tbusdc"]  = 8 
    DC_overlay_grid["branchdc"]["10"]["fbusdc"] = 11
    DC_overlay_grid["branchdc"]["10"]["tbusdc"] = 12
    DC_overlay_grid["branchdc"]["11"]["fbusdc"] = 9
    DC_overlay_grid["branchdc"]["11"]["tbusdc"] = 10
    DC_overlay_grid["branchdc"]["12"]["fbusdc"] = 13
    DC_overlay_grid["branchdc"]["12"]["tbusdc"] = 14

    
    # DC Converters
    DC_overlay_grid["convdc"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["Conv_dc"])
        i = XLSX.row_number(r)
        if i > 1 && i <= 7 # compensate for header and limit the number of rows to the existing branches
            idx = i - 1    
            DC_overlay_grid["convdc"]["$idx"] = Dict{String,Any}()
            DC_overlay_grid["convdc"]["$idx"] = deepcopy(test_grid["convdc"]["1"])  # To fill in default values......
            DC_overlay_grid["convdc"]["$idx"]["busdc_i"] = idx 
            DC_overlay_grid["convdc"]["$idx"]["busac_i"] = idx 
            DC_overlay_grid["convdc"]["$idx"]["index"] = idx
            DC_overlay_grid["convdc"]["$idx"]["status"] = 1
            sum = 0.0
            for (brdc_id,brdc) in DC_overlay_grid["branchdc"]
                if brdc["fbusdc"] == idx || brdc["tbusdc"] == idx 
                    sum = sum + brdc["rateA"]
                end
            end 
            DC_overlay_grid["convdc"]["$idx"]["Pacmax"] = deepcopy(sum) # Values to not having this power constraining the OPF -> sum of the capacities coming in and going out
            DC_overlay_grid["convdc"]["$idx"]["Pacmin"] = - deepcopy(sum)
            DC_overlay_grid["convdc"]["$idx"]["Qacmin"] = 0.0#- deepcopy(sum)
            DC_overlay_grid["convdc"]["$idx"]["Qacmax"] = 0.0#deepcopy(sum)
            DC_overlay_grid["convdc"]["$idx"]["Pacrated"] = deepcopy(sum)
            DC_overlay_grid["convdc"]["$idx"]["Qacrated"] = 0.0#deepcopy(sum)
            DC_overlay_grid["convdc"]["$idx"]["Imax"] = DC_overlay_grid["convdc"]["$idx"]["Imax"]*100
            DC_overlay_grid["convdc"]["$idx"]["Pg"] = 0.0 #Adjusting with pu values
            DC_overlay_grid["convdc"]["$idx"]["ratio"] = 0
            DC_overlay_grid["convdc"]["$idx"]["transformer"] = 0
            DC_overlay_grid["convdc"]["$idx"]["reactor"] = 0
            DC_overlay_grid["convdc"]["$idx"]["filter"] = 0
            DC_overlay_grid["convdc"]["$idx"]["source_id"] = []
            push!(DC_overlay_grid["convdc"]["$idx"]["source_id"],"convdc")
            push!(DC_overlay_grid["convdc"]["$idx"]["source_id"], idx)

        end
    end
    
    # Count the number of converters needed to have the Pmax equal to conv_power and transmit the same amount of power
    n_conv = Dict{String,Any}() # -> dict with the number of converters with the same power
    for i in eachindex(DC_overlay_grid["convdc"])
        n_conv[i] = ceil(Int,DC_overlay_grid["convdc"][i]["Pacmax"]/(conv_power*10))
    end

    original_conv = deepcopy(DC_overlay_grid["convdc"]) # -> easier to work with a deepcopy
    
    # Creating a set of converters for each bus in which the only indeces differing among the converters are index and source_id
    for i in eachindex(original_conv)
        l = length(DC_overlay_grid["convdc"])
        new_convs = collect(1:n_conv["$i"])  
        for n in new_convs
            if n != 1
                new_conv = l + n
                DC_overlay_grid["convdc"]["$new_conv"] = deepcopy(DC_overlay_grid["convdc"]["$i"])
                DC_overlay_grid["convdc"]["$new_conv"]["index"] = new_conv
                DC_overlay_grid["convdc"]["$new_conv"]["source_id"] = []
                push!(DC_overlay_grid["convdc"]["$new_conv"]["source_id"],"convdc")
                push!(DC_overlay_grid["convdc"]["$new_conv"]["source_id"], new_conv)
            end
        end
    end

    # Imposing the power to each converter
    for (conv_id,conv) in DC_overlay_grid["convdc"]
        conv["Pacmax"] = conv_power*10 #conv["Pacmax"]/n_conv[i] # Values to not having this power constraining the OPF -> sum of the capacities coming in and going out
        conv["Pacmin"] = - conv_power*10 #conv["Pacmin"]/n_conv[i]
        conv["Qacmin"] = 0.0#- conv_power*10 #conv["Qacmin"]/n_conv[i]
        conv["Qacmax"] = 0.0#conv_power*10 #conv["Qacmax"]/n_conv[i]
        conv["Pacrated"] = conv_power*10 #conv["Qacmax"]/n_conv[i]
        conv["Qacrated"] = 0.0#conv_power*10 #conv["Qacmax"]/n_conv[i]
        conv["Imax"] = conv["Imax"]*100

        # Computed with Hakan's excel
        conv["rtf"] = (((DC_overlay_grid["base_kv_AC"]*10^3)^2 / (conv["Pacmax"]*10^8) * (15 / 100)) * cos( atan(35)))/DC_overlay_grid["Z_base"]
        #DC_overlay_grid["convdc"]["$idx"]["rtf"] = r[2] 
        conv["xtf"] = (((DC_overlay_grid["base_kv_AC"]*10^3)^2 / (conv["Pacmax"]*10^8) * (15 / 100)) * sin( atan(35)))/DC_overlay_grid["Z_base"]
        #DC_overlay_grid["convdc"]["$idx"]["xtf"] = r[3] 
        conv["bf"] = 0.00003 * 2 * 3.1415 * 50 * DC_overlay_grid["Z_base"]
        #DC_overlay_grid["convdc"]["$idx"]["bf"] = r[4] 
        conv["rc"] = (((DC_overlay_grid["base_kv_AC"]*10^3)^2 / (conv["Pacmax"]*10^8) * (7.5 / 100)) * cos( atan(30)))/DC_overlay_grid["Z_base"]
        #DC_overlay_grid["convdc"]["$idx"]["rc"] = r[5]
        conv["xc"] = ((((DC_overlay_grid["base_kv_AC"]*10^3)^2 / (conv["Pacmax"]*10^8)) * (7.5 / 100)) * sin( atan(30)))/DC_overlay_grid["Z_base"]
        #DC_overlay_grid["convdc"]["$idx"]["xc"] = r[6]
        conv["lossA"] = (1.1033 * conv["Pacmax"]/10)
        #DC_overlay_grid["convdc"]["$idx"]["lossA"] = r[7]/DC_overlay_grid["baseMVA"] 
        conv["lossB"] = 0.0035 * (DC_overlay_grid["base_kv_AC"] * sqrt(3))
        #DC_overlay_grid["convdc"]["$idx"]["lossB"] = r[8]
        conv["lossCrec"] = (0.0035 / (conv["Pacmax"]*10^2)) * DC_overlay_grid["Z_base"]
        #DC_overlay_grid["convdc"]["$idx"]["lossCrec"] = r[9] 
        #conv["LossCrec"] = (0.0035 / (conv["Pacmax"]*10^2)) * DC_overlay_grid["Z_base"]
    end

    # Converters for the Point-to-point links
    n_convs = length(DC_overlay_grid["convdc"])
    println("n_convs ", n_convs)
    for i in 1:8
        DC_overlay_grid["convdc"]["$(n_convs+i)"] = deepcopy(DC_overlay_grid["convdc"]["1"])
        DC_overlay_grid["convdc"]["$(n_convs+i)"]["type"] = "PtP_link" 
        DC_overlay_grid["convdc"]["$(n_convs+i)"]["index"] = n_convs+i
        DC_overlay_grid["convdc"]["$(n_convs+i)"]["source_id"][2] = n_convs+i
    end
    DC_overlay_grid["convdc"]["$(n_convs+1)"]["busdc_i"] = 7 
    DC_overlay_grid["convdc"]["$(n_convs+1)"]["busac_i"] = 1 
    DC_overlay_grid["convdc"]["$(n_convs+2)"]["busdc_i"] = 9 
    DC_overlay_grid["convdc"]["$(n_convs+2)"]["busac_i"] = 1 
    DC_overlay_grid["convdc"]["$(n_convs+3)"]["busdc_i"] = 11 
    DC_overlay_grid["convdc"]["$(n_convs+3)"]["busac_i"] = 1 
    DC_overlay_grid["convdc"]["$(n_convs+4)"]["busdc_i"] = 12 
    DC_overlay_grid["convdc"]["$(n_convs+4)"]["busac_i"] = 2 
    DC_overlay_grid["convdc"]["$(n_convs+5)"]["busdc_i"] = 13 
    DC_overlay_grid["convdc"]["$(n_convs+5)"]["busac_i"] = 2 
    DC_overlay_grid["convdc"]["$(n_convs+6)"]["busdc_i"] = 10 
    DC_overlay_grid["convdc"]["$(n_convs+6)"]["busac_i"] = 3 
    DC_overlay_grid["convdc"]["$(n_convs+7)"]["busdc_i"] = 14 
    DC_overlay_grid["convdc"]["$(n_convs+7)"]["busac_i"] = 3 
    DC_overlay_grid["convdc"]["$(n_convs+8)"]["busdc_i"] = 8 
    DC_overlay_grid["convdc"]["$(n_convs+8)"]["busac_i"] = 4 
    

    # Load
    loads = ["I","J","K","L","M","N"]
    DC_overlay_grid["load"] = Dict{String,Any}()
    for idx in 1:length(loads)
        DC_overlay_grid["load"]["$idx"] = Dict{String,Any}()
        DC_overlay_grid["load"]["$idx"]["load_bus"] = idx #load_dict[:,3][i]
        DC_overlay_grid["load"]["$idx"]["pmax"] = xf["Demand"]["$(loads[idx])2"]/DC_overlay_grid["baseMVA"]
        DC_overlay_grid["load"]["$idx"]["pavg"] = xf["Demand"]["$(loads[idx])5"]/DC_overlay_grid["baseMVA"]
        DC_overlay_grid["load"]["$idx"]["cosphi"] = 0.9
        DC_overlay_grid["load"]["$idx"]["pd"] = DC_overlay_grid["load"]["$idx"]["pmax"]/2 # load_dict[:,4][i]/DC_overlay_grid["baseMVA"] 
        DC_overlay_grid["load"]["$idx"]["qd"] = (DC_overlay_grid["load"]["$idx"]["pmax"]/2)*sqrt(1 - DC_overlay_grid["load"]["$idx"]["cosphi"]^2)
        DC_overlay_grid["load"]["$idx"]["index"] = idx
        DC_overlay_grid["load"]["$idx"]["status"] = 1
        DC_overlay_grid["load"]["$idx"]["source_id"] = []
        push!(DC_overlay_grid["load"]["$idx"]["source_id"],"bus")
        push!(DC_overlay_grid["load"]["$idx"]["source_id"], idx)
    end
    
    # Sort time series
    demands = ["A","B","C","D","E","F"]
    total_demand = ["G"]
    demand_time_series = Dict{String,Any}()
    total_demand_time_series = Dict{String,Any}()
    for idx in 1:length(demands)
        demand_time_series["Bus_$idx"] = []
        for h in (start_hour+1):(number_of_hours+1)
            push!(demand_time_series["Bus_$idx"],xf["Demand"]["$(demands[idx])$(h)"]/DC_overlay_grid["baseMVA"])
        end
    end
    for idx in 1:length(total_demand)
        total_demand_time_series["Total_demand"] = []
        for h in 2:number_of_hours
            push!(total_demand_time_series["Total_demand"],xf["Demand"]["$(total_demand[idx])$(h)"]/DC_overlay_grid["baseMVA"])
        end
    end

    ####### READ IN GENERATION DATA #######################
    solar_pv = ["B","E","H","K","N","Q"]
    onshore_wind = ["C","F","I","L","O","R"]
    offshore_wind = ["D","G","J","M","P","S"]
    flexible_gens = ["T","U","V","W","X","Y"]
    DC_overlay_grid["gen"] = Dict{String,Any}()
    count_ = 0

    ##### Solar PV  #####
    for idx in 1:length(solar_pv) 
        count_ += 1
        DC_overlay_grid["gen"]["$idx"] = Dict{String,Any}()
        DC_overlay_grid["gen"]["$idx"]["index"] =   deepcopy(idx)
        DC_overlay_grid["gen"]["$idx"]["gen_bus"] = deepcopy(idx) 
        DC_overlay_grid["gen"]["$idx"]["pmax"] = xf["RES_MVA"]["$(solar_pv[idx])2"]/DC_overlay_grid["baseMVA"]
        DC_overlay_grid["gen"]["$idx"]["pmin"] = 0.0 
        DC_overlay_grid["gen"]["$idx"]["qmax"] =  DC_overlay_grid["gen"]["$idx"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$idx"]["qmin"] = -DC_overlay_grid["gen"]["$idx"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$idx"]["cost"] = [0.0, 0.0]
        DC_overlay_grid["gen"]["$idx"]["marginal_cost"] = 0.0
        DC_overlay_grid["gen"]["$idx"]["co2_add_on"] = 0.0
        DC_overlay_grid["gen"]["$idx"]["ncost"] = 2
        DC_overlay_grid["gen"]["$idx"]["model"] = 2
        DC_overlay_grid["gen"]["$idx"]["type"] = "Solar PV"
        DC_overlay_grid["gen"]["$idx"]["gen_status"] = 1
        DC_overlay_grid["gen"]["$idx"]["vg"] = 1.0
        DC_overlay_grid["gen"]["$idx"]["source_id"] = []
        DC_overlay_grid["gen"]["$idx"]["name"] = "Solar_PV_$(idx)"  # Assumption here, to be checked
        push!(DC_overlay_grid["gen"]["$idx"]["source_id"],"gen")
        push!(DC_overlay_grid["gen"]["$idx"]["source_id"], idx)
    end
    ##### Onshore Wind  #####
    for idx in 1:length(onshore_wind) 
        count_ += 1
        DC_overlay_grid["gen"]["$count_"] = Dict{String,Any}()
        DC_overlay_grid["gen"]["$count_"]["index"]  = deepcopy(count_)
        DC_overlay_grid["gen"]["$count_"]["gen_bus"] = deepcopy(idx) 
        DC_overlay_grid["gen"]["$count_"]["pmax"] = xf["RES_MVA"]["$(onshore_wind[idx])2"]/DC_overlay_grid["baseMVA"]
        DC_overlay_grid["gen"]["$count_"]["pmin"] = 0.0 
        DC_overlay_grid["gen"]["$count_"]["qmax"] =  DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$count_"]["qmin"] = -DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$count_"]["cost"] = [25.0, 0.0]
        DC_overlay_grid["gen"]["$count_"]["marginal_cost"] = 0.0
        DC_overlay_grid["gen"]["$count_"]["co2_add_on"] = 0.0
        DC_overlay_grid["gen"]["$count_"]["ncost"] = 2
        DC_overlay_grid["gen"]["$count_"]["model"] = 2
        DC_overlay_grid["gen"]["$count_"]["type"] = "Onshore Wind"
        DC_overlay_grid["gen"]["$count_"]["gen_status"] = 1
        DC_overlay_grid["gen"]["$count_"]["vg"] = 1.0
        DC_overlay_grid["gen"]["$count_"]["source_id"] = []
        DC_overlay_grid["gen"]["$count_"]["name"] = "Onshore_Wind_$(idx)"  # Assumption here, to be checked
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"],"gen")
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"], count_)
    end
    ##### Offshore Wind  #####
    for idx in 1:length(offshore_wind) 
        count_ += 1
        DC_overlay_grid["gen"]["$count_"] = Dict{String,Any}()
        DC_overlay_grid["gen"]["$count_"]["index"] = deepcopy(count_)
        DC_overlay_grid["gen"]["$count_"]["gen_bus"] = deepcopy(idx) 
        DC_overlay_grid["gen"]["$count_"]["pmax"] = xf["RES_MVA"]["$(offshore_wind[idx])2"]/DC_overlay_grid["baseMVA"]
        DC_overlay_grid["gen"]["$count_"]["pmin"] = 0.0 
        DC_overlay_grid["gen"]["$count_"]["qmax"] =  DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$count_"]["qmin"] = -DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$count_"]["cost"] = [50.0, 0.0]
        DC_overlay_grid["gen"]["$count_"]["marginal_cost"] = 0.0
        DC_overlay_grid["gen"]["$count_"]["co2_add_on"] = 0.0
        DC_overlay_grid["gen"]["$count_"]["ncost"] = 2
        DC_overlay_grid["gen"]["$count_"]["model"] = 2
        DC_overlay_grid["gen"]["$count_"]["type"] = "Offshore Wind"
        DC_overlay_grid["gen"]["$count_"]["gen_status"] = 1
        DC_overlay_grid["gen"]["$count_"]["vg"] = 1.0
        DC_overlay_grid["gen"]["$count_"]["source_id"] = []
        DC_overlay_grid["gen"]["$count_"]["name"] = "Offshore_Wind_$(idx)"  # Assumption here, to be checked
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"],"gen")
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"], count_)
    end

    
    ##### Conventional gens  #####
    for idx in 1:length(solar_pv) 
        count_ += 1
        DC_overlay_grid["gen"]["$count_"] = Dict{String,Any}()
        DC_overlay_grid["gen"]["$count_"]["index"] = deepcopy(count_)
        DC_overlay_grid["gen"]["$count_"]["gen_bus"] = deepcopy(idx) # SUM OF THE ENTSO-E TYNDP CAPACITY
        DC_overlay_grid["gen"]["$count_"]["pmax"] = xf["RES_MVA"]["$(flexible_gens[idx])2"]/DC_overlay_grid["baseMVA"]#5*10^5/DC_overlay_grid["baseMVA"] #High value to always have adequacy, assumption, to be discussed
        DC_overlay_grid["gen"]["$count_"]["pmin"] = 0.0 
        DC_overlay_grid["gen"]["$count_"]["qmax"] =  DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$count_"]["qmin"] = -DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        #########################################################################
        DC_overlay_grid["gen"]["$count_"]["cost"] = [100.0, 0.0] # Made-up values
        #########################################################################
        DC_overlay_grid["gen"]["$count_"]["marginal_cost"] = 2.0 # Made-up values
        DC_overlay_grid["gen"]["$count_"]["co2_add_on"] = 1.0 # Made-up values
        DC_overlay_grid["gen"]["$count_"]["ncost"] = 2
        DC_overlay_grid["gen"]["$count_"]["model"] = 2
        DC_overlay_grid["gen"]["$count_"]["type"] = "Conventional"
        DC_overlay_grid["gen"]["$count_"]["gen_status"] = 1
        DC_overlay_grid["gen"]["$count_"]["vg"] = 1.0
        DC_overlay_grid["gen"]["$count_"]["source_id"] = []
        DC_overlay_grid["gen"]["$count_"]["name"] = "Conventional_gen_$(idx)"  # Assumption here, to be checked
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"],"gen")
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"], count_)
    end

    ##### VOLL  #####
    for idx in 1:length(solar_pv) 
        count_ += 1
        DC_overlay_grid["gen"]["$count_"] = Dict{String,Any}()
        DC_overlay_grid["gen"]["$count_"]["index"] = deepcopy(count_)
        DC_overlay_grid["gen"]["$count_"]["gen_bus"] = deepcopy(idx) # SUM OF THE ENTSO-E TYNDP CAPACITY
        DC_overlay_grid["gen"]["$count_"]["pmax"] = 0.0#/DC_overlay_grid["baseMVA"] #High value to always have adequacy, assumption, to be discussed
        DC_overlay_grid["gen"]["$count_"]["pmin"] = 0.0 
        DC_overlay_grid["gen"]["$count_"]["qmax"] =  0.0#DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        DC_overlay_grid["gen"]["$count_"]["qmin"] = 0.0#-DC_overlay_grid["gen"]["$count_"]["pmax"]*0.5
        #########################################################################
        DC_overlay_grid["gen"]["$count_"]["cost"] = [500.0, 0.0] # Made-up values
        #########################################################################
        DC_overlay_grid["gen"]["$count_"]["marginal_cost"] = 2.0 # Made-up values
        DC_overlay_grid["gen"]["$count_"]["co2_add_on"] = 1.0 # Made-up values
        DC_overlay_grid["gen"]["$count_"]["ncost"] = 2
        DC_overlay_grid["gen"]["$count_"]["model"] = 2
        DC_overlay_grid["gen"]["$count_"]["type"] = "VOLL"
        DC_overlay_grid["gen"]["$count_"]["gen_status"] = 1
        DC_overlay_grid["gen"]["$count_"]["vg"] = 1.0
        DC_overlay_grid["gen"]["$count_"]["source_id"] = []
        DC_overlay_grid["gen"]["$count_"]["name"] = "VOLL_gen_$(idx)"  # Assumption here, to be checked
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"],"gen")
        push!(DC_overlay_grid["gen"]["$count_"]["source_id"], count_)
    end

    # Sort RES time series
    res_time_series = Dict{String,Any}()
    count_ = 0
    for idx in 1:length(solar_pv)
        count_ += 1
        res_time_series["$count_"] = Dict{String,Any}()
        res_time_series["$count_"]["name"] = "Solar_PV_$idx"
        res_time_series["$count_"]["time_series"] = []
        for h in (start_hour+1):(number_of_hours+1)
            push!(res_time_series["$count_"]["time_series"],xf["RES_PU"]["$(solar_pv[idx])$(h)"])
        end
    end
    for idx in 1:length(onshore_wind)
        count_ += 1
        res_time_series["$count_"] = Dict{String,Any}()
        res_time_series["$count_"]["name"] = "Onshore_Wind_$idx"
        res_time_series["$count_"]["time_series"] = []
        for h in (start_hour+1):(number_of_hours+1)
            push!(res_time_series["$count_"]["time_series"],xf["RES_PU"]["$(onshore_wind[idx])$(h)"])
        end
    end
    for idx in 1:length(offshore_wind)
        count_ += 1
        res_time_series["$count_"] = Dict{String,Any}()
        res_time_series["$count_"]["name"] = "Offshore_Wind_$idx"
        res_time_series["$count_"]["time_series"] = []
        for h in (start_hour+1):(number_of_hours+1)
            push!(res_time_series["$count_"]["time_series"],xf["RES_PU"]["$(offshore_wind[idx])$(h)"])
        end
    end

    ######
    # Making sure all the keys for PowerModels are there
    DC_overlay_grid["source_type"] = deepcopy(test_grid["source_type"])
    DC_overlay_grid["switch"] = deepcopy(test_grid["switch"])
    DC_overlay_grid["shunt"] = deepcopy(test_grid["shunt"])
    DC_overlay_grid["dcline"] = deepcopy(test_grid["dcline"])
    DC_overlay_grid["storage"] = deepcopy(test_grid["storage"])

    string_data = JSON.json(DC_overlay_grid)
    open(output_filename*"_$(conv_power)_GW_convdc.json","w" ) do f
        write(f,string_data)
    end

    string_data_demand = JSON.json(demand_time_series)
    open(output_filename*"_Demand_$(start_hour)_$(number_of_hours)"*".json","w" ) do f
        write(f,string_data_demand)
    end

    string_data_res = JSON.json(res_time_series)
    open(output_filename*"_RES_$(start_hour)_$(number_of_hours)"*".json","w" ) do f
        write(f,string_data_res)
    end
    return DC_overlay_grid, demand_time_series, res_time_series
end

function solve_opf_timestep(data,RES,load,timesteps,conv_power;output_filename::String = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC_grid_overlay_results/results")
    #function solve_opf_timestep(data,RES,load,timesteps,conv_power;output_filename::String = "./results/OPF_results_selected_timesteps")
    result_timesteps_dc = Dict{String,Any}()
    result_timesteps_ac = Dict{String,Any}()
    result_timesteps_load = Dict{String,Any}()
    #tcs=[]
    for t in timesteps
        println(t)
        test_case_timestep = deepcopy(data)
        res_total=Dict(1=>0.0,2=>0.0,3=>0.0,4=>0.0,5=>0.0,6=>0.0)
        load_total=Dict(1=>0.0,2=>0.0,3=>0.0,4=>0.0,5=>0.0,6=>0.0)
        for (g_id,g) in test_case_timestep["gen"]
            if (g["type"] != "Conventional" && g["type"] != "VOLL")
                res_total[g["gen_bus"]]=res_total[g["gen_bus"]]+g["pmax"]*RES["$t"][g_id]["time_series"]
                g["pmax"] = deepcopy(g["pmax"]*RES["$t"][g_id]["time_series"])
                g["qmax"] = deepcopy(g["qmax"]*RES["$t"][g_id]["time_series"]) 
                g["qmin"] = deepcopy(-1*g["qmax"]*RES["$t"][g_id]["time_series"]) 
            end
        end
        for (l_id,l) in test_case_timestep["load"]
            load_total[l["load_bus"]]=load_total[l["load_bus"]]+load["$t"]["Bus_"*l_id]["time_series"]*l["cosphi"]
            l["pd"] = deepcopy(load["$t"]["Bus_"*l_id]["time_series"]*l["cosphi"])
            l["qd"] = 0.0#deepcopy(load["$t"]["Bus_"*l_id]["time_series"]*sqrt(1-(l["cosphi"])^2))
        end

        #Sets price of most expensive generator based on regional RES penetration
        for (g_id,g) in test_case_timestep["gen"]
            if (g["type"] == "Conventional")
                ratio=load_total[g["gen_bus"]]/res_total[g["gen_bus"]]
                cost=100+ratio*10
                println(g["pmax"])
                g["cost"]=[cost,0]
            end
        end


        #Sets price of most expensive generator based on regional RES penetration
        #VOLL is set to zero for all simulaitons at the moment
        for (g_id,g) in test_case_timestep["gen"]
            if (g["type"] == "VOLL")
                ratio=load_total[g["gen_bus"]]/res_total[g["gen_bus"]]
                cost=500+ratio*10
                #println(cost)
                g["cost"]=[cost,0]
            end
        end
        
        ########################################################################################
        #to adjust P2P converters 28 and 29
        #test_case["convdc"]["29"]
        test_case_timestep["convdc"]["25"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["26"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["27"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["28"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["29"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["30"]["Pacmax"]=30.0

        test_case_timestep["convdc"]["25"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["26"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["27"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["28"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["29"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["30"]["Pacmin"]=-30.0
        #######################################################################################

        ########################################################################################
        #to remove genertor 16

        #=test_case_timestep["gen"]["16"]["pmax"]=0.0

        test_case_timestep["gen"]["16"]["pmin"]=0.0

        test_case_timestep["gen"]["16"]["qmax"]=test_case_timestep["gen"]["16"]["pmax"]/2

        test_case_timestep["gen"]["16"]["qmin"]=-1*test_case_timestep["gen"]["16"]["pmax"]/2=#
        ##########################################################################################
            

        ########################################################################################
        #to remove P2P converters 28 and 29
        #test_case["convdc"]["29"]
        #test_case_timestep["convdc"]["28"]["Pacmax"]=test_case_timestep["convdc"]["28"]["Pacmin"]=0.0
        #test_case_timestep["convdc"]["29"]["Pacmax"]=test_case_timestep["convdc"]["29"]["Pacmin"]=0.0

        #test_case_timestep["convdc"]["28"]["Pacmax"]=test_case_timestep["convdc"]["28"]["Pacrated"]=0.1
        #######################################################################################

        #push!(tcs,test_case_timestep)
        #result_timesteps_dc["$t"] = deepcopy(_PMACDC.run_acdcopf(test_case_timestep, DCPPowerModel, gurobi; setting = s))
        result_timesteps_ac["$t"] = deepcopy(_PMACDC.run_acdcopf(test_case_timestep, ACPPowerModel, ipopt; setting = s))
        result_timesteps_load["$t"] = deepcopy(test_case_timestep)
    
    end
    
    return result_timesteps_ac,result_timesteps_load#, tcs
end

function solve_opf_timestep_dc(data,RES,load,timesteps,conv_power;output_filename::String = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC_grid_overlay_results/results")
    #function solve_opf_timestep(data,RES,load,timesteps,conv_power;output_filename::String = "./results/OPF_results_selected_timesteps")
    result_timesteps_dc = Dict{String,Any}()
    result_timesteps_ac = Dict{String,Any}()
    result_timesteps_load = Dict{String,Any}()
    #tcs=[]
    for t in timesteps
        println(t)
        test_case_timestep = deepcopy(data)
        res_total=Dict(1=>0.0,2=>0.0,3=>0.0,4=>0.0,5=>0.0,6=>0.0)
        load_total=Dict(1=>0.0,2=>0.0,3=>0.0,4=>0.0,5=>0.0,6=>0.0)
        for (g_id,g) in test_case_timestep["gen"]
            if (g["type"] != "Conventional" && g["type"] != "VOLL")
                res_total[g["gen_bus"]]=res_total[g["gen_bus"]]+g["pmax"]*RES["$t"][g_id]["time_series"]
                g["pmax"] = deepcopy(g["pmax"]*RES["$t"][g_id]["time_series"])
                g["qmax"] = deepcopy(g["qmax"]*RES["$t"][g_id]["time_series"]) 
                g["qmin"] = deepcopy(-1*g["qmax"]*RES["$t"][g_id]["time_series"]) 
            end
        end
        for (l_id,l) in test_case_timestep["load"]
            load_total[l["load_bus"]]=load_total[l["load_bus"]]+load["$t"]["Bus_"*l_id]["time_series"]*l["cosphi"]
            l["pd"] = deepcopy(load["$t"]["Bus_"*l_id]["time_series"]*l["cosphi"])
            l["qd"] = 0.0#deepcopy(load["$t"]["Bus_"*l_id]["time_series"]*sqrt(1-(l["cosphi"])^2))
        end

        #Sets price of most expensive generator based on regional RES penetration
        for (g_id,g) in test_case_timestep["gen"]
            if (g["type"] == "Conventional")
                ratio=load_total[g["gen_bus"]]/res_total[g["gen_bus"]]
                cost=100+ratio*10
                println(g["pmax"])
                g["cost"]=[cost,0]
            end
        end


        #Sets price of most expensive generator based on regional RES penetration
        #VOLL is set to zero for all simulaitons at the moment
        for (g_id,g) in test_case_timestep["gen"]
            if (g["type"] == "VOLL")
                ratio=load_total[g["gen_bus"]]/res_total[g["gen_bus"]]
                cost=500+ratio*10
                #println(cost)
                g["cost"]=[cost,0]
            end
        end
        
        ########################################################################################
        #to adjust P2P converters 28 and 29
        #test_case["convdc"]["29"]
        test_case_timestep["convdc"]["25"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["26"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["27"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["28"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["29"]["Pacmax"]=30.0
        test_case_timestep["convdc"]["30"]["Pacmax"]=30.0

        test_case_timestep["convdc"]["25"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["26"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["27"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["28"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["29"]["Pacmin"]=-30.0
        test_case_timestep["convdc"]["30"]["Pacmin"]=-30.0
        #######################################################################################

        ########################################################################################
        #to remove genertor 16

        #=test_case_timestep["gen"]["16"]["pmax"]=0.0

        test_case_timestep["gen"]["16"]["pmin"]=0.0

        test_case_timestep["gen"]["16"]["qmax"]=test_case_timestep["gen"]["16"]["pmax"]/2

        test_case_timestep["gen"]["16"]["qmin"]=-1*test_case_timestep["gen"]["16"]["pmax"]/2=#
        ##########################################################################################
            

        ########################################################################################
        #to remove P2P converters 28 and 29
        #test_case["convdc"]["29"]
        #test_case_timestep["convdc"]["28"]["Pacmax"]=test_case_timestep["convdc"]["28"]["Pacmin"]=0.0
        #test_case_timestep["convdc"]["29"]["Pacmax"]=test_case_timestep["convdc"]["29"]["Pacmin"]=0.0

        #test_case_timestep["convdc"]["28"]["Pacmax"]=test_case_timestep["convdc"]["28"]["Pacrated"]=0.1
        #######################################################################################

        #push!(tcs,test_case_timestep)
        result_timesteps_dc["$t"] = deepcopy(_PMACDC.run_acdcopf(test_case_timestep, DCPPowerModel, gurobi; setting = s))
        #result_timesteps_ac["$t"] = deepcopy(_PMACDC.run_acdcopf(test_case_timestep, ACPPowerModel, ipopt; setting = s))
        result_timesteps_load["$t"] = deepcopy(test_case_timestep)
    
    end
    
    return result_timesteps_dc,result_timesteps_load#, tcs
end

######################################### topology check


function show_topo(test_case)
    map=map4topo_display()


    every=Array{GenericTrace{Dict{Symbol,Any}},1}()
    ac_buses = scatter(;x=[first(v) for (k,v) in map["busac_i"]], y=[last(v) for (k,v) in map["busac_i"]],mode="marker+text", textfont_color="red",textposition="top right",text=[k for (k,v) in map["busac_i"]])
    push!(every, ac_buses)

    dc_busesl = scatter(;x=[first(v) for (k,v) in map["busdc_i"] if (parse(Int,k)<9)], y=[last(v) for (k,v) in map["busdc_i"] if (parse(Int,k)<9)], marker_color="black",mode="marker+text", textfont_color="black",textposition="bottom left", marker_size=40,text=[k for (k,v) in map["busdc_i"] if (parse(Int,k)<9)])
    push!(every, dc_busesl)
    dc_busesr = scatter(;x=[first(v) for (k,v) in map["busdc_i"]  if (parse(Int,k)>8)], y=[last(v) for (k,v) in map["busdc_i"]  if (parse(Int,k)>8)], marker_color="black",mode="marker+text", textfont_color="black",textposition="bottom right", marker_size=30,text=[k for (k,v) in map["busdc_i"] if (parse(Int,k)>8)])
    push!(every, dc_busesr)

    for (k,v) in test_case["branch"]
        acb=scatter(;x=[first(map["busac_i"][string(v["f_bus"])]),first(map["busac_i"][string(v["t_bus"])])], y=[last(map["busac_i"][string(v["f_bus"])]),last(map["busac_i"][string(v["t_bus"])])], line_color="red", mode="lines")  
        push!(every,acb)
    end

    for (k,v) in test_case["branchdc"]
        
            dcb=scatter(;x=[first(map["busdc_i"][string(v["fbusdc"])]),first(map["busdc_i"][string(v["tbusdc"])])], y=[last(map["busdc_i"][string(v["fbusdc"])]), last(map["busdc_i"][string(v["tbusdc"])])], line_color="black", mode="lines")

        push!(every,dcb)
    end

    for (k,v) in test_case["convdc"]
        acdc=scatter(;x=[first(map["busac_i"][string(v["busac_i"])]),first(map["busdc_i"][string(v["busdc_i"])])], y=[last(map["busac_i"][string(v["busac_i"])]),last(map["busdc_i"][string(v["busdc_i"])])], line_color="blue", mode="lines")  
        push!(every,acdc)
    end
        
    plot(every)
end

function map4topo_display()
    map=Dict("busac_i"=>Dict(),"busdc_i"=>Dict())
    map["busac_i"]["1"]=(1.1,2.1)
    map["busac_i"]["2"]=(2.3,3.1)
    map["busac_i"]["3"]=(2.2,2.1)
    map["busac_i"]["4"]=(2.1,1.1)
    map["busac_i"]["5"]=(4.1,1.1)
    map["busac_i"]["6"]=(4.2,2.1)
    map["busdc_i"]["1"]=(1,12)
    map["busdc_i"]["2"]=(2,13)
    map["busdc_i"]["3"]=(2,12)
    map["busdc_i"]["4"]=(2,11)
    map["busdc_i"]["5"]=(4,11)
    map["busdc_i"]["6"]=(4,12)

    map["busdc_i"]["7"]=(1,1.6)
    map["busdc_i"]["8"]=(2,1)
    map["busdc_i"]["9"]=(0.8,2)
    map["busdc_i"]["10"]=(2,2)
    map["busdc_i"]["11"]=(1,2.4)
    map["busdc_i"]["12"]=(2,3)
    map["busdc_i"]["13"]=(2,2.8)
    map["busdc_i"]["14"]=(2,2.2)
    return map
end    

