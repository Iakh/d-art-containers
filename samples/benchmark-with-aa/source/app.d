import std.algorithm;
import std.datetime;
import std.random;
import std.range;
import std.stdio;

import art.sparse_array;

struct BMFunc
{
    this(int dataCount) @safe pure
    {
        m_dataCount = dataCount;
    }

    void runInsertSeq(AA)()
    {
        AA a;

        foreach (i; iota(m_dataCount))
        {
            a[i] = i;
        }
    }

    void runInsertDense(AA)()
    {
        AA a;
        enum maxChunkSize = 500;

        for (int i = m_dataCount, step = maxChunkSize;
                i > 0;
                i -= step, step = uniform(0, maxChunkSize))
        {
            auto start = uniform!int;

            foreach (j; iota(step))
            {
                a[j + start] = j + start;
            }
        }
    }

    void runInsertSparse(AA)()
    {
        AA a;

        for (int i = m_dataCount; i > 0; --i)
        {
            auto j = uniform!int;

            a[j] = j;
        }
    }

    private immutable int m_dataCount;
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

enum BMTimes = 5;

void runInsertSeqBM()
{
    auto sa = () => BMFunc(1000_000).runInsertSeq!(SparseArray!(int, int));
    auto aa = () => BMFunc(1000_000).runInsertSeq!(int[int]);
    auto t = benchmark!(sa, aa)(BMTimes);
    auto n = normalize(t);
    writeln("-----");
    writeln("SA:  ", n[0]);
    writeln("AA:  ", n[1]);
}

void runInsertDenseBM()
{
    auto sa = () => BMFunc(1000_000).runInsertDense!(SparseArray!(int, int));
    auto aa = () => BMFunc(1000_000).runInsertDense!(int[int]);
    auto t = benchmark!(sa, aa)(BMTimes);
    auto n = normalize(t);
    writeln("-----");
    writeln("SA:  ", n[0]);
    writeln("AA:  ", n[1]);
}

void runInsertSparseBM()
{
    auto sa = () => BMFunc(1000_000).runInsertSparse!(SparseArray!(int, int));
    auto aa = () => BMFunc(1000_000).runInsertSparse!(int[int]);
    auto t = benchmark!(sa, aa)(BMTimes);
    auto n = normalize(t);
    writeln("-----");
    writeln("SA:  ", n[0]);
    writeln("AA:  ", n[1]);
}

void main()
{
    writeln("Seq -----------");
    foreach (i; iota(3))
    {
        runInsertSeqBM();
    }
    writeln("Dense----------");
    foreach (i; iota(3))
    {
        runInsertDenseBM();
    }
    writeln("Sparse---------");
    foreach (i; iota(3))
    {
        runInsertSparseBM();
    }
}
