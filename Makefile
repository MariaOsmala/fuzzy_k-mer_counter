
CFLAGS= -std=c++23 -march=native -Wshadow -Wall -Wextra -pedantic

SEQAN=deps/seqan3/include/seqan3/io/sequence_file/input.hpp

INCLUDE= -isystem deps/seqan3/include

HEADERS= include/mer.hpp include/util.hpp include/seq.hpp

count: count.cpp $(SEQAN) $(HEADERS)
	g++ -O3 $(CFLAGS) $(INCLUDE) -fopenmp count.cpp -o count -lz -DSEQAN3_HAS_BZIP2=0

debug_count: count.cpp $(SEQAN) $(HEADERS)
	g++ -g -fanalyzer $(CFLAGS) $(INCLUDE) count.cpp -o debug_count -lz -DSEQAN3_HAS_BZIP2=0

$(SEQAN): 
	git submodule update --init