# Parse TYNDP 2024 electricity demand by country / scenario / year into a
# tidy csv. Sources (CC-BY 4.0, "TYNDP 2024 Scenarios"):
#   - DE / GA + REF 2019: Demand_Scenarios_..._After_Public_Consultation.xlsb,
#     sheet 3_DEMAND_OUTPUT (ETM-based; final energetic electricity demand,
#     sum of sector totals per country);
#   - NT+ 2030 / 2040: MMStandardOutputFile_NT{2030,2040}..., sheet
#     'Yearly Outputs', row 'Native Demand (excl. Pump load & Battery
#     charge)' per market zone, zones summed to countries (offshore hubs
#     carry no demand).
# Scopes differ between the two sources; the R side builds growth factors
# WITHIN each scenario's own series, so scope constants cancel.
from pathlib import Path
import pandas as pd

HERE = Path(__file__).parent
OUT = HERE / "tyndp_demand_raw.csv"

# model countries (pypsa_eur_41 buses); TYNDP writes GB as UK. Anything
# else in the sources (EU aggregates, Mediterranean rim zones) is dropped.
MODEL = {"AL", "AT", "BA", "BE", "BG", "CH", "CZ", "DE", "DK", "EE", "ES",
         "FI", "FR", "GB", "GR", "HR", "HU", "IE", "IT", "LT", "LU", "LV",
         "MD", "ME", "MK", "NL", "NO", "PL", "PT", "RO", "RS", "SE", "SI",
         "SK", "UA", "XK"}
RENAME = {"UK": "GB"}

rows = []

# --- DE / GA / REF from the demand workbook --------------------------------
P = HERE / "Demand_Scenarios_TYNDP_2024_After_Public_Consultation.xlsb"
df = pd.read_excel(P, sheet_name="3_DEMAND_OUTPUT", engine="pyxlsb",
                   header=None)
scen_row = df.iloc[0].tolist()
year_row = df.iloc[1].tolist()
body = df.iloc[2:].reset_index(drop=True)
body.columns = range(df.shape[1])
elec = body[(body[6] == "Electricity") & (body[7] == "Energy demand")]
# sector totals only (avoid subsector double counting)
elec = elec[elec[5] == "Total"]
print("sectors summed:", sorted(elec[4].unique()))
for col in range(10, df.shape[1]):
    scen = scen_row[col]
    year = year_row[col]
    if pd.isna(scen) or pd.isna(year):
        continue
    g = elec.groupby(1)[col].sum()  # by COUNTRY (column 1)
    for country, twh in g.items():
        country = RENAME.get(str(country), str(country))
        if country not in MODEL:
            continue
        rows.append({"source": "demand_workbook", "scenario": str(scen),
                     "country": country, "year": int(year),
                     "twh": float(twh)})

# --- NT+ from the market-modelling outputs ---------------------------------
for year, f in [(2030, "MMStandardOutputFile_NT2030_Plexos_CY2009_2.5_v40.xlsx"),
                (2040, "MMStandardOutputFile_NT2040_Plexos_CY2009_2.5_v40.xlsx")]:
    d = pd.read_excel(HERE / f, sheet_name="Yearly Outputs", header=None)
    zone_row = d.iloc[5].tolist()
    hit = d[d[0].astype(str).str.startswith("Native Demand", na=False)]
    assert len(hit) == 1, f"{f}: expected one Native Demand row, got {len(hit)}"
    vals = hit.iloc[0].tolist()
    per_country = {}
    for col in range(2, d.shape[1]):
        z = zone_row[col]
        if not isinstance(z, str) or len(z) < 4:
            continue
        v = pd.to_numeric(vals[col], errors="coerce")
        if pd.isna(v):
            continue
        per_country[z[:2]] = per_country.get(z[:2], 0.0) + float(v)
    for country, gwh in per_country.items():
        country = RENAME.get(country, country)
        if country not in MODEL:
            continue
        rows.append({"source": "mm_output", "scenario": "NT",
                     "country": country, "year": year, "twh": gwh / 1e3})

out = pd.DataFrame(rows)
out.to_csv(OUT, index=False)
print(out.groupby(["source", "scenario", "year"])
         .agg(countries=("country", "nunique"), twh=("twh", "sum"))
         .round(0))
print("wrote", OUT)
