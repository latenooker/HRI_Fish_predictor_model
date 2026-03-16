# AGRRA Methodology

Reference: [HRI AGRRA Dashboard](https://oref.maps.arcgis.com/apps/dashboards/bdb35a48e40b49a6b12267e38633fd67)

## Benthic Cover

The code for each benthic group directly below 100 points marked at 10-cm intervals along nominally 10-m benthic transects is recorded. Each benthic group proportion is calculated by summing the number of points for all its codes and dividing by total available points per transect. Percentage cover = proportion x 100. All transects for a given survey are averaged to give a final survey value.

- **Coral Cover (tCORAL)**: Percentage of reef surface covered by live hard corals, indicating structural complexity and habitat availability. Values summarized by survey (a site with multiple transects).

- **Fleshy Macroalgae Cover (tFMA)**: Proportion of reef covered by fleshy macroalgae, which can outcompete corals. High values signal ecological imbalance.

## Fish Biomass

Fish biomass is estimated from size class and length-weight formulas per surveyed species, calculated by family.

### Biomass Formula

Biomass for each individual fish:

```
Biomass = a * (S * TL2FL)^b
```

Where:
- `a`, `b` = species biomass curve coefficients (from FishBase, 2013 values)
- `S` = size (size class midpoint for AGRRA fishes)
- `TL2FL` = total length to fork length conversion factor (species-specific)

Summations calculate total biomass per species/group/family, normalized by dividing by transect area and multiplying by 100 to produce **grams per 100m2**. All transect-level values are averaged per survey.

### Commercial Fish Biomass (tCommBiomass)

Sum of mean biomass for five families:

| Code | Family | Species Included |
|------|--------|-----------------|
| tLUTJ | Lutjanidae (Snappers) | LANA Mutton Snapper, LAPO Schoolmaster, LBUC Blackfin Snapper, LCYA Cubera Snapper, LGRI Gray Snapper, LJOC Dog Snapper, LMAH Mahogany Snapper, LSYN Lane Snapper, OCHR Yellowtail Snapper |
| tSERR | Epinephelidae (Groupers) | CCRU Graysby, CFUL Coney, EADS Rock Hind, EGUT Red Hind, EITA Goliath Grouper, EMOR Red Grouper, ESTR Nassau Grouper, MACU Comb Grouper, MBON Black Grouper, MINT Yellowmouth Grouper, MMIC Gag, MPHE Scamp, MTIG Tiger Grouper, MVEN Yellowfin Grouper |
| tCARA | Carangidae (Jacks) | CRUB Bar Jack, TFAL Permit |
| tSPHY | Sphyraenidae (Barracuda) | SBAR Great Barracuda |
| tHAEM | Haemulidae (Grunts) | All grunt species |

### Herbivorous Fish Biomass (tHerbiBiomass)

Sum of mean biomass for two families:

| Code | Family | Species Included |
|------|--------|-----------------|
| tACAN | Acanthuridae (Surgeonfish) | ACHI Doctorfish, ACOE Blue Tang, ATRA Ocean Surgeonfish |
| tSCAR | Scaridae (Parrotfish) | CROS Bluelip Parrotfish, SATO Greenblotch Parrotfish, SAUR Redband Parrotfish, SCEL Midnight Parrotfish, SCER Blue Parrotfish, SCHR Redtail Parrotfish, SGUA Rainbow Parrotfish, SISE Striped Parrotfish, SRAD Bucktooth Parrotfish, SRUB Yellowtail Parrotfish, STAE Princess Parrotfish, SVET Queen Parrotfish, SVIR Stoplight Parrotfish |

**Note on pre-2023 data mapping**: In the 2011-2021 dataset, parrotfish are coded as `PARR` (mapped to `tSCAR`) and surgeonfish as `SURG` (mapped to `tACAN`).
