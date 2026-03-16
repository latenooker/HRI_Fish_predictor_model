# Data Dictionary

## ResponseVariables_full.csv

All survey records across years (2018, 2021, 2023) at the site level.

| Column | Description | Units |
|--------|-------------|-------|
| Code | Survey code assigned by AGRRA | — |
| Name | Reef/site name | — |
| Latitude | Survey latitude | decimal degrees |
| Longitude | Survey longitude | decimal degrees |
| YEAR | Survey year | — |
| Depth | Average depth of survey | meters |
| Reef Type | Reef morphology classification | — |
| tCORALavg | Mean live stony coral cover | % |
| tCORALstd | SD of live stony coral cover | % |
| tFMAavg | Mean fleshy macroalgae cover | % |
| tFMAstd | SD of fleshy macroalgae cover | % |
| tLUTJavg | Mean biomass — Snappers (Lutjanidae) | g/100m2 |
| tLUTJstd | SD biomass — Snappers | g/100m2 |
| tSERRavg | Mean biomass — Groupers (Serranidae) | g/100m2 |
| tSERRstd | SD biomass — Groupers | g/100m2 |
| tCARAavg | Mean biomass — Jacks (Carangidae) | g/100m2 |
| tCARAstd | SD biomass — Jacks | g/100m2 |
| tSPHYavg | Mean biomass — Barracuda (Sphyraenidae) | g/100m2 |
| tSPHYstd | SD biomass — Barracuda | g/100m2 |
| tHAEMavg | Mean biomass — Grunts (Haemulidae) | g/100m2 |
| tHAEMstd | SD biomass — Grunts | g/100m2 |
| tCommBiomass | Total commercial fish biomass (sum of 5 family means) | g/100m2 |
| tACANavg | Mean biomass — Surgeonfish (Acanthuridae) | g/100m2 |
| tACANstd | SD biomass — Surgeonfish | g/100m2 |
| tSCARavg | Mean biomass — Parrotfish (Scaridae) | g/100m2 |
| tSCARstd | SD biomass — Parrotfish | g/100m2 |
| tHerbiBiomass | Total herbivorous fish biomass (tACANavg + tSCARavg) | g/100m2 |

## ResponseVariables_input.csv

Site-level averages across all survey years. One row per unique site.

| Column | Description | Units |
|--------|-------------|-------|
| Name | Reef/site name | — |
| Latitude | Survey latitude | decimal degrees |
| Longitude | Survey longitude | decimal degrees |
| Reef Type | Reef morphology classification | — |
| tCommBiomass_avg | Mean commercial fish biomass across years | g/100m2 |
| tHerbiBiomass_avg | Mean herbivorous fish biomass across years | g/100m2 |
| tCORALavg_avg | Mean coral cover across years | % |
| tFMAavg_avg | Mean fleshy macroalgae cover across years | % |

## AGRRA Family Code Key

| Code | Family | Common Name |
|------|--------|-------------|
| tLUTJ | Lutjanidae | Snappers |
| tSERR | Serranidae/Epinephelidae | Groupers |
| tCARA | Carangidae | Jacks |
| tSPHY | Sphyraenidae | Barracuda |
| tHAEM | Haemulidae | Grunts |
| tACAN | Acanthuridae | Surgeonfish |
| tSCAR | Scaridae | Parrotfish |
| tCORAL | — | Live stony coral cover |
| tFMA | — | Fleshy macroalgae cover |
