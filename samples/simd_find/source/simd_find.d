/**
Sample with demonstration of vectorized IndexOf.

Currently not implemented due to XMM.PMOVMSKB absence.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Iakh Takh
*/
module simd_find.simd_find;

import core.simd;
import core.bitop;

import std.algorithm;
import std.simd;

immutable size_t ArraySize = 16;

int simdIndexOf(ubyte niddle, ref const ubyte[ArraySize] haystack)
{
    ubyte16 arr;
    arr.array = haystack[];
    ubyte16 niddles;
    niddles.array[] = niddle;
    ubyte16 result;
    result = __simd_sto(XMM.PCMPEQB, arr, niddles);
    alias Mask = ulong;

    if (Mask mask = *cast(Mask*)(result.array.ptr))
    {
        return bsf(mask) / 8;
    }
    else if (Mask mask = *cast(Mask*)(result.array.ptr + Mask.sizeof))
    {
        return bsf(mask) / 8 + cast(int)Mask.sizeof;
    }
    else
    {
        return -1;
    }

}

int stdSIMDIndexOf(ubyte niddle, ref const ubyte[ArraySize] haystack)
{
    ubyte16 arr;
    arr.array = haystack[];
    ubyte16 niddles;
    niddles.array[] = niddle;
    ubyte16 result;
    result = std.simd.maskEqual(arr, niddles);
    alias Mask = ulong;

    if (Mask mask = *cast(Mask*)(result.array.ptr))
    {
        return bsf(mask) / 8;
    }
    else if (Mask mask = *cast(Mask*)(result.array.ptr + Mask.sizeof))
    {
        return bsf(mask) / 8 + cast(int)Mask.sizeof;
    }
    else
    {
        return -1;
    }

}

version(unittest)
{
    import std.format;
}

unittest
{
    ubyte[ArraySize] arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
    assert(simdIndexOf(10, arr) == 9, "%s".format(simdIndexOf(10, arr)));
}

unittest
{
    ubyte[ArraySize] arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
    assert(simdIndexOf(3, arr) == 2, "%s".format(simdIndexOf(10, arr)));
}

unittest
{
    ubyte[ArraySize] arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
    assert(simdIndexOf(20, arr) == -1, "%s".format(simdIndexOf(10, arr)));
}

int naiveIndexOf(ubyte niddle, ref const ubyte[ArraySize] haystack)
{
    for (int i = 0; i < ArraySize; ++i)
    {
        if (haystack[i] == niddle)
        {
            return i;
        }
    }

    return -1;
}

int binaryIndexOf(ubyte niddle, ref const ubyte[ArraySize] haystack)
{
    /// https://en.wikipedia.org/wiki/Binary_search_algorithm
    int imin = 0;
    int imax = ArraySize - 1;

    while(true)
    {
        if (imax < imin)
        {
            return -1;
        }
        else
        {
            int imid = (imin + imax) / 2;

            if (haystack[imid] > niddle)
            {
                imax = imid - 1;
                continue;
            }
            else if (haystack[imid] < niddle)
            {
                imin = imid + 1;
                continue;
            }
            else
            {
                return imid;
            }
        }
    }
}

immutable ubyte[ArraySize] arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

void runSIMD()
{
    static int i = 0;
    simdIndexOf(cast(ubyte)(i++ % ArraySize + 1), arr);
}

void runSTDSIMD()
{
    static int i = 0;
    stdSIMDIndexOf(cast(ubyte)(i++ % ArraySize + 1), arr);
}

void runNaive()
{
    static int i = 0;
    naiveIndexOf(cast(ubyte)(i++ % ArraySize + 1), arr);
}

void runBinary()
{
    static int i = 0;
    binaryIndexOf(cast(ubyte)(i++ % ArraySize + 1), arr);
}

void runNothing()
{
}

void runBenchmark()
{
    import std.stdio;
    import std.datetime;
    auto t = benchmark!(
            runSIMD
            , runBinary
            , runNaive
            , runSTDSIMD
            )(10_000);
    writeln("-----");
    writeln("SIMD:    ", t[0]);
    writeln("Binary:  ", t[1]);
    writeln("Naive:   ", t[2]);
    writeln("SSIMD:   ", t[3]);
}

void main()
{
    runBenchmark();
    runBenchmark();
}
