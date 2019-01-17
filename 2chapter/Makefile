GCC = /usr/local/cuda/bin/nvcc 
current_path=`pwd`
SRCS += ./main.cu
	
test : $(SRCS)
	$(GCC)  $(CFLAGS) $(SRCS) $(INCS) $(LIBS) -o main

clean:
	rm -rf *.o main
