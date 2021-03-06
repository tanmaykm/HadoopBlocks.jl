# calculates colsums of a large matrix stored in HDFS
# julia -p 3
# include("test_colsum.jl")

using Elly
using HadoopBlocks

const INP = "hdfs://tan@localhost:9000/colsuminp.csv"

if myid() == 1
    function gendata(M, N)
        open(HDFSFile(INP), "w") do f
            for m in 1:M
                write(f, join(map(string, rand(N)), ","), "\n")
            end
        end
    end
    gendata(10^5, 5)
end

# split script here and uncomment below lines to run data generation and computation separately
#using Elly
#using HadoopBlocks
#const INP = "hdfs://tan@localhost:9000/colsuminp.csv"

function findrow(r::HdfsBlockReader, iter_status)
    rec = HadoopBlocks.find_rec(r, iter_status, Vector)
    #HadoopBlocks.logmsg("findrow found rec:$rec")
    rec    
end

function maprow(rec)
    #HadoopBlocks.logmsg("maprow called with rec:$rec")
    [tuple([parse(Float64, x) for x in rec]...)]
end

function collectrow(results, rec)
    #HadoopBlocks.logmsg("collectrow called with results:$results rec:$rec")
    isempty(rec) && (return results)
    (results == nothing) && (return rec)
    tuple([results[x]+rec[x] for x in 1:length(results)]...)
end

function reducerow(reduced, results...)
    #HadoopBlocks.logmsg("reducerow called with reduced:$reduced results:$results")
    (nothing == reduced) && (reduced = zeros(Float64, length(results[1])))
    for res in results
        (nothing == res) && continue
        #HadoopBlocks.logmsg("reducerow res:$res")
        #HadoopBlocks.logmsg("reducerow res:$([res...])")
        for x in 1:length(res)
            reduced[x] += res[x]
        end
    end
    #HadoopBlocks.logmsg("reducerow returning reduced:$reduced")
    reduced
end

function wait_results(j_mon)
    loopstatus = true
    while(loopstatus)
        sleep(5)
        jstatus,jstatusinfo = status(j_mon,true)
        ((jstatus == "error") || (jstatus == "complete")) && (loopstatus = false)
        (jstatus == "running") && println("$(j_mon): $(jstatusinfo)% complete...")
    end
    wait(j_mon)
    println("time taken (total time, wait time, run time): $(times(j_mon))")
    println("")
end


j = dmapreduce(MRHdfsFileInput([INP], findrow), maprow, collectrow, reducerow)
wait_results(j)
println(results(j))
