
CFLAGS= -std=c++23 -march=native -Wshadow -Wall -Wextra -pedantic

SEQAN=deps/seqan3/include/seqan3/io/sequence_file/input.hpp

INCLUDE= -isystem deps/seqan3/include

HEADERS= include/mer.hpp include/util.hpp include/seq.hpp

count: count.cpp $(SEQAN) $(HEADERS)
	g++ -Ofast $(CFLAGS) $(INCLUDE) -fopenmp count.cpp -o count -lz

debug_count: count.cpp $(SEQAN) $(HEADERS)
	g++ -g -fanalyzer $(CFLAGS) $(INCLUDE) count.cpp -o debug_count -lz

$(SEQAN): 
	git submodule update --init