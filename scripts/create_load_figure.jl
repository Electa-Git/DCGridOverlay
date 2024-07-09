# Script to create the DC grid overlay project's grid
# Refer to the excel file in the package
# 7th August 2023
using XLSX
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using JSON
using JuMP
using Plots
#using CbaOPF

excel_file = XLSX.readxlsx("/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/Stephen's files/DC_overlay_grid.xlsx")

group_1 = deepcopy(excel_file["Demand"][:,1][2:8761])/10^3 # GW
group_2 = deepcopy(excel_file["Demand"][:,2][2:8761])/10^3 # GW
group_3 = deepcopy(excel_file["Demand"][:,3][2:8761])/10^3 # GW
group_4 = deepcopy(excel_file["Demand"][:,4][2:8761])/10^3 # GW
group_5 = deepcopy(excel_file["Demand"][:,5][2:8761])/10^3 # GW
group_6 = deepcopy(excel_file["Demand"][:,6][2:8761])/10^3 # GW

hours = collect(1:8760)

p5_10 = Plots.plot(hours, group_1, legend=:outertopright, label = "\$Zone~1\$",seriesalpha = 0.3,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Demand~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,200],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, group_2, legend=:outertopright, label = "\$Zone~2\$",xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Demand~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,200],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, group_3, legend=:outertopright, label = "\$Zone~3\$",seriesalpha = 1.0,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Demand~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,200],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, group_4, legend=:outertopright, label = "\$Zone~4\$",seriesalpha = 0.4,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Demand~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,200],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, group_5, legend=:outertopright, label = "\$Zone~5\$",seriesalpha = 0.6,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Demand~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,200],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
Plots.plot!(hours, group_6, legend=:outertopright, label = "\$Zone~6\$",seriesalpha = 0.5,xlabel = "\$Hours\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Demand~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,200],xlims=[1,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))


plot_filename = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/Report/Figures/Load.svg"

Plots.savefig(p5_10, plot_filename)


total_res_1 = deepcopy(excel_file["RES_MVA"][:,28][4:8763])/10^3 # GW
total_res_2 = deepcopy(excel_file["RES_MVA"][:,29][4:8763])/10^3 # GW
total_res_3 = deepcopy(excel_file["RES_MVA"][:,30][4:8763])/10^3 # GW
total_res_4 = deepcopy(excel_file["RES_MVA"][:,31][4:8763])/10^3 # GW
total_res_5 = deepcopy(excel_file["RES_MVA"][:,32][4:8763])/10^3 # GW
total_res_6 = deepcopy(excel_file["RES_MVA"][:,33][4:8763])/10^3 # GW


total_res = total_res_1.+total_res_2.+total_res_3.+total_res_4.+total_res_5.+total_res_6
total_load = group_1+group_2+group_3+group_4+group_5+group_6

load_over_res = total_load./total_res

ratio = Plots.plot(hours,load_over_res,xlabel = "Hours",legend=:none,xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "Total load/ Total RES generation [-]",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[0,5.5],xlims=[1,8760])

# Proof that timestep 475 is the one with the maximum value
maximum(total_load./total_res)
total_load[475]/total_res[475]

plot_filename = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/DC overlay - SuperNode/Report/Figures/Ratio_load_RES.svg"

Plots.savefig(ratio, plot_filename)


