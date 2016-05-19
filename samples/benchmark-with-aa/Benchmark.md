# Comparison speed of D's asociative array and adaptive radix tree

## Hardware

| | |
| --- | ---: |
|Architecture:|          x86_64|
|CPU(s):|                4|
|Thread(s) per core:|    2|
|Core(s) per socket:|    2|
|Model name:|            Intel(R) Core(TM) i5-323 2.60GHz|
|L1d cache:|             32K|
|L2 cache:|              256K|
|L3 cache:|              3072K|

## Run

Compile program:
```
dub build --build=release
```
Feed benchmarck results to the script:
```
./benchmark-with-aa | ./source/drawPlot.py
```
See results

## Test insertion

Sparse - insert in random places

Dense - start at random place and insert several elements sequentialy, then jamp to another random place and so on.

Sequential - start at some index and insert all elements one-by-one

For indexes used 4-byte integer. Sizes of first 3 datasets is about corresponding cache levels.

![figure 1](figure_1.png)
