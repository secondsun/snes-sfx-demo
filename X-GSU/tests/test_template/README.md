This directory contains a template for generating a test for the superFX functions I am writing for this library.
This test will setup the Snes CPU to run from work ram and the Super FX chip to run from work ram.
Key files are 
 * test.lua -> lua language program that is responsible for setting up memory watches, break points, testing output, reporting status, and stopping emulation.
 * Test.s -> The Snes progrram that sets up the main and superfx cpus to run from memory and starts superfx execution
 * Test.sgs -> The SuperFX code that sets up the test.
 * libSFX.cfg -> libSFX configuration file. Should be largely untouched, but the ROM_TITLE may be set. It should be exactly 21 chars padded if necessary

Makefile Configuration : 
 * libsfx_dir	should point to a [libSFX](https://github.com/optiroc/libsfx) installation that has been initialized with the tooling.  It is currently pointed to a correct one and will only need to be updated if the template is moved up or down in the filesystem tree heirachy

Running Tests : 
 - Run `make clean all` to build a clean version of the Test
 - Review Test.cpu.sym. Set the test_setup, test_start, and test_stop label addresses in the test.lua script to the address values found here. Mesen does not import them correctly.  The first byte of the word should be removed; only include the bottom 2 bytes.
 - run `Mesen --testRunner test.lua Test.sfc` to run the tests (note: use `--testRunner` without the hyphen in the middle). 
 - Mesen should finish, the status of Mesen will match the status that the script set when it finished.


 