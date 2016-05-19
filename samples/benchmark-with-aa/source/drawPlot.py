#!/usr/bin/env python3

import sys
import json
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker

s = input()
print(s)
print("\n")

data = json.loads(s)
dataSizes = data.get("dataSizes")
plotCount = len(dataSizes)

fig, axes = plt.subplots(nrows=2, ncols=2)
axList = axes.flat

groups = ['sparse', 'dense', 'sequential']
types = ["ART", "AA"]

fig.suptitle("Relative time consumed by D's asociative arrays and ART to insert all keys.")

histData = []

for i in range(plotCount):
    arr = []

    for cn in types:
        group = []

        for gr in groups:
            t = data.get(gr)
            x = t.get(cn)[i]
            group.append(x)

        arr.append(group)

    histData.append(arr)

bins = [range(3), range(3)]
formatter = matplotlib.ticker.FixedFormatter(["0"] + groups)
for i in range(plotCount):
    ax = axList[i]
    ax.hist(bins, 3, weights=histData[i], histtype='bar', label=types)
    ax.legend(prop={'size': 10})
    ax.set_title('Keys total size (KB): ' + str(dataSizes[i] / 1024))
    ax.xaxis.set_major_formatter(formatter)

plt.tight_layout()
plt.show()
