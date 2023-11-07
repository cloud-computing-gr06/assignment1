#!/usr/bin/env python3
# Before running this script, install required Pythons package manager:
#   sudo apt update && sudo apt install -y python-pip
# Then install required packages:
#   pip install pandas matplotlib seaborn

import pathlib
import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
import matplotlib.dates as md
import datetime as dt


machine_types = ["n1", "n2", "c3"]
platforms = ["native", "docker", "kvm", "qemu"]
metrics = ["cpu", "mem", "diskRand", "diskSeq"]

temp_df_list = []
for mt in machine_types:
    for p in platforms:
        path_to_file = pathlib.Path(__file__).parent.joinpath(f"{mt}-{p}-results.csv")
        if path_to_file.exists():
            temp_df = pd.read_csv(path_to_file)
            temp_df["time"] = md.date2num([dt.datetime.fromtimestamp(ts) for ts in temp_df["time"].values])
            temp_df["machine_type"] = mt
            temp_df["platform"] = p
            temp_df_list.append(temp_df)

final_df = pd.concat(temp_df_list, ignore_index=True)

# Create a figure and a grid of subplots
fig, axes = plt.subplots(len(metrics), len(machine_types), figsize=(12, 8), sharex=True, sharey='row')

for i, m in enumerate(metrics):
    for j, mt in enumerate(machine_types):
        ax = axes[i, j]
        sub_df = final_df.loc[final_df.machine_type == mt, ["time", "platform", m]].copy()
        if len(sub_df):
            ax = sns.lineplot(data=sub_df, ax=ax, x="time", y=m, hue="platform")
        xfmt = md.DateFormatter('%d.%m.%Y %H:%M:%S')
        ax.xaxis.set_major_formatter(xfmt)
        ax.set_xticks(ax.get_xticks())
        ax.set_xticklabels(ax.get_xticklabels(), rotation=45)
        if i == 0:
            ax.set_title(f"Machine Type: {mt.capitalize()}", fontsize=14)
        handles, labels = ax.get_legend_handles_labels()
        ax.legend([],[], frameon=False)

# Create a legend outside of the subplots
legend = fig.legend(handles, labels, loc='upper center', bbox_to_anchor=(0.5, 1.05),
                    fancybox=True, ncol=4, framealpha=1.0, shadow=True, fontsize=12)

plt.tight_layout()
plt.savefig("all-results-plot.png", dpi=300, bbox_inches = "tight")