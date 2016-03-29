import std.algorithm;
import std.datetime;
import std.range;
import std.stdio;

import art.sparse_array;

void runInsertSeq(AA)()
{
    AA a;

    foreach (i; iota(1000_000))
    {
        a[i] = i;
    }
}

auto normalize(T)(T t)
{
    auto a = minPos(t[])[0];
    double[t.length] res;
    foreach (i, v; t)
    {
        res[i] = cast(double)v.hnsecs/a.hnsecs;

    }

    return res;
}

void runInsertSeqBM()
{
    auto t = benchmark!(
            runInsertSeq!(SparseArray!(int, int))
            , runInsertSeq!(int[int])
            )(10);
    auto n = normalize(t);
    writeln("-----");
    writeln("SA:    ", n[0]);
    writeln("AA:  ", n[1]);
}

void main()
{
    runInsertSeqBM();
    runInsertSeqBM();
    runInsertSeqBM();
}
