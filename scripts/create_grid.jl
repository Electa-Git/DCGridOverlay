# Script to create the DC grid overlay project's grid based on the develped function
# Refer to the excel file in the package
# 7th August 2023

using XLSX
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using JSON

# One can choose the Pmax of the conv_power among 2.0, 4.0 and 8.0 GW
conv_power = 6.0
grid, demand, res = create_grid(1,8760,conv_power)
