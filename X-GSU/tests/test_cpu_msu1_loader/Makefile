# Name
name          := Test
debug         := 2
derived_files := Test.msu
clean_files   := Test.msu

# Include libSFX.make
libsfx_dir    := ../../../libSFX
include $(libsfx_dir)/libSFX.make

Test.msu : pack_msu.py
	python3 pack_msu.py
